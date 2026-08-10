# @path: lib/adt/default.nix
# @description: ADT library extensions — Option and Result.
#
# Aggregates Option and Result modules. Helper functions are namespaced
# under `option` and `result` sub-attrsets to avoid name collisions
# (both define `unwrap`, `map`, `cases`, etc.).
#
# Top-level shortcuts are provided for the most common constructors:
#   some, none, ok, err
#
# Requires the core library's `enum` and `match` functions as input.

{ enum }:
let
  optionMod = import ./option.nix { inherit enum; };
  resultMod = import ./result.nix { inherit enum; };

  matchOption = optionMod.Option.match;
  matchResult = resultMod.Result.match;
in {
  # === Enum types ===
  Option = optionMod.Option;
  Result = resultMod.Result;

  # === Namespaced helpers ===
  option = optionMod;
  result = resultMod;

  # === Top-level constructor shortcuts ===
  # These don't collide (unique names).
  some = optionMod.some;
  none = optionMod.none;
  ok = resultMod.ok;
  err = resultMod.err;

  # === Cross-conversion ===

  # Convert an Option to a Result: Some(x) → Ok(x), None → Err(null).
  optionToResult = opt: matchOption opt {
    Some = v: resultMod.ok v.value;
    None = _: resultMod.err null;
  };

  # Convert a Result to an Option: Ok(x) → Some(x), Err(_) → None.
  resultToOption = res: matchResult res {
    Ok = v: optionMod.some v.value;
    Err = _: optionMod.none;
  };
}
