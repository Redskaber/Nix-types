# @path: lib/types/config.nix
# @description: Central configuration & constants for the nix-types library.
#
# All magic strings/sentinels live here. Internal-only — callers should use
# the public API (`isEnum`, `isInst`, `match`, etc.) instead of reading
# these constants directly.
#
# Field naming convention (v3.0):
#   - Public fields on instances: `tag`, `value`, `display` (bare, ergonomic)
#   - Internal metadata: `__meta__`, `__enumInstance__` (dunder, namespaced)
#   - Nix magic: `__toString` (function for string interpolation)
#   - Reserved in user data: `__PORDER__`, `__throw__` (dunder, consistent)

{
  # Sentinel value carried by unit variants (no payload).
  const.non-postable = null;

  keys = {
    # Internal attrs on an enum instance — stripped when computing the
    # "external" view that callers see in the spread of `instance`.
    # Includes both instance fields and enum-type fields to prevent
    # user data from shadowing library functions.
    internal = [
      "tag"
      "value"
      "display"
      "__toString"
      "__meta__"
      "__enumInstance__"
      "__variants__"
      "match"
      "serialize"
    ];

    # External (caller-visible) accessor.
    external.tag = "tag";

    # Reserved keys with special meaning in user-supplied data.
    reserved = {
      __PORDER__ = "__PORDER__"; # explicit ordering key for attrset-match
      __throw__ = "__throw__";   # validator-fn failure marker
    };

    # `builtins.typeOf` values that can be carried as variant values.
    postables = [
      "int" "float" "bool" "null" "string" "path"
      "list" "set" "lambda"
    ];

    # Acceptable return types from a user-supplied validator function:
    #   - bool : pass/fail
    #   - set  : success (returned attrset enriches the value) OR
    #            { __throw__ = "..."; } for failure with a message
    postableValidRstTypes = [ "bool" "set" ];

    # Acceptable top-level input types for `match`.
    matchValidTypes = [ "list" "set" ];

    # Acceptable node types inside a multi-instance pattern tree.
    matchValidMultiInstPatternTypes = [ "set" "lambda" ];

    # Wildcard identifier used in pattern matching.
    matchWildCard = "_";

    # Identity attrs used to detect enum types and instances by duck-typing.
    # Minimal set — only fields that ALL enum types / instances must have.
    typeIdents = [
      "__meta__" "__variants__" "match" "serialize"
    ];
    instIdents = [
      "__enumInstance__" "tag" "value" "display" "__meta__"
    ];
  };

  types = {
    # `typeOf` values considered "literal" (leaf values, no recursion).
    literals = [ "int" "float" "bool" "null" "string" "path" ];
    # `typeOf` values considered "container" (recursive).
    containers = [ "list" "set" ]; # set = attrset
  };
}
