# @path: lib/version.nix
# @description: Library version identity — the single source of truth.
#
# Machine contract (downstream consumers read this, not the README):
#   nix-config (and any flake-input consumer) pins a rev AND asserts
#   `lib.version == "<expected>"` in its test battery, so a rev bump that
#   changes the API surface can never pass silently as "just an upgrade"
#   — the version assertion fails first and names the drift.
#
# Semver discipline (the CHANGELOG records every release under this
# number):
#   major — breaking (instance shape, removed/renamed exports)
#   minor — additive (new exports — like this one — or new validator
#           coverage; behavior of existing faces unchanged)
#   patch — fixes (error messages, internal refactors, docs)
#
# Identity rules:
#   - `version` is a plain string at the top level of `lib` — it must
#     NEVER leak into enum types or instances (the v3.0 cleanup moved
#     instance metadata to `__meta__`; this module joins `lib` only at
#     the top level, and test/cases/version.nix locks that boundary).
#   - The flake's `packages.<sys>.default` derivation name carries the
#     same string, so `nix build` artifacts are versioned identically.
{
  version = "3.6.0";
}
