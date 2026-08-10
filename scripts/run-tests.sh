#!/usr/bin/env bash
# @path: scripts/run-tests.sh
# @description: CLI test runner for nix-types. Prints a human-readable summary.
#
# Usage:
#   ./scripts/run-tests.sh           # run all tests, exit 0 on success
#   ./scripts/run-tests.sh --json    # print JSON summary
#   ./scripts/run-tests.sh --verbose # print per-suite breakdown
#
# Requires: nix (with experimental-features = nix-command flakes pipe-operators)
#           python3 (for JSON formatting in default/verbose modes)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_FILE="$PROJECT_ROOT/test/default.nix"

# Detect nix
if ! command -v nix >/dev/null 2>&1; then
  echo "ERROR: 'nix' not found in PATH." >&2
  echo "Install Nix from https://nixos.org/download.html" >&2
  exit 127
fi

# Argument parsing
mode="${1:-default}"
case "$mode" in
  --json)
    nix eval --impure --file "$TEST_FILE" summary --json
    ;;
  --verbose|-v)
    echo "=== nix-types test suite (verbose) ==="
    echo ""
    nix eval --impure --file "$TEST_FILE" suites --json | python3 -c '
import json, sys
data = json.load(sys.stdin)
for name, suite in sorted(data.items()):
    status = "PASS" if suite["allPassed"] else "FAIL"
    p = suite["passed"]
    t = suite["total"]
    print("  [%s] %-12s  %d/%d passed" % (status, name, p, t))
    for f in suite.get("failures", []):
        print("      FAILED: %s" % f["name"])
        if f.get("error"):
            err = f["error"].replace("\n", " ")[:200]
            print("        error: %s" % err)
'
    echo ""
    nix eval --impure --file "$TEST_FILE" summary --json | python3 -c '
import json, sys
s = json.load(sys.stdin)
print("Total:  %d" % s["total"])
print("Passed: %d" % s["passed"])
print("Failed: %d" % s["failed"])
print("Result: " + ("ALL PASSED" if s["allPassed"] else "SOME FAILED"))
sys.exit(0 if s["allPassed"] else 1)
'
    ;;
  --help|-h)
    cat <<EOF
nix-types test runner

Usage: $0 [OPTION]

Options:
  (default)   Print compact summary, exit 0 on success
  --json      Print JSON summary
  --verbose   Print per-suite breakdown with failures
  --help      Show this help

Exit codes:
  0    All tests passed
  1    Some tests failed
  127  Nix not installed
EOF
    ;;
  *)
    # Default: compact summary
    nix eval --impure --file "$TEST_FILE" summary --json | python3 -c '
import json, sys
s = json.load(sys.stdin)
print("nix-types: %d/%d tests passed" % (s["passed"], s["total"]))
if s["allPassed"]:
    print("ALL PASSED")
else:
    print("%d FAILED" % s["failed"])
sys.exit(0 if s["allPassed"] else 1)
'
    ;;
esac
