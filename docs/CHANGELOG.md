# Changelog

## [3.4.0] — 2026-08-10

### Summary

Exhaustive-audit fixes: variant name validation, predicate safety guards,
cases handler type validation, serialize lambda handling, documentation
accuracy. 419 tests across 15 suites.

### High-severity fixes

**H10. Variant name validation added**
- Empty strings, duplicates, non-string names, and collisions with internal
  fields (`__meta__`, `match`, `serialize`, `__variants__`) were silently
  accepted, causing confusing behavior later.
- Fix: `validateVariantName` + `validateVariantNames` check all variant
  names eagerly. Throws descriptive, catchable errors.

**H11. ADT predicates guard against non-attrsets**
- `option.isSome 42` / `result.isOk "hello"` produced uncatchable builtin
  errors (accessing `.tag` on non-attrset).
- Fix: `isSome`/`isNone`/`isOk`/`isErr` now check `builtins.isAttrs inst`
  first, returning `false` for non-attrsets instead of crashing.

**H12. `cases` validates handler types are functions**
- `option.cases (some 42) { some = 42; none = 0; }` produced an uncatchable
  builtin error when calling the non-function `some` handler.
- Fix: both `cases` functions now validate `handlers.some`/`ok`/`err` are
  functions before matching. `none` is a value (not a function) for Option.

### Medium fixes

**M12. `__PORDER__` collision with variant names**
- A variant named `__PORDER__` would be inaccessible as a pattern key.
- Fix: covered by H10's internal-field collision check.

**M13. Non-string list elements in unit enum**
- `m.enum "E" [ "A" 42 ]` produced an uncatchable builtin error.
- Fix: covered by H10's `validateVariantName` (checks `isString`).

**M14. `serialize` handles lambdas safely**
- If a function-validator returned an attrset containing a lambda,
  `builtins.toJSON (m.serialize inst)` would fail with an uncatchable error.
- Fix: `serializeValue` now converts lambdas to `"<lambda>"` string,
  ensuring the output is always JSON-safe.

### Low fixes

**L22. `__meta__` structure diagrams updated**
- README, ARCHITECTURE.md, and constructors.nix now show the `variantNames`
  field added in v3.3.

**L23. `lib/default.nix` `m.types` description corrected**
- Now accurately states `types (predicates + struct defs + config)`.

**L24. `validateFunRst` comment corrected**
- Changed "non-empty attrset" to "attrset (may be empty)" to match actual
  behavior.

**L25. Test coverage gaps filled**
- Added `test/cases/audit4.nix` (33 tests) covering: variant name
  validation, predicate safety, cases handler types, serialize lambda
  handling, nested tuple construction, wrong-enum match, andThen chains.

### Added

- **`test/cases/audit4.nix`** (33 tests) — regression tests for all the
  above fixes.

---

## [3.3.0] — 2026-08-10

### Summary

Final-audit fixes: safety guards on all entry points, type-identity
fingerprint, __PORDER__ duplicate detection, documentation accuracy.
386 tests across 14 suites.

### Critical fixes

**C1. `flake.nix` `mkTestDerivation` called test with spurious argument**
- `(import ./test { inherit lib; })` tried to call a non-function attrset,
  breaking `nix build .#test` and `nix flake check`.
- Fix: `(import ./test)` — test/default.nix takes no arguments.

### High-severity fixes

**H7. `match` with non-instance elements → catchable throw**
- Previously, `match [ 42 ] { ... }` or `match { x = "not-inst"; } { ... }`
  produced uncatchable builtin errors when accessing `.tag`.
- Fix: added `validateInputElements` that checks all list/attrset elements
  are enum instances before matching. Throws a descriptive, catchable error.

**H8. `serialize` on non-instance → catchable throw**
- `serialize 42` produced a lazy attrset with throwing fields (uncatchable).
- Fix: added `isInst` guard at the top of `serialize`.

**H9. `option.cases`/`result.cases` with missing handler keys → catchable throw**
- `option.cases none { some = x: x; }` → uncatchable `attribute 'none' missing`.
- Fix: both `cases` functions now eagerly validate that `handlers` contains
  all required keys (`some`/`none` for Option, `ok`/`err` for Result).

### Medium fixes

**M8. `isType` now distinguishes enums with different variant sets**
- Previously, two `enum "Color" [...]` calls with different variants were
  indistinguishable by `isType` (both had `__meta__ = { typename = "Color"; }`).
- Fix: `__meta__` now includes `variantNames`, so `isType` can distinguish
  enums with the same typename but different variant sets.

**M9. `__PORDER__` with duplicate keys → catchable throw**
- `__PORDER__ = [ "a" "a" ]` was silently mishandled (only last occurrence
  kept, other keys dropped).
- Fix: `validateOrderKeyTp` now checks for duplicates and throws.

**M10/M11. Documentation stale test counts fixed**
- README and ARCHITECTURE.md had outdated "284 tests" / "10 suites" counts.
- Updated to 386 tests / 14 suites.

### Low fixes

**L16/L17. `some null` / `some [ ]` edge cases tested**
- The `null` sentinel collision (null = both "no payload" and "payload is
  null") and the empty-list display quirk are now documented via tests.
- `value` is correct in both cases; only `display` is affected.

**L19. Option helper count corrected (14 → 13)**
- ARCHITECTURE.md listed 14 helpers but only 13 were enumerated.

**L20. `lib/default.nix` doc for `lib` nested export corrected**
- Now accurately states `lib (utils + core API + predicates + config)`.

**L21. Stale version comment removed from `lib/types/default.nix`**

### Added

- **`test/cases/audit3.nix`** (30 tests) — regression tests for all the
  above fixes, including edge cases for null/empty-list values.

---

## [3.2.0] — 2026-08-10

### Summary

Fresh-audit fixes: recursive serialization, API consistency, dead code
removal, safety guards. 356 tests across 13 suites.

### High-severity fixes

**H5. `serialize` now recursively normalizes values**
- Previously, tuple/function variants serialized their `value` as a nested
  attrset of **full enum instances** (with lambdas, `__meta__`, etc.),
  making the output non-JSON-safe and inconsistent with the docs.
- Fix: `serializeValue` recursively normalizes — enum instances become
  their `tag` (string), attrsets/lists are recursed element-wise.
- The output is now fully JSON-safe (verified by `toJSON` tests).
- Updated `serialize.04` test (tuple value is now tags, not instances).

**H6. `result.mapOr` added (API consistency)**
- `option.mapOr` existed but `result.mapOr` was missing.
- Fix: added `result.mapOr default f inst` mirroring `option.mapOr`.
- Added tests `result.transform.08/09`.

### Medium fixes

**M6. `__logger` dead code removed**
- `__logger` was defined, exported, and never used or tested.
- Removed from `utils.nix`; removed `debug.enable` from `config.nix`.

**M7. `parseTypeName` guards non-string input**
- `builtins.match` requires a string; non-string typename produced an
  uncatchable builtin error.
- Fix: added `isString` guard that throws a catchable error.

### Low fixes

**L9. `optionToResult`/`resultToOption` now tested**
- Added 5 tests covering all conversion paths and a roundtrip.

**L10. Dead test fixtures removed**
- `shared.Shape`, `shared.Inner`, `shared.Outer` were never used.
- Removed from `shared.nix`.

**L11. `lazy.option.01` comment corrected**
- Misattributed eagerness cause to the validator fn; actual cause is
  `getBasePostable` forcing the value via `builtins.isAttrs`.

**L12. `validateMultiMatchRst` tip uses computed wildcard**
- Was hardcoded `_._._`; now uses the computed `${wildcard}` variable.

**L13. `m.lib` ADT exclusion documented**
- Added note in `lib/default.nix` that `m.lib` intentionally excludes
  ADT helpers.

**L15. Naming convention documentation updated**
- `utils.nix` header now accurately documents that public functions use
  camelCase while internal `let` bindings may use kebab-case.

### Added

- **`test/cases/audit2.nix`** (18 tests) — regression tests for all the
  above fixes.
- **`serialize.13/14`** — JSON safety and content verification tests.

---

## [3.1.0] — 2026-08-10

### Summary

Deep-audit fixes: critical test framework bug, dead code removal, safety
improvements, documentation accuracy. 334 tests across 12 suites, all
genuinely verifying correctness (previous "318 passing" was inflated by
a framework bug that made tests vacuously pass).

### Critical fixes

**C1. Test framework `seq` bug (CRITICAL)**
- `builtins.seq thunk true` returns `true` (the second arg), not the thunk's
  value. Every bare-boolean test was vacuously passing.
- Fix: use `builtins.deepSeq thunk thunk` to force and return the actual value.
- Impact: 3 tests that were silently wrong now correctly fail and have been
  fixed (literal.13, literal.14, option.extract.06).

### High-severity fixes

**H1. Dead code: `externalKeysFn` / `getTupleBasePostable`**
- These functions were broken (threw on access) and never exercised by tests.
- Removed; `getBasePostable` now returns `{}` for non-attrset inputs.
- The tuple value is already correctly stored in `instance.value` via
  `mkMapTuplePostable`.

**H2. `option.unwrapOrElse` didn't call `f`**
- Was returning `f` itself instead of calling it, inconsistent with
  `result.unwrapOrElse` which calls `f errValue`.
- Fix: `option.unwrapOrElse f inst` now calls `f null` on None (None has no
  value to pass).

**H3. Tuple-position function validators bypassed `validateFunRst`**
- A function validator inside a tuple position (`[Color (x: ...) Color]`)
  was called but its return value wasn't validated.
- Fix: route through `validateFunRst` so `{ __throw__ = "..." }` returns
  are converted to actual throws, consistent with top-level validators.

**H4. Function validator's returned attrset was discarded**
- `postableFunConstructor` computed the validator result but passed the
  original input to `mkInstance`, discarding any enrichment.
- Fix: if the validator returns an attrset, use it as the instance value.
- Note: tuple-position function validators still keep the original input
  (documented limitation — enrichment only works at the top level).

### Medium fixes

**M1. `validateArgTp` interpolation could mask errors**
- `${postable}` would throw "cannot coerce" for non-string-coercible values,
  masking the intended friendly error message.
- Fix: removed the `${postable}` interpolation; kept `${types.descTp postable}`.

**M3. Dead `utils` import in `predicates.nix`**
- `utils = import ./utils.nix;` was bound but never used.
- Removed.

**M4. Dead struct definitions removed**
- `EnumTypeFuncs`, `VariantInst`, `PostableVariant` were never called.
- Removed; kept `EnumMeta`, `EnumInstStruct`, `TupleVariant` (used).

### Low fixes

**L4. Misleading export list in `lib/default.nix`**
- Header listed `map` as top-level but it's namespaced under `option.*`/`result.*`.
- Fixed to accurately reflect the export structure.

**L5. README referenced non-existent `O`/`R` shortcuts**
- README examples used `O` and `R` as aliases for `option`/`result`.
- Fixed to use `option`/`result` directly.

**L6. Overly defensive `builtins.seq` chains in `flattenPatterns`**
- Redundant `seq` calls on values already forced by dependent computations.
- Simplified to a single `seq` around the duplicate-pattern check.

**L8. Empty attrset variants now rejected**
- `enum "E" {}` now throws (a postable enum with no variants is never useful).
- Empty list `enum "E" []` is still allowed (valid edge case).

### Added

- **`test/cases/audit.nix`** (16 tests) — regression tests for all the above
  fixes, plus framework correctness verification.

### Test framework correctness

The `audit.framework.*` tests verify that the framework actually checks test
return values:
- `1 == 2` → fails (not vacuously passes)
- `1 == 1` → passes
- `throw "x"` → fails

This ensures future framework changes don't reintroduce the C1 bug.

---

## [3.0.0] — 2026-08-10

### Summary

Breaking-change release: removed all backward-compat aliases, standardized
internal data structure, added Option/Result ADT library. 284 tests across
10 suites.

### Breaking changes

**Removed all `fn-*` aliases** — v1.x/v2.x names like `fn-isEnum`, `fn-match`,
`fn-trim` are gone. Use the clean names: `isEnum`, `match`, `trim`.

**Standardized internal data structure:**

| v2.x | v3.0 | Reason |
|------|------|--------|
| `__IS_ENUM_INSTANCE_MASKER_V1__` | `__enumInstance__` | Clean, no version suffix |
| `type` (on instances) | `__meta__` | Namespaced, no collision with user data |
| `toString` (string attr) | `display` + `__toString` (function) | Clearer; enables `"${instance}"` |
| `__throw` | `__throw__` | Consistent dunder convention |
| `__typename__` (on enum types) | removed | Use `__meta__.typename` |
| serialize: `{ tag, type, value }` | `{ tag, typename, value }` | Flat, no nested meta |

**Migration:**
```nix
# v2.x (broken in v3.0)
v.toString           →  v.display
v.type.typename      →  v.__meta__.typename
{ __throw = "msg"; } →  { __throw__ = "msg"; }
types.fn-isEnum Color →  types.isEnum Color

# v3.0 (new)
"${Color.Red}"       # works! → "enum::Color::Red" (via __toString)
```

### Added

- **Option ADT** (`lib/adt/option.nix`) — `Option = Some(value) | None` with
  helpers: `some`, `none`, `isSome`, `isNone`, `unwrap`, `unwrapOr`,
  `unwrapOrElse`, `expect`, `map`, `mapOr`, `andThen`, `filter`, `cases`.
  - `Some` takes a BARE value (not attrset) — `some 42` stores `42` directly.
  - Helpers are namespaced under `option` (e.g., `nt.option.unwrap`).

- **Result ADT** (`lib/adt/result.nix`) — `Result = Ok(value) | Err(error)`
  with helpers: `ok`, `err`, `isOk`, `isErr`, `unwrap`, `unwrapErr`,
  `unwrapOr`, `unwrapOrElse`, `expect`, `map`, `mapErr`, `andThen`, `cases`.
  - Both `Ok` and `Err` take bare values.
  - Helpers are namespaced under `result` (e.g., `nt.result.unwrap`).

- **Cross-conversion** — `optionToResult` and `resultToOption`.

- **String interpolation** — instances now support `"${instance}"` via the
  `__toString` Nix magic field, which returns the pre-computed `display` string.

- **10 test suites** (284 tests total), including new `option.nix` (38 tests)
  and `result.nix` (37 tests).

### Changed

- **Internal field naming** — all fields standardized (see breaking changes above).
- **Serialize output** — now flat `{ tag, typename, value }` instead of
  `{ tag, type, value }` with nested meta.
- **`isType` simplified** — both enum types and instances carry `__meta__`,
  so the check unifies: `v.__meta__ == t.__meta__`.
- **`descTp`** — uses `v.__meta__.typename` instead of `v.__typename__`.
- **`config.keys.internal`** — updated to include all v3.0 field names.
- **`config.keys.reserved.__throw__`** — renamed from `__throw` for consistency.

### Removed

- All `fn-*` deprecated aliases (20+ names).
- `__typename__` field on enum types (redundant with `__meta__.typename`).
- `compat.nix` test file (tested old `fn-*` names).
- `fn-validator_*` aliases in validators module.
- `__fn-logger__` alias (now just `__logger`).

---

## [2.1.0] — 2026-08-10

Naming standardization + carry-vs-separate design. All public functions
renamed to drop `fn-` prefix. `match`/`serialize` promoted to top-level.
Full backward compat via deprecated aliases. 241 tests.

## [2.0.0] — 2026-08-10

Module-split architecture, modern flake outputs, CLI test runner.
Removed generic-type code. 209 tests.

## [1.0.0] — 2026-03-10

Initial release with generic-type support.
