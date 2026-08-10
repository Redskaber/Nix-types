# @path: lib/default.nix
# @description: Public entry point of the nix-types library.
#
# Combines the core type system and the ADT extensions.
#
# Public exports (top-level):
#   Core:     enum, match, serialize, isEnum, isInst, isType, descTp, ...
#   Utils:    trim, splitString, zipListsWith, listToIndexedAttrs, ...
#   ADT:      Option, Result, some, none, ok, err,
#             optionToResult, resultToOption
#   Nested:   types (predicates + struct defs + config), lib (utils + core API + predicates + config),
#             option (namespaced Option helpers), result (namespaced Result helpers)
#
# Note: Option/Result helpers (unwrap, map, etc.) are namespaced under
# `option.*` and `result.*` to avoid name collisions. Only the constructors
# (some, none, ok, err) and the enum types (Option, Result) are top-level.
#
# Note: `m.lib` intentionally EXCLUDES ADT helpers (to keep the namespace
# clean). Use `m.option.*` / `m.result.*` for ADT operations.

let
  core = import ./types;
  adt = import ./adt { inherit (core) enum; };
in
  core // adt
