# @path: lib/types/default.nix
# @description: Aggregator module — assembles all type-system pieces and
#               exposes the public surface.
#
# Public exports (clean names, no deprecated aliases):
#   { enum, match, serialize,             # core API
#     isEnum, isInst, isType, descTp,     # predicates & descriptors
#     isLiteral, isDeepLiteral, isContainer,
#     isPostable, isPostableValidRst,
#     isMatchInputTp, isMatchMultiInstPatternTp,
#     parseTypeName,
#     addContextFrom, count, escape, ...  # utility helpers
#     lib, types }                        # nested re-exports

let
  config = import ./config.nix;
  utils = import ./utils.nix;
  predicates = import ./predicates.nix { inherit config; };
  matchMod = import ./match.nix { inherit config; types = predicates; };
  serializeMod = import ./serialize.nix { inherit config; types = predicates; };
  enumMod = import ./enum.nix { inherit config; types = predicates; };

  # Collect the core API functions that are re-exported at multiple levels.
  coreApi = {
    inherit (enumMod) enum;
    inherit (matchMod) match;
    inherit (serializeMod) serialize;
  };

  # Collect the predicate functions.
  predicateApi = {
    inherit (predicates)
      isEnum isInst isType descTp
      isLiteral isDeepLiteral isContainer
      isPostable isPostableValidRst
      isMatchInputTp isMatchMultiInstPatternTp
      parseTypeName;
  };
in
# Top-level: core API + predicates + utility helpers + nested re-exports.
coreApi // predicateApi // utils // {
  # `types` = predicates + struct definitions + internal config.
  types = predicates // { inherit config; };
  # `lib` = everything (utils + core API + predicates + config).
  # Provided for callers who prefer the `lib.foo` access style.
  lib = utils // coreApi // predicateApi // { inherit config; };
}
