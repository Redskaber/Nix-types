# Consumption Patterns

How real consumers pin, import, and lock `nix-types` in a flake-based Nix
configuration. Every pattern below is **battle-tested in production** by
[nix-config](https://github.com/Redskaber/nix-config) (16 policy tables,
a Result railway, and exhaustive dispatch — the examples are real faces,
not sketches), and each carries the failure mode it exists to prevent.

> Companion docs: [README](../README.md) for the API surface,
> [ARCHITECTURE](ARCHITECTURE.md) for the internals, [CHANGELOG](CHANGELOG.md)
> for release history (semver discipline is defined there).

## 1. Pin the rev — never ride HEAD

```nix
# flake.nix (consumer)
inputs.nix-types.url =
  "github:Redskaber/nix-types/815fc3fa921c243ec0dc9efd39201d05f0990a8a";
```

**Why a 40-hex SHA and not a tag**: this repository has no tags yet; a
commit SHA is the only address that cannot move. Weekly base updates
(e.g. nixpkgs) then no longer drag `nix-types` HEAD along — an upgrade
stops being a surprise and becomes a **deliberate decision** recorded in
the lock diff.

**Failure mode prevented**: your flake evaluates green on Monday and red
on Friday with zero local changes, because the library published a
breaking commit overnight.

## 2. Version contract — assert what you pinned (v3.6+)

Pinning a rev answers *where*; it cannot answer *what*. Since 3.6.0 the
library carries `lib.version` as a top-level export, so a consumer's test
battery can hold both ends of the identity:

```nix
# consumer's test battery (the truthfulness discipline)
{ lib, ... }: {
  # ...
  nt-version = inputs.nix-types.lib.version == "3.6.0";
}
```

```bash
nix eval .#tests.nt-version   # must be true
```

A rev bump that changes the API surface now fails **your** CI first, with
a version assertion that names the drift — instead of a cryptic
"attribute missing" three layers downstream.

**Failure mode prevented**: `flake.lock` updated, tests still green,
production eval breaks on a face the lock diff never mentioned.

## 3. One instance, many consumers — `follows` for siblings

If several of your inputs consume `nix-types` (a shell library building
its FSM on the enum, a config repo using the ADTs), make them share
**your** input:

```nix
# flake.nix (consumer)
inputs = {
  nix-types.url = "github:Redskaber/nix-types/<rev>";
  pdshell.url = "github:redskaber/pdshell";
  pdshell.inputs.nix-types.follows = "nix-types";  # single instance
};
```

Without `follows`, Nix materializes a second `nix-types_2` node in the
lock; the two instances can drift independently on partial updates, and
a value built by one fails predicates in the other.

**Failure mode prevented**: "works on my machine" dispatch tables —
enum instances that are structurally identical but identity-different
across two library instances.

## 4. Policy tables — enums as the config's vocabulary

The main production pattern: domain vocabularies as **postable enums
whose payload rows carry capabilities, policy functions, and set
routing** — data, not `if/else` ladders:

```nix
# consumer's enum table (real shape from a 16-table fleet)
inherit (inputs.nix-types.lib) enum;

editor = enum "editor" {
  #          payload = { caps, policy, sets }
  vim  = { caps = [ "tui" ];  sets.editor-set = [ "vim" ]; };
  emacs = { caps = [ "tui" "daemon" ]; sets.editor-set = [ "emacs" ]; };
  # ...
};
```

Host facts select a variant; **the dispatch layer** (the emitter that
maps variants to target systems) consumes `caps` / `sets` — the config
leaves stay free of both branching and knowledge of each other. This is
the "nix-config as a compiler" shape: lang table → runtime → targets.

**Failure mode prevented**: `if host.editor == "vim" then … else if …`
ladders duplicated per host file — grep-able branches in leaves are the
smell this replaces.

## 5. Result railway — errors as values, one boundary

```nix
# consumer's validation layer (real shape)
inherit (inputs.nix-types.lib) result;

checks = result.andThen
  (v: if builtins.length v.missing > 0
      then result.err "host ${v.name}: missing ${toString v.missing}"
      else result.ok v)
  base;

in result.unwrapOrElse (throw) checks;   # THE single throw boundary
```

`ok`/`err`/`andThen` compose over data-driven pass lists; the diagnostic
string travels as a value and surfaces **verbatim** exactly once, at the
single `unwrapOrElse throw` boundary. Multiple `throw`s scattered through
configuration code is the smell this replaces.

## 6. Exhaustive dispatch — no silent `_` escape

```nix
match shared.version {
  v25_11 = ...;
  v26_05 = ...;
  # deliberately no `_` — a new version must be answered explicitly
}
```

Use the wildcard only where "anything else" is a **true** semantic
statement (a terminal fallback), never as a maintenance shortcut: an
unhandled new variant should fail loudly, not fall into a catch-all.

## 7. When NOT to enum-ify (adjudicated in production)

Not every string-keyed dispatch should become an enum. A real
adjudication ([nix-config's source-scopes verdict]) rejected mechanical
conversion on three grounds, kept here as the checklist:

1. **Default-value scoping** — if schema defaults are declared as plain
   strings (`foo ? "stable"`) in a different module than the table,
   converting the table forces either required-izing the field (boiler-
   plate on every host) or re-wiring the phase that reads the default.
2. **Interpolation consumers** — if the raw string is interpolated into
   diagnostics (`using ${source}`), an enum instance changes the printed
   semantics (label vs. declared text) — unless the display string is
   crafted to match.
3. **Diagnostic quality** — a hand-written `throw` can carry
   *illegal value + legal face + where to fix* in one message; the
   library's type errors carry the first two. Keep the hand-rolled
   error where the third matters.

**Reopen condition**: a `parse`/`fromString` bridge (string → instance
construction, diagnostics carrying the legal face) would remove ground
2 and much of 3 — tracked as an upstream idea, not a promise.

---

*Patterns 1–3 are the **consumption contract** (pin, assert, share);
4–6 are the **usage vocabulary** (tables, railways, exhaustive
dispatch); 7 is the **judgment layer**. A consumer following all three
tiers gets: silent API drift impossible (1+2), instance drift impossible
(3), grep-able zero-branch leaves (4), single error boundary (5), and
loud new-variant failures (6) — the same discipline the library applies
to itself, projected onto its consumers.*

[nix-config's source-scopes verdict]: https://github.com/Redskaber/nix-config/blob/main/docs/architecture/nix-types.md
