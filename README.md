# nix-types

A pure-Nix type system focused on **algebraic data types (ADT / sum types)** with
**pattern matching**. Zero external dependencies — only Nix builtins.

> v3.3: Final audit fixes — safety guards on all entry points (match,
> serialize, cases), type-identity fingerprint, __PORDER__ duplicate detection.
> 386 tests across 14 suites, all genuinely verifying correctness.

## Highlights

- **Zero deps** — only `builtins.*`. No nixpkgs, no flake inputs.
- **Clean API** — bare camelCase (no `fn-` prefix), matches nixpkgs convention.
- **Safe** — strong validation at every public entry; descriptive, contextual errors.
- **Modern** — `|>` pipe operator, `@` pattern binding, layered modules.
- **Efficient** — strict folds, lazy dispatch; 386 tests in ~70 ms.
- **String interpolation** — `"${instance}"` just works (via `__toString`).
- **ADT library** — built-in `Option` (Some/None) and `Result` (Ok/Err) with
  full helper API (unwrap, map, andThen, filter, cases, etc.).
- **Well-tested** — 386 tests across 14 categories.

## Quick start

```nix
let
  nt = import ./lib;
  inherit (nt) enum match serialize;

  # 1) unit enum
  Color = enum "Color" [ "Red" "Green" "Blue" ];

  # 2) postable enum
  Shape = enum "Shape" {
    Circle   = Color;
    Square   = [ Color Color Color ];
    Triangle = { pos1, pos2, pos3 }@inst:
      if pos1.tag == pos2.tag then inst
      else { __throw__ = "pos1 must equal pos2"; };
  };

  # 3) ADT library
  inherit (nt) some none ok err;

  # 4) pattern matching
  result = match Color.Red {
    Red = v: "got red";
    _ = v: "other";
  };

  # 5) Option/Result helpers
  doubled = nt.option.map (x: x * 2) (some 21);  # Some(42)
  safe-div = nt.result.andThen (y: if y == 0 then err "div by zero" else ok (10 / y)) (some 0);
in result
```

## Instance data structure (v3.0)

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

Changes from v2.x:
- `__IS_ENUM_INSTANCE_MASKER_V1__` → `__enumInstance__` (clean, no version)
- `type` → `__meta__` (namespaced, no collision with user data)
- `toString` → `display` (clearer, not misleading) + `__toString` function
- `__throw` → `__throw__` (consistent dunder)
- Removed `__typename__` (use `__meta__.typename` instead)
- Serialize output is now flat: `{ tag, typename, value }`

## API reference

### Core

| Function | Description |
|----------|-------------|
| `enum "Name" variants` | Create an enum type |
| `match input patterns` | Pattern match (library-level) |
| `serialize instance` | Serialize to `{ tag, typename, value }` |

### Predicates

| Function | Description |
|----------|-------------|
| `isEnum v` | Is `v` an enum type? |
| `isInst v` | Is `v` an enum instance? |
| `isType v t` | Does `v` belong to enum `t`? |
| `descTp v` | Human-readable description |
| `isLiteral v` | Leaf type? (int/float/bool/null/string/path) |
| `isDeepLiteral v` | Literal or list of deep literals? |
| `parseTypeName s` | Parse & validate a type name |

### Option ADT

```nix
let inherit (nt) some none option;

option.unwrap (some 42)           # → 42
option.unwrap none                # → throws
option.unwrapOr 0 none            # → 0
option.map (x: x * 2) (some 21)   # → Some(42)
option.andThen (x: some (x+1)) (some 41)  # → Some(42)
option.filter (x: x > 10) (some 5)  # → None
option.cases (some 42) { some = x: x; none = 0; }  # → 42
```

### Result ADT

```nix
let inherit (nt) ok err result;

result.unwrap (ok 42)             # → 42
result.unwrap (err "fail")        # → throws
result.unwrapErr (err "fail")     # → "fail"
result.map (x: x + 1) (ok 41)     # → Ok(42)
result.mapErr (e: e + "!") (err "x")  # → Err("x!")
result.andThen (x: ok (x+1)) (ok 41)  # → Ok(42)
result.cases (ok 42) { ok = x: x; err = e: -1; }  # → 42
```

### Cross-conversion

```nix
nt.optionToResult (some 42)  # → Ok(42)
nt.optionToResult none       # → Err(null)
nt.resultToOption (ok 42)    # → Some(42)
nt.resultToOption (err "x")  # → None
```

## Project layout

```
nix-types/
├── lib/
│   ├── default.nix            # public exports (core + adt)
│   ├── types/                 # core type system
│   │   ├── default.nix        # aggregator
│   │   ├── config.nix         # constants
│   │   ├── utils.nix          # pure helpers
│   │   ├── predicates.nix     # type predicates
│   │   ├── validators.nix     # validation logic
│   │   ├── constructors.nix   # variant constructors
│   │   ├── match.nix          # pattern matching engine
│   │   ├── serialize.nix      # serialization
│   │   └── enum.nix           # enum factory
│   └── adt/                   # ADT library extensions
│       ├── default.nix        # aggregator + cross-conversion
│       ├── option.nix         # Option, Some, None, helpers
│       └── result.nix         # Result, Ok, Err, helpers
├── test/
│   ├── default.nix            # test entry
│   ├── framework.nix          # test framework
│   └── cases/                 # 14 test suites (386 tests)
├── scripts/run-tests.sh       # CLI test runner
└── docs/
    ├── ARCHITECTURE.md
    └── CHANGELOG.md
```

## Lazy evaluation

Nix is lazy by default, but certain operations force evaluation. Key boundaries:

**LAZY** (does NOT force values until accessed):
- `enum "Name" { ... }` — creating an enum doesn't force variant descriptors
- `E.A` — accessing variant A doesn't force variant B
- `inst.tag` — doesn't force `inst.value`
- `match inst { ... }` — only the matched handler runs
- `isEnum`/`isInst`/`isType` — check attr presence only (WHNF)

**EAGER** (forces values at the indicated point):
- `Shape.Square [a b c]` — all args validated at construct time (fail-fast)
- `Shape.Triangle { ... }` — validator fn runs at construct time
- `some (throw "X")` / `ok (throw "X")` — validator fn `_: true` runs eagerly
- `inst.display` / `"${inst}"` — forces value for string construction
- `option.unwrap`/`map`/`filter`/`cases` — force the contained value

The `test/cases/lazy.nix` suite (34 tests) verifies these boundaries using
`throw` as a probe, catching accidental strictness changes in refactors.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full lazy/eager map.

## Running tests

```bash
./scripts/run-tests.sh           # compact summary
./scripts/run-tests.sh --verbose # per-suite breakdown
./scripts/run-tests.sh --json    # JSON for CI
```

### Test categories (386 tests)

| Suite | Count | Coverage |
|-------|-------|----------|
| unit | 23 | unit enum, string interpolation, field names |
| literal | 21 | every literal type, edge cases |
| postable | 32 | enum/tuple/fun/mixed variants |
| match | 32 | single/list/attrset, errors, chaining |
| predicates | 52 | all predicates, parseTypeName |
| serialize | 14 | recursive normalization, JSON safety |
| errors | 19 | error paths |
| library | 18 | library-level API, top-level exports |
| option | 38 | Option ADT (construct/pred/extract/transform/match) |
| result | 39 | Result ADT (construct/pred/extract/transform/match) |
| lazy | 34 | lazy evaluation boundaries (LAZY vs EAGER) |
| audit | 16 | regression tests for v3.0 deep-audit fixes |
| audit2 | 18 | regression tests for v3.1 fresh-audit fixes |
| audit3 | 30 | regression tests for v3.2 final-audit fixes |
| **total** | **386** | |

> **Note**: The test framework uses `builtins.deepSeq thunk thunk` to verify
> test return values (not `builtins.seq thunk true`, which would make every
> test vacuously pass). The `audit.framework.*` tests verify this.

## Requirements

- Nix 2.24+ (`experimental-features = nix-command flakes pipe-operators`)
- No internet, no nixpkgs — fully self-contained.

## License

MIT.
