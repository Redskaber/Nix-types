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
# A "test" is a thunk that evaluates to `true` on success or `throw`s on
# failure. Tests that don't throw but return a non-`true` value are also
# recorded as failures (with a descriptive error).
#
# Note on `builtins.tryEval`:
#   It catches `throw` (and `assert false`) but does NOT catch:
#     - `abort` (terminates the whole evaluation)
#     - builtin type errors (e.g., `elemAt` out-of-bounds, attr access on non-attrs)
#   Library code uses `throw` exclusively for user-facing errors, so
#   `assertThrows` works for testing library error paths.

{ }:
let
  # Convert an error value to a human-readable string (safely).
  errToMsg = e:
    let r1 = builtins.tryEval (toString e); in
    if r1.success then r1.value
    else
      let r2 = builtins.tryEval (builtins.toJSON e); in
      if r2.success then r2.value
      else "<unevaluable error>";

  # Run a single test case. Captures any thrown error.
  # Returns: { name = ...; ok = bool; error = string | null; }
  #
  # Key implementation detail:
  #   `builtins.seq thunk thunk` forces `thunk` to WHNF and RETURNS the
  #   thunk's value (not `true`). This is critical: `seq thunk true` would
  #   return `true` regardless of what `thunk` evaluated to, making every
  #   non-throwing test vacuously pass.
  run = name: thunk:
    let
      # Force the thunk and capture its actual value (or the thrown error).
      result = builtins.tryEval (builtins.deepSeq thunk thunk);
      # The test passes iff the thunk evaluated to exactly `true`.
      ok = result.success && result.value == true;
      errStr =
        if ok then null
        else if !result.success then errToMsg result.value
        else "test returned ${builtins.toJSON result.value} (expected true)";
    in
    {
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
    in
    {
      total = builtins.length results;
      passed = builtins.length pass;
      failed = builtins.length fail;
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
  # Returns true iff the thunk raises.
  assertThrows = name: thunk:
    let r = builtins.tryEval (builtins.deepSeq thunk thunk); in
    if r.success then
      throw ''[${name}] assertThrows failed: expected an error, but the thunk succeeded.''
    else true;
in
{
  inherit run runAll
    assertEqual assertTrue assertFalse
    assertThrows;
}
