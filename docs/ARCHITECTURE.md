# Architecture

This document describes the design decisions, layered architecture, and data
flow of `nix-types` v3.0.

## 1. Project intent

`nix-types` is a **pure Nix builtins** implementation of an algebraic data type
(ADT / sum type) system with pattern matching, suitable for declaring domain
models, state machines, validators, and controlled ADT values in Nix
configurations.

### Design goals

- **Zero dependencies** — only Nix language builtins (`builtins.*`), no nixpkgs,
  no flake inputs, no FFI.
- **Safe** — every public entry point has strong validation; error messages are
  readable, contextual, and surfaced eagerly via `builtins.seq`.
- **Modern** — uses `|>` pipe operator, `@` pattern binding, `rec` for mutual
  recursion, layered modules with explicit dependency injection.
- **Efficient** — strict folds (`foldl'`), lazy dispatch on variant shape,
  no redundant computations; 284 tests run in ~50 ms.
- **Clean API** — bare camelCase (no `fn-` prefix), matches nixpkgs convention.
  No backward-compat aliases.

## 2. Design decision: carry vs separate

### The question

Should enum types carry functions (`Shape.match`, `Shape.serialize`) or should
functions be separated at the library level (`lib.match Shape inst`, `lib.serialize inst`)?

### Decision: Separate (library-level) + Carry (alias)

- **Primary API**: library-level functions `match`, `serialize` — defined once
  in `match.nix` / `serialize.nix`, exported at the top level.
- **Alias**: enum types carry `Shape.match` / `Shape.serialize` as thin aliases
  that delegate to the library functions.

**Rationale**:
- `match` and `serialize` are pure functions of `(input, patterns)` and
  `(instance)` — they don't reference the enum type. Carrying is just an alias.
- **Performance**: neutral (Nix caches imports; the alias is just an attr pointer).
- **Organization**: separating gives single source of truth, testability
  without an enum, consistent with `isEnum`/`isInst` being library-level.
- **Ergonomics**: carrying provides `Shape.match inst` ergonomics.

## 3. Instance data structure (v3.0)

Every enum instance has this clean, standardized shape:

```
{
  tag = "Red";                    # variant name (public)
  value = null;                   # payload (public)
  display = "enum::Color::Red";   # pre-computed display string (public)
  __toString = self: self.display; # Nix magic: enables "${instance}"
  __meta__ = { typename = "Color"; }; # enum identity (internal)
  __enumInstance__ = true;        # duck-type marker (internal)
}
```

### Naming convention

| Category | Convention | Examples |
|----------|-----------|----------|
| Public fields | bare lowercase | `tag`, `value`, `display` |
| Internal metadata | dunder | `__meta__`, `__enumInstance__` |
| Nix magic | dunder function | `__toString` |
| Reserved in user data | dunder | `__PORDER__`, `__throw__` |
| Public functions | bare camelCase | `enum`, `match`, `isEnum`, `descTp` |
| Internal validators | `validate` prefix | `validateVariantsType`, `validateValue` |
| Internal constructors | `mk` prefix | `mkInstance`, `mkTupleVariant` |
| Struct definitions | PascalCase | `EnumMeta`, `VariantInst` |

## 4. Module architecture

```
lib/
├── default.nix            # public entry (core + adt)
├── types/                 # core type system
│   ├── default.nix        # aggregator
│   ├── config.nix         # constants
│   ├── utils.nix          # pure helpers
│   ├── predicates.nix     # type predicates
│   ├── validators.nix     # validation logic
│   ├── constructors.nix   # variant constructors (single mkInstance)
│   ├── match.nix          # pattern matching engine
│   ├── serialize.nix      # serialization
│   └── enum.nix           # enum factory
└── adt/                   # ADT library extensions
    ├── default.nix        # aggregator + cross-conversion
    ├── option.nix         # Option, Some, None, helpers
    └── result.nix         # Result, Ok, Err, helpers
```

### Dependency graph

```
                     ┌──────────┐
                     │ config   │
                     └────┬─────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
  ┌──────────┐    ┌──────────────┐   ┌──────────────┐
  │ utils    │    │ predicates   │   │              │
  └────┬─────┘    └──────┬───────┘   │              │
       │                 │           │              │
       │      ┌──────────┘           │              │
       │      │                      │              │
       ▼      ▼                      ▼              ▼
  ┌────────────────┐         ┌──────────────┐  ┌──────────────┐
  │  validators    │◄────────│   match      │  │  serialize   │
  └────────┬───────┘         └──────┬───────┘  └──────┬───────┘
           │                        │                 │
           ▼                        ▼                 ▼
        ┌─────────────────────────────────────────────────┐
        │              constructors                       │
        │  (single mkInstance; imports match & serialize  │
        │   as aliases on the enum type)                  │
        └─────────────────────┬───────────────────────────┘
                              │
                              ▼
                       ┌──────────────┐
                       │   enum       │  ← public factory
                       └──────┬───────┘
                              │
                              ▼
                       ┌──────────────┐
                       │  default     │  ← aggregator
                       └──────────────┘
```

### Key design choices

1. **Single `mkInstance`** — all per-shape constructors delegate to one
   `mkInstance` function, ensuring consistent field layout and avoiding
   duplication (was 4 copies in v2.x, now 1).

2. **Explicit dependency injection** — each module receives its dependencies
   as an attrset argument (`{ config, types, ... }`). No implicit imports,
   easy to test in isolation.

3. **Deep-literal vs tuple distinction** — `mkMapTuplePostable` checks
   `isDeepLiteral` first: deep-literal lists (e.g., `["a" "b"]`) are kept
   as lists; non-literal lists (tuple args) are converted to indexed attrsets.

## 5. ADT library (Option / Result)

### Option

```
Option = Some(value) | None
```

- `Some` takes a BARE value (not attrset) — `some 42` stores `42` directly.
- Helpers are namespaced under `option` (e.g., `nt.option.unwrap`).
- 14 helpers: `some`, `none`, `isSome`, `isNone`, `unwrap`, `unwrapOr`,
  `unwrapOrElse`, `expect`, `map`, `mapOr`, `andThen`, `filter`, `cases`.

### Result

```
Result = Ok(value) | Err(error)
```

- Both `Ok` and `Err` take bare values.
- Helpers are namespaced under `result` (e.g., `nt.result.unwrap`).
- 13 helpers: `ok`, `err`, `isOk`, `isErr`, `unwrap`, `unwrapErr`,
  `unwrapOr`, `unwrapOrElse`, `expect`, `map`, `mapErr`, `andThen`, `cases`.

### Cross-conversion

- `optionToResult`: `Some(x) → Ok(x)`, `None → Err(null)`
- `resultToOption`: `Ok(x) → Some(x)`, `Err(_) → None`

## 6. Lazy evaluation boundaries

Nix is lazy by default, but certain operations force evaluation. This section
documents exactly which operations are lazy and which are eager, so callers
can reason about performance and infinite-data scenarios.

### LAZY (does NOT force values until accessed)

| Operation | Behavior |
|-----------|----------|
| `enum "Name" { A = ...; B = ...; }` | Creating an enum does NOT force variant descriptors. |
| `E.A` (variant access) | Forces only variant A's descriptor; B stays lazy. |
| `inst.tag` | Does NOT force `inst.value` (independent attrset fields). |
| `match inst { Red = ...; _ = ...; }` | Only the matched handler runs; other handlers stay lazy. |
| `match [a b] { Red.Green = ...; _._ = ...; }` | Only the matched pattern's handler runs. |
| `isEnum v`, `isInst v` | Check attr presence (WHNF only); do NOT force values. |
| `isType v t` | Compares `__meta__`; does NOT force values. |
| `serialize inst` (accessing `.tag` only) | `.tag` and `.typename` don't force `.value`. |
| `none` (Option.None) | Unit variant — no value to force. |

### EAGER (forces values at the indicated point)

| Operation | Forces | Why |
|-----------|--------|-----|
| `Shape.Square [a b c]` (tuple construct) | All args | Validator checks arity + type of each position. |
| `Shape.Triangle { ... }` (fn validator) | The arg + return value | Validator fn runs at construct time; returned attrset enriches the instance. |
| `some (throw "X")`, `ok (throw "X")` | The value | Some/Ok use validator fn `_: true`, which runs eagerly. |
| `inst.display` | The value | Display string includes the value for interpolation. |
| `"${inst}"` | The value | Uses `__toString` → `display` → forces value. |
| `serialize inst` (accessing `.value`) | The value | The `isInst` check forces the value. |
| `option.unwrap s` | The value | Returns the value directly. |
| `option.map f s` | The value | Applies `f` to the value. |
| `option.cases s { ... }` | The value | Passes value to the handler. |
| `option.filter pred s` | The value | Applies `pred` to the value. |

### Design rationale

The eager points are deliberate safety tradeoffs:
- **Tuple/fn validators** run at construct time to catch arity/type errors
  early (fail-fast), rather than deferring errors to access time.
- **Display/toString** must force the value to build the string.
- **Some/Ok** use validator functions because the enum system requires a
  descriptor shape (function = validator). A future optimization could add
  a "passthrough" descriptor type that avoids the validator call.

### Testing

The `test/cases/lazy.nix` suite (34 tests) verifies these boundaries using
`throw` as a probe — if a `throw` fires, the value was forced; if not, it
stayed lazy. This catches accidental strictness changes in refactors.

## 7. Test architecture

356 tests across 13 suites:

| Suite | Count | Coverage |
|-------|-------|----------|
| unit | 23 | unit enum, string interpolation, field names |
| literal | 21 | every literal type, edge cases |
| postable | 32 | enum/tuple/fun/mixed variants |
| match | 32 | single/list/attrset, errors, chaining |
| predicates | 52 | all predicates, parseTypeName |
| serialize | 14 | flat output, recursive value normalization, JSON safety |
| errors | 19 | error paths |
| library | 18 | library-level API, top-level exports |
| option | 38 | Option ADT (construct/pred/extract/transform/match) |
| result | 39 | Result ADT (construct/pred/extract/transform/match) |
| lazy | 34 | lazy evaluation boundaries (LAZY vs EAGER) |
| audit | 16 | regression tests for v3.0 deep-audit fixes |
| audit2 | 18 | regression tests for v3.1 fresh-audit fixes |
| **total** | **356** | |

### Test framework correctness

The test framework (`test/framework.nix`) uses `builtins.deepSeq thunk thunk`
to force the thunk to its full normal form and return its actual value. This
is critical: `builtins.seq thunk true` would return `true` regardless of the
thunk's value, making every non-throwing test vacuously pass.

The `audit.framework.*` tests verify this behavior:
- `1 == 2` → correctly fails (not vacuously passes)
- `1 == 1` → correctly passes
- `throw "x"` → correctly fails
