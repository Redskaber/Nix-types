# @path: lib/types/enum.nix
# @description: Public enum factory entry point.
#
#   enum : string -> variants -> EnumType
#
#   variants = [ "A" "B" "C" ]                (unit / tuple-less enum)
#   variants = { A = <postable>; B = ...; }   (postable / value-carrying enum)
#
# Forces typename validation eagerly so an invalid name throws at the call
# site rather than being deferred until a variant is accessed.

{ config, types }:
let
  validators = import ./validators.nix { inherit config types; };
  constructors = import ./constructors.nix { inherit config types; };
in
{
  enum = enumType: variants:
    let
      parsed-meta = types.parseTypeName enumType;
    in
    builtins.seq (parsed-meta.typename)
      (let
        # Include variant names in meta so isType can distinguish enums
        # with the same typename but different variant sets.
        variantNames =
          if builtins.isList variants then variants
          else builtins.attrNames variants;
        meta = types.EnumMeta {
          typename = parsed-meta.typename;
          inherit variantNames;
        };
      in
      builtins.seq (validators.validateVariantsType variants)
        (if builtins.isList variants then
          constructors.mkEnumInstStructTupleVariants
            (types.EnumInstStruct { inherit meta variants; })
        else
          constructors.mkEnumInstStructPostableVariants
            (types.EnumInstStruct { inherit meta variants; })));
}
