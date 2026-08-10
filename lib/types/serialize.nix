# @path: lib/types/serialize.nix
# @description: Serialization of enum instances to plain records.
#
# This is a **pure library-level function** — it does not close over any
# enum-specific state. The enum-carried `Shape.serialize` is a thin alias
# that delegates here.
#
# Public output shape (flat, JSON-friendly):
#   { tag = <variant-name>; typename = <enum-type-name>; value = <normalized-value>; }
#
# `value` is recursively normalized:
#   - null                            for unit variants (non-postable sentinel)
#   - the literal value               for literal variants (int/string/bool/etc.)
#   - the nested instance's `tag`     for enum-typed variants (single instance)
#   - a recursive attrset             for tuple/function variants
#     ({ _0 = "Red"; _1 = "Green"; ... } of nested tags or raw values)
#   - lists and attrsets are recursively serialized
#
# The output contains NO lambdas or internal markers — safe for `toJSON`.

{ config, types }:
let
  # Recursively normalize a value for serialization.
  # - enum instances → their `tag` (string)
  # - attrsets → recursively normalized (preserving keys)
  # - lists → recursively normalized (element-wise)
  # - everything else → kept as-is
  serializeValue = v:
    if v == config.const.non-postable then config.const.non-postable
    else if types.isInst v then v.tag
    else if builtins.isAttrs v then builtins.mapAttrs (_: serializeValue) v
    else if builtins.isList v then map serializeValue v
    else v;
in {
  serialize = enum-instance:
    if !types.isInst enum-instance then
      throw "serialize: expected enum instance, found ${types.descTp enum-instance}"
    else
      {
        tag = enum-instance.tag;
        typename = enum-instance.__meta__.typename;
        value = serializeValue enum-instance.value;
      };
}
