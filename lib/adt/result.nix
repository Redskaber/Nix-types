# @path: lib/adt/result.nix
# @description: Result ADT — represents success or failure.
#
#   Result = Ok(value) | Err(error)
#
# This is a non-generic Result (holds any value for both Ok and Err).
# Both variants use pass-through validators so they accept bare values:
#
#   ok 42          → Result.Ok 42    (instance.value = 42)
#   err "failure"  → Result.Err "failure"  (instance.value = "failure")
#
# Design choices:
#   - Both `Ok` and `Err` take BARE values (not attrsets).
#   - Helpers (unwrap, map, etc.) are standalone functions.
#   - `Result.match` is the standard enum-carried alias.
#   - `cases` provides an ergonomic match where `ok`/`err` are functions
#     that receive the unwrapped value.

{ enum }:
let
  anyValue = _: true;

  Result = enum "Result" {
    Ok = anyValue;
    Err = anyValue;
  };

  # Use Result.match (the enum-carried alias) for pattern matching.
  matchResult = Result.match;
in {
  inherit Result;

  # === Constructors ===
  ok = Result.Ok;    # ok x → Result instance with value = x
  err = Result.Err;  # err e → Result instance with value = e

  # === Predicates ===
  isOk = inst: inst.tag == "Ok";
  isErr = inst: inst.tag == "Err";

  # === Extractors ===
  unwrap = inst: matchResult inst {
    Ok = v: v.value;
    Err = v: throw "Result.unwrap: called on Err(${builtins.toJSON v.value})";
  };

  unwrapErr = inst: matchResult inst {
    Ok = v: throw "Result.unwrapErr: called on Ok(${builtins.toJSON v.value})";
    Err = v: v.value;
  };

  unwrapOr = default: inst: matchResult inst {
    Ok = v: v.value;
    Err = _: default;
  };

  unwrapOrElse = f: inst: matchResult inst {
    Ok = v: v.value;
    Err = v: f v.value;
  };

  expect = msg: inst: matchResult inst {
    Ok = v: v.value;
    Err = _: throw "Result.expect: ${msg}";
  };

  # === Transformers ===
  map = f: inst: matchResult inst {
    Ok = v: Result.Ok (f v.value);
    Err = _: inst;
  };

  # Apply f to the Ok value, or return default for Err.
  # Mirrors `option.mapOr` for API consistency.
  mapOr = default: f: inst: matchResult inst {
    Ok = v: f v.value;
    Err = _: default;
  };

  mapErr = f: inst: matchResult inst {
    Ok = _: inst;
    Err = v: Result.Err (f v.value);
  };

  # Flat map: `andThen f (ok x)` → `f x` (which should return a Result).
  andThen = f: inst: matchResult inst {
    Ok = v: f v.value;
    Err = _: inst;
  };

  # === Pattern match (ergonomic) ===
  # `cases` unwraps the value for both branches. Both `ok` and `err`
  # handlers must be functions that receive the unwrapped value:
  #   cases (ok 42) { ok = x: x + 1; err = e: -1; }  →  43
  #   cases (err "fail") { ok = x: x; err = e: e + "!" }  →  "fail!"
  cases = inst: handlers: matchResult inst {
    Ok = v: handlers.ok v.value;
    Err = v: handlers.err v.value;
  };
}
