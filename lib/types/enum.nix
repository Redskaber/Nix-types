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
        meta = types.EnumMeta { typename = parsed-meta.typename; };
      in
      builtins.seq (validators.validateVariantsType variants)
        (if builtins.isList variants then
          constructors.mkEnumInstStructTupleVariants
            (types.EnumInstStruct { inherit meta variants; })
        else
          constructors.mkEnumInstStructPostableVariants
            (types.EnumInstStruct { inherit meta variants; })));
}
