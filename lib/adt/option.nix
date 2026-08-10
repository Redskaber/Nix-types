# @path: lib/adt/option.nix
# @description: Option ADT — represents an optional value.
#
#   Option = Some(value) | None
#
# This is a non-generic Option (holds any value). The `Some` variant uses
# a pass-through validator (`_: true`) so it accepts a bare value directly:
#
#   some 42       → Option.Some 42   (instance.value = 42)
#   none          → Option.None      (unit variant)
#
# Design choices:
#   - `Some` takes a BARE value (not an attrset), so `instance.value` is
#     the value directly — no nesting.
#   - `None` is a unit variant (no payload).
#   - Helpers (unwrap, map, etc.) are standalone functions, consistent with
#     the "separate" design.
#   - `Option.match` is the standard enum-carried alias (takes
#     `{ Some = v: ...; None = v: ...; }`).
#   - For a more ergonomic match API, use `cases` (takes
#     `{ some = x: ...; none = ...; }` where `x` is the unwrapped value).

{ enum }:
let
  # Pass-through validator: accepts any single value, always succeeds.
  # This makes `Option.Some x` store `x` directly in `instance.value`.
  anyValue = _: true;

  Option = enum "Option" {
    Some = anyValue;
    None = null;
  };

  # Use Option.match (the enum-carried alias) for pattern matching.
  # This ensures the match context is bound to the Option enum type.
  matchOption = Option.match;
in {
  inherit Option;

  # === Constructors ===
  some = Option.Some;   # some x → Option instance with value = x
  none = Option.None;   # unit variant (no payload)

  # === Predicates ===
  isSome = inst: inst.tag == "Some";
  isNone = inst: inst.tag == "None";

  # === Extractors ===
  unwrap = inst: matchOption inst {
    Some = v: v.value;
    None = _: throw "Option.unwrap: called on None";
  };

  unwrapOr = default: inst: matchOption inst {
    Some = v: v.value;
    None = _: default;
  };

  unwrapOrElse = f: inst: matchOption inst {
    Some = v: v.value;
    None = _: f null;
  };

  expect = msg: inst: matchOption inst {
    Some = v: v.value;
    None = _: throw "Option.expect: ${msg}";
  };

  # === Transformers ===
  map = f: inst: matchOption inst {
    Some = v: Option.Some (f v.value);
    None = _: Option.None;
  };

  mapOr = default: f: inst: matchOption inst {
    Some = v: f v.value;
    None = _: default;
  };

  # Flat map: `andThen f (some x)` → `f x` (which should return an Option).
  andThen = f: inst: matchOption inst {
    Some = v: f v.value;
    None = _: Option.None;
  };

  # Keep the value only if it satisfies the predicate.
  filter = pred: inst: matchOption inst {
    Some = v: if pred v.value then inst else Option.None;
    None = _: Option.None;
  };

  # === Pattern match (ergonomic) ===
  # Unlike `Option.match` (which gives the handler the full instance),
  # `cases` unwraps the value for the `some` branch:
  #   cases (some 42) { some = x: x + 1; none = 0; }  →  43
  # The `none` handler is a bare value (not a function).
  # Throws eagerly if `handlers` is missing `some` or `none`.
  cases = inst: handlers:
    if !(handlers ? some) then
      throw "Option.cases: handlers missing 'some' key (function)"
    else if !(handlers ? none) then
      throw "Option.cases: handlers missing 'none' key (value)"
    else matchOption inst {
      Some = v: handlers.some v.value;
      None = _: handlers.none;
    };
}
