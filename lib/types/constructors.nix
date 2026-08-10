# @path: lib/types/constructors.nix
# @description: Variant instance constructors.
#
# Convert the user's variant descriptors into actual callable constructors
# that produce `VariantInst` records. Dispatch on the descriptor's
# shape (literal / enum-inst / enum-type / tuple / function / attrset).
#
# Design note (carry vs separate):
#   `match` and `serialize` are defined as pure library-level functions
#   (in match.nix and serialize.nix). The enum type carries them as
#   **thin aliases** for ergonomic `Shape.match ...` / `Shape.serialize ...`
#   access.
#
# Instance record shape (v3.0):
#   {
#     tag = "Red";                    # variant name (public)
#     value = null;                   # payload (public)
#     display = "enum::Color::Red";   # pre-computed display string (public)
#     __toString = self: self.display; # Nix magic: enables "${instance}"
#     __meta__ = {                    # enum identity (internal)
#       typename = "Color";
#       variantNames = [ "Red" "Green" "Blue" ];
#     };
#     __enumInstance__ = true;        # duck-type marker (internal)
#   }

{ config, types }:
let
  utils = import ./utils.nix;
  validators = import ./validators.nix { inherit config types; };
  matchMod = import ./match.nix { inherit config types; };
  serializeMod = import ./serialize.nix { inherit config types; };
in rec {
  # --- Argument presentation helpers ----------------------------------

  # Normalize `postable-args` (which may be a single value or a list) into
  # a uniform list form for display purposes.
  mkPostableStringArgs = postable-args:
    if postable-args == config.const.non-postable then [ ]
    else if builtins.isList postable-args then postable-args
    else [ postable-args ];

  # Render a single postable argument to a display string for `display`.
  # Uses the `display` field on nested instances (recursive).
  mkPostableArgDisplay = postable-arg:
    if postable-arg == config.const.non-postable then "<none>"
    else if builtins.isAttrs postable-arg
         && builtins.hasAttr "display" postable-arg
         then postable-arg.display
    else if builtins.isString postable-arg then builtins.toJSON postable-arg
    else if builtins.isInt postable-arg || builtins.isFloat postable-arg
         then builtins.toString postable-arg
    else if builtins.isBool postable-arg then if postable-arg then "true" else "false"
    else if builtins.isList postable-arg then "<list>"
    else if builtins.isAttrs postable-arg then "<attrset>"
    else "<${builtins.typeOf postable-arg}>";

  # Build the `display` string of a variant call:
  #   "enum::TypeName::Variant(arg1,arg2,...)"
  mkVariantDisplay = enum-struct: postable-variant: postable-args:
    (mkPostableStringArgs postable-args)
    |> (pstArgs:
      if pstArgs == [ ] then ""
      else "(${builtins.concatStringsSep "," (builtins.map mkPostableArgDisplay pstArgs)})")
    |> (postable-args-display:
      "enum::${enum-struct.meta.typename}::${postable-variant}${postable-args-display}");

  # --- Value extraction -----------------------------------------------

  # Strip internal keys from an attrset-style postable argument so callers
  # only see their own data when reading the spread on `instance`.
  # Only attrsets are processed; lists and other types return {} (the tuple
  # value is already correctly stored in instance.value via mkMapTuplePostable).
  getBasePostable = postable:
    if builtins.isAttrs postable then builtins.removeAttrs postable config.keys.internal
    else { };

  mkVariantInstValuePostableExpand = postable: getBasePostable postable;

  # Normalize a postable argument into a uniform "value" representation:
  #   - literal: keep as-is
  #   - deep-literal list (e.g., ["a" "b"]): keep as-is (NOT converted to indexed attrs)
  #   - tuple list (e.g., [Color Color Color] args): convert to indexed attrset { _0=...; _1=...; ... }
  #   - attrset: keep as-is
  #   - function: keep as-is (will be called by the validator)
  #   - non-postable sentinel: keep as-is (null)
  #
  # The distinction between deep-literal and tuple is made by the dispatcher
  # (postableDispatchConstructor): deep-literal lists go through the literal
  # path (value kept as a list), tuple lists go through the tuple path
  # (value converted to indexed attrs). Here we just normalize whatever shape
  # we receive.
  mkMapTuplePostable = postable:
    builtins.seq (validators.postable.validateArgTp postable) (
      if postable == config.const.non-postable then config.const.non-postable
      # Deep-literal lists are kept as plain lists (they're literal values).
      else if types.isDeepLiteral postable then postable
      # Non-literal lists (tuple args) are converted to indexed attrsets
      # so callers can access positions by _0, _1, _2, ...
      else if builtins.isList postable then utils.listToIndexedAttrs postable
      # Attrsets and functions are kept as-is.
      else if builtins.isAttrs postable then postable
      else postable # builtins.isFunction postable
    );

  # --- Instance builder (unified) -------------------------------------
  # Builds the actual VariantInst record. This is the SINGLE place where
  # instance records are constructed — all per-shape constructors delegate
  # here, ensuring consistent field layout and avoiding duplication.
  #
  # The spread `(mkVariantInstValuePostableExpand postable-args)` allows
  # caller-supplied attrset data to be merged onto the instance (for
  # function-validator variants that return enriched attrsets).
  mkInstance = enum-struct: variant: postable-args:
    let
      display = mkVariantDisplay enum-struct variant postable-args;
    in
    (mkVariantInstValuePostableExpand postable-args) // {
      tag = variant;
      value = mkMapTuplePostable postable-args;
      inherit display;
      __toString = self: self.display;
      __meta__ = enum-struct.meta;
      __enumInstance__ = true;
    };

  # --- Per-shape constructors ------------------------------------------
  # Each validates its specific argument shape, then delegates to mkInstance.

  postableEnumConstructor =
    enum-struct: postable-variant: postable-value: postable-args:
    builtins.seq
      (validators.postable.validateEnumValue postable-value postable-args)
      (mkInstance enum-struct postable-variant postable-args);

  postableTupleConstructor =
    enum-struct: postable-variant: postable-values: postable-args:
    builtins.seq
      (validators.postable.validateTupleValue
        enum-struct postable-variant postable-values postable-args)
      (mkInstance enum-struct postable-variant postable-args);

  postableFunConstructor =
    enum-struct: postable-variant: postable-values: postable-args:
    let rstpst = postable-values postable-args; in
    builtins.seq
      (validators.postable.validateFunRst rstpst postable-args)
      # Use the validator's returned attrset (if it returned one) to enrich
      # the instance value; otherwise fall back to the original postable-args.
      (mkInstance enum-struct postable-variant
        (if builtins.isAttrs rstpst then rstpst else postable-args));

  # Literal / enum-inst / deep-literal-list / plain-attrset descriptors
  # produce a ready instance (no arguments needed from caller).
  postableLiteralConstructor =
    enum-struct: postable-variant: postable-value:
    mkInstance enum-struct postable-variant postable-value;

  # Dispatch on the descriptor's shape and return the appropriate result:
  #   - instance, for literal / enum-inst descriptors
  #   - function, for enum-type / tuple / function descriptors
  #     (awaiting arguments)
  postableDispatchConstructor = enum-struct: postable-variant: postable-value:
    builtins.seq (validators.postable.validateValue postable-value)
    (types.isLiteral postable-value)
    |> (isLiteral:
      if isLiteral then
        postableLiteralConstructor enum-struct postable-variant postable-value
      else if types.isInst postable-value then
        postableLiteralConstructor enum-struct postable-variant postable-value
      else if types.isEnum postable-value then
        (postable-args:
          postableEnumConstructor enum-struct postable-variant postable-value postable-args)
      else if builtins.isList postable-value then
        if types.isDeepLiteral postable-value then
          postableLiteralConstructor enum-struct postable-variant postable-value
        else
          (postable-args:
            postableTupleConstructor enum-struct postable-variant postable-value postable-args)
      else if builtins.isFunction postable-value then
        (postable-args:
          postableFunConstructor enum-struct postable-variant postable-value postable-args)
      else
        # builtins.isAttrs postable-value (literal attrset fallback)
        postableLiteralConstructor enum-struct postable-variant postable-value);

  # Build the constructor map for all variants of a postable enum.
  mkPostableVariantDispatchs = enum-struct:
    builtins.mapAttrs
      (postable-variant: postable-value:
        postableDispatchConstructor enum-struct postable-variant postable-value)
      enum-struct.variants;

  # --- Tuple (unit) variant constructors -------------------------------

  mkTupleVariant = enum-struct: variant:
    types.TupleVariant {
      name = variant;
      value = mkInstance enum-struct variant config.const.non-postable;
    };

  mkEnumInstStructTupleVariants = enum-struct:
    (map (variant: mkTupleVariant enum-struct variant) enum-struct.variants)
    |> (vars: builtins.listToAttrs vars)
    |> (constructors: mkEnumStructFunction enum-struct constructors);

  # --- Enum-type function bundle ---------------------------------------
  # Attach the standard enum-type functions (match, serialize, metadata)
  # to a constructor map. `match` and `serialize` are **aliases** that
  # delegate to the library-level functions in match.nix / serialize.nix.
  mkEnumStructFunction = enum-struct: constructors:
    (constructors // {
      __meta__ = enum-struct.meta;
      __variants__ = enum-struct.variants;
      match = matchMod.match;
      serialize = serializeMod.serialize;
    });

  mkEnumInstStructPostableVariants = enum-struct:
    (mkPostableVariantDispatchs enum-struct)
    |> (constructors: mkEnumStructFunction enum-struct constructors);
}
