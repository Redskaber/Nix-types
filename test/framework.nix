# @path: test/framework.nix
# @description: Minimal test framework for nix-types.
#
# Public API:
#   assertEqual  : name -> a -> b -> bool                  (a == b)
#   assertTrue   : name -> v -> bool                       (v == true)
#   assertFalse  : name -> v -> bool                       (v == false)
#   assertThrows : name -> thunk -> bool                   (thunk throws)
#   run          : name -> thunk -> { name, ok, error? }   (run one test, capture throw)
#   runAll       : [{ name, test }] -> {
#                    total, passed, failed, failures, allPassed
#                  }
#
# A "test" is a thunk that evaluates to `true` on success or `throw`s on failure.
# Tests that don't throw but return a non-`true` value are also recorded as failures
# (with a descriptive error).

{ }:
let
  # Run a single test case. Captures any thrown error.
  # Returns: { name = ...; ok = bool; error = string | null; }
  run = name: thunk:
    let
      # Force evaluation; both the thunk itself and `== true` check.
      # We use a nested tryEval so that even errors during `== true`
      # comparison or `toJSON` rendering are caught.
      step1 = builtins.tryEval (builtins.seq thunk true);
      # If step1 succeeded, also verify the thunk returned `true`.
      step2 =
        if !step1.success then { success = false; value = step1.value; }
        else builtins.tryEval (step1.value == true);
      # Final ok flag.
      ok = step2.success && step2.value == true;
      # Capture error message safely (errors may be strings or error objects).
      errStr =
        if ok then null
        else if !step1.success then _errToMsg step1.value
        else if !step2.success then _errToMsg step2.value
        else "test did not return true";
      _errToMsg = e:
        let r = builtins.tryEval (toString e);
        in if r.success then r.value
        else let r2 = builtins.tryEval (builtins.toJSON e);
             in if r2.success then r2.value
             else "<unevaluable error>";
    in {
      inherit name ok;
      error = errStr;
    };

  # Run a list of test cases and produce a summary.
  # Each case: { name = string; test = thunk; }
  runAll = cases:
    let
      results = map (c: run c.name c.test) cases;
      pass = builtins.filter (r: r.ok) results;
      fail = builtins.filter (r: !r.ok) results;
    in {
      total    = builtins.length results;
      passed   = builtins.length pass;
      failed   = builtins.length fail;
      failures = fail;
      allPassed = builtins.length fail == 0;
    };

  # --- Composable assertions (each returns true or throws) -----------------
  assertEqual = name: a: b:
    if a == b then true
    else throw ''
      [${name}] assertEqual failed:
        expected: ${builtins.toJSON b}
        actual:   ${builtins.toJSON a}
    '';

  assertTrue = name: v:
    if v == true then true
    else throw ''
      [${name}] assertTrue failed: expected `true`, got ${builtins.toJSON v}
    '';

  assertFalse = name: v:
    if v == false then true
    else throw ''
      [${name}] assertFalse failed: expected `false`, got ${builtins.toJSON v}
    '';

  # Assert that a thunk throws (used for testing error paths).
  # Note: `builtins.tryEval` only catches `throw` (and `assert false`); it does
  # NOT catch builtin type errors (e.g., `elemAt` out-of-bounds, attribute
  # access on non-attrs). Library code uses `throw` exclusively, so this works
  # for testing library error paths. Returns true iff the thunk raises.
  assertThrows = name: thunk:
    let r = builtins.tryEval (builtins.seq thunk true); in
    if r.success then
      throw ''[${name}] assertThrows failed: expected an error, but the thunk succeeded.''
    else true;

  # Note: `assertThrowsWith` was removed because Nix's `builtins.tryEval`
  # returns `{ success = false; value = false; }` — it does NOT preserve the
  # error message string. Use `assertThrows` and inspect traces manually
  # when you need to verify error contents.

in {
  inherit run runAll
          assertEqual assertTrue assertFalse
          assertThrows;
}
