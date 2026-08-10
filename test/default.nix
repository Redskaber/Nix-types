# @path: test/default.nix
# @description: Test entry point. Aggregates all per-category test suites and
#               produces a single summary record.

let
  suites = {
    unit       = import ./cases/unit.nix;
    literal    = import ./cases/literal.nix;
    postable   = import ./cases/postable.nix;
    match      = import ./cases/match.nix;
    predicates = import ./cases/predicates.nix;
    serialize  = import ./cases/serialize.nix;
    errors     = import ./cases/errors.nix;
    library    = import ./cases/library.nix;
    option     = import ./cases/option.nix;
    result     = import ./cases/result.nix;
    lazy       = import ./cases/lazy.nix;
    audit      = import ./cases/audit.nix;
    audit2     = import ./cases/audit2.nix;
    audit3     = import ./cases/audit3.nix;
  };

  all-results = builtins.concatLists (builtins.attrValues
    (builtins.mapAttrs (_: s: s.failures) suites));

  total    = builtins.foldl' (n: s: n + s.total)    0 (builtins.attrValues suites);
  passed   = builtins.foldl' (n: s: n + s.passed)   0 (builtins.attrValues suites);
  failed   = builtins.foldl' (n: s: n + s.failed)   0 (builtins.attrValues suites);
  failures = all-results;
  allPassed = failed == 0;
in
{
  inherit total passed failed failures allPassed suites;
  summary = {
    inherit total passed failed allPassed;
  };
}
