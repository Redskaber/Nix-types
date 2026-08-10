# @path: lib/types/validators.nix
# @description: Validation layer.
#
# All `throw` calls in the library live here. Error messages include:
#   - context (which enum, which variant, which arg position)
#   - expected vs. actual
#   - a hint on how to fix
#
# Each validator returns `true` on success or throws a descriptive error
# on failure. They never return `false` — that would silently hide bugs.
#
# Naming convention (internal):
#   validators.<category>.<validateXxx>  — grouped by concern
#   validateVariantsType                — top-level (not in a category)

{ config, types }:
let
  utils = import ./utils.nix;
in rec {
  # ---- Top-level variants validator -----------------------------------
  # The `variants` argument to `enum` must be a list (unit-enum) or attrset
  # (postable-enum). An empty list is allowed (produces an enum type with no
  # variants — unusual but valid). An empty attrset is rejected because a
  # postable enum with no variants is never useful.
  validateVariantsType = variants:
    if !types.isContainer variants then
      throw ''
        enum error: Expected list (unit-enum) or attrset (param-enum), found ${types.descTp variants}
      ''
    else if builtins.isAttrs variants && variants == { } then
      throw ''
        enum error: postable enum variants cannot be empty
      ''
    else true;

  # ---- Variant name validator -----------------------------------------
  # Validates that variant names are legal identifiers and don't collide
  # with internal fields. Catches:
  #   - non-string names (would cause uncatchable builtin errors later)
  #   - empty strings / invalid characters
  #   - duplicates (in list form; attrsets can't have duplicate keys)
  #   - collisions with internal fields (__meta__, match, serialize, etc.)
  validateVariantName = name:
    if !builtins.isString name then
      throw "enum error: variant name must be a string, found ${types.descTp name}"
    else if builtins.match "^[A-Za-z_][A-Za-z0-9_-]*$" name == null then
      throw "enum error: invalid variant name '${name}' (must be alphanumeric identifier, optionally with hyphens)"
    else if builtins.elem name config.keys.internal
         || builtins.elem name [ "match" "serialize" "__variants__" ] then
      throw "enum error: variant name '${name}' collides with internal field"
    else true;

  validateVariantNames = variants:
    if builtins.isList variants then
      let
        # Validate each name is a legal identifier (force eagerly).
        validated = builtins.foldl' (status: v:
          builtins.seq (validateVariantName v) status
        ) true variants;
        # Check for duplicates.
        dupCount = builtins.length (utils.unique variants);
      in
      builtins.seq validated (
        if builtins.length variants != dupCount then
          let
            dups = builtins.filter
              (v: (utils.count (x: x == v) variants) > 1)
              (utils.unique variants);
          in
          throw ''
            enum error: duplicate variant names: ${builtins.concatStringsSep ", " dups}
          ''
        else true
      )
    else
      # Attrset: keys are unique by construction, just validate each name.
      let
        names = builtins.attrNames variants;
        validated = builtins.foldl' (status: n:
          builtins.seq (validateVariantName n) status
        ) true names;
      in
      builtins.seq validated true;

  # ---- Postable validators (variant value + argument checking) --------
  postable = rec {
    # Is `v` a valid postable descriptor (something we can wrap in a variant)?
    validateValue = postable-value:
      if types.isPostable postable-value then true
      else throw "Enum::variant: Expected (enum, list, function, literals), found ${types.descTp postable-value}";

    # Validate that `postable-args` is a proper instance of `postable-value`
    # (when postable-value is itself an enum type).
    validateEnumValue = postable-value: postable-args:
      if ! types.isInst postable-args then
        if types.isEnum postable-args then
          throw ''
            Validation failed: Expected ${types.descTp postable-value
            } instance, found enum type ${types.descTp postable-args}.
          ''
        else
          throw ''
            Validation failed: Expected ${types.descTp postable-value
            } instance, found ${types.descTp postable-args}.
          ''
      else if !(builtins.hasAttr "__meta__" postable-value) then
        throw "Validation failed: Constraint enum missing '__meta__' (outdated definition)"
      else if !(types.isType postable-args postable-value) then
        throw ''
          Type mismatch in variant argument:
            Expected: ${types.descTp postable-value}
            Got: ${types.descTp postable-args}
        ''
      else if ! (builtins.hasAttr postable-args.tag postable-value) then
        throw ''
          Validation failed: '${postable-args.tag}' is not a valid variant of enum.
          Available variants: ${builtins.concatStringsSep ", " (builtins.attrNames postable-value)}
        ''
      else true;

    # Argument count check for tuple variants.
    validateTupleCount =
      enum-struct: postable-variant: postable-values: postable-args:
      let
        enumTypes-count = builtins.length postable-values;
        enumInsts-count = builtins.length postable-args;
      in
      if enumTypes-count == enumInsts-count then true
      else throw ''
        Argument count mismatch in ${enum-struct.meta.typename}::${postable-variant}:
          Expected ${builtins.toString enumTypes-count} arguments: [${builtins.concatStringsSep ", " (
            map (desc:
              if types.isEnum desc then types.descTp desc
              else if builtins.isList desc then "tuple<...>"
              else if builtins.isFunction desc then "validator-fn"
              else types.descTp desc
            ) postable-values
          )}]
          Got ${builtins.toString enumInsts-count} arguments
      '';

    # Validate a single tuple position. Recurses into nested tuples.
    validateTuplePositionArg = postable-value: postable-arg: postable-ctx:
      let
        ctx-info = "at ${postable-ctx.path} (variant '${postable-ctx.variant}' of enum '${postable-ctx.enumType}')";
        exp-type = builtins.typeOf postable-value;
        act-type = builtins.typeOf postable-arg;
      in
      if types.isLiteral postable-value then
        if exp-type == act-type then true
        else throw ''
          enum error: Type mismatch ${ctx-info}:
          Expected ${exp-type}, found ${act-type}
        ''
      else if types.isEnum postable-value then
        builtins.seq (validateEnumValue postable-value postable-arg) { }
      else if builtins.isList postable-value then
        if ! (builtins.isList postable-arg) then
          throw ''
            enum error: Type mismatch ${ctx-info}:
            Expected tuple (list), found ${act-type}
          ''
        else if (builtins.length postable-value) != (builtins.length postable-arg) then
          throw ''
            enum error: Tuple length mismatch ${ctx-info}:
            Expected ${builtins.length postable-value}, found ${builtins.length postable-arg}
          ''
        else
          builtins.foldl' (status: index:
            let
              nested-pctx = postable-ctx // {
                path = "${postable-ctx.path}[${builtins.toString index}]";
              };
            in
            builtins.seq
              (validateTuplePositionArg
                (builtins.elemAt postable-value index)
                (builtins.elemAt postable-arg index)
                nested-pctx)
              status
          ) true (builtins.genList (n: n) (builtins.length postable-value))
      else if builtins.isFunction postable-value then
        # Route nested function validators through validateFunRst so that
        # { __throw__ = "..." } returns are converted to actual throws,
        # consistent with the top-level function-validator path.
        builtins.seq (validateFunRst (postable-value postable-arg) postable-arg) true
      else
        throw ''
          enum error: Unsupported type descriptor ${ctx-info}: ${types.descTp postable-value}
        '';

    # Validate every position of a tuple variant's arguments.
    validateTuplePositionType =
      enum-struct: postable-variant: postable-values: postable-args:
      let
        postable-position-arg-ctx = {
          enumType = enum-struct.meta.typename;
          variant = postable-variant;
          path = "args";
        };
        enumTypes-count = builtins.length postable-values;
        validators-list = builtins.genList (index:
          validateTuplePositionArg
            (builtins.elemAt postable-values index)
            (builtins.elemAt postable-args index)
            (postable-position-arg-ctx // { path = "args[${builtins.toString index}]"; })
        ) enumTypes-count;
      in
      builtins.foldl' (status: validator-parg: builtins.seq validator-parg status) true validators-list;

    validateTupleValue =
      enum-struct: postable-variant: postable-values: postable-args:
      builtins.seq
        (validateTupleCount enum-struct postable-variant postable-values postable-args)
        (validateTuplePositionType enum-struct postable-variant postable-values postable-args);

    # Validate the return value of a user-supplied validator function.
    # Allowed: true | attrset (success, may be empty — enriches the instance),
    #          false | { __throw__ = "..." } (failure).
    validateFunRst = rst-postable: _postable-args:
      if types.isPostableValidRst rst-postable then
        if rst-postable == false then
          throw ''
            [custom-handle] Validation failed for arguments (return false).
            Check validator logic or input constraints.
          ''
        else if types.isEnum rst-postable then
          throw ''
            Validation only result (bool | error attrset), find enum type ${types.descTp rst-postable}
          ''
        else if types.isInst rst-postable then
          throw ''
            Validation only result (bool | error attrset), find enum instance ${types.descTp rst-postable}
          ''
        else if builtins.isAttrs rst-postable && rst-postable ? __throw__ then
          throw ''
            [custom-handle] Validation failed:
              ${rst-postable.__throw__}
          ''
        else rst-postable
      else
        throw ''
          Enum Validation Error: Expected return bool or attr error, find ${types.descTp rst-postable}.
        '';

    # Validate that a variant descriptor type is supported.
    validateArgTp = postable:
      if (types.isLiteral postable)
         || (types.isContainer postable)
         || builtins.isFunction postable then true
      else
        throw ''
          enum::args unsupported type
            Expected type (literals | function | list | attrs(enum,inst),...),
            find ${types.descTp postable}
        '';
  };

  # ---- Match-input validators -----------------------------------------
  match = rec {
    validateInputType = input:
      if types.isMatchInputTp input then true
      else throw ''
        enum::match: Invalid input type '${builtins.typeOf input}'
        Expected: [Inst]enum instance | [List]list of enum instances | [Attr]attrset of enum instances
        Find: ${types.descTp input}.
      '';

    validateInputNonEmpty = input:
      if builtins.isList input && input != [ ] then true
      else if builtins.isAttrs input && input != { } then true
      else
        throw ''
          enum::match: Empty input '${if builtins.isList input then "[]" else "{}"}'
          Expected: enum-instance(s) [list or attrset]
          Find: ${types.descTp input}.
        '';

    # Validate that all elements/values in the input are enum instances.
    # Without this, accessing `.tag` on a non-instance produces an
    # uncatchable builtin error.
    validateInputElements = input:
      if builtins.isList input then
        let
          bad = builtins.filter (x: !types.isInst x) input;
        in
        if bad == [ ] then true
        else throw ''
          enum::match: list elements must be enum instances
            First non-instance element: ${types.descTp (builtins.head bad)}
        ''
      else if builtins.isAttrs input then
        let
          badKeys = builtins.filter (k: !types.isInst input.${k}) (builtins.attrNames input);
        in
        if badKeys == [ ] then true
        else
          let k = builtins.head badKeys; in
          throw ''
            enum::match: attrset values must be enum instances
              Key '${k}' has: ${types.descTp input.${k}}
          ''
      else true;

    validatePatternsType = patterns:
      if builtins.isAttrs patterns then true
      else
        throw ''
          enum::match: Expected patterns is attrset, found ${types.descTp patterns}.
        '';

    validateOrderKeyTp = match-porder:
      if !(builtins.isList match-porder
           && builtins.all (key: builtins.isString key) match-porder) then
        throw ''
          enum::match: Expected __PORDER__ must be a list of strings,
          found ${types.descTp match-porder}.
        ''
      else if builtins.length match-porder != builtins.length (utils.unique match-porder) then
        let
          dups = builtins.filter
            (k: (utils.count (x: x == k) match-porder) > 1)
            (utils.unique match-porder);
        in
        throw ''
          enum::match: __PORDER__ contains duplicate keys: ${builtins.concatStringsSep ", " dups}
        ''
      else true;

    validateOrderKeyCount = input: match-porder:
      let input-count = builtins.length (builtins.attrNames input); in
      if input-count == builtins.length match-porder then true
      else
        throw ''
          enum::match: Expected __PORDER__ length(members) = length(inputs),
          found ${builtins.toString input-count} != ${builtins.toString (builtins.length match-porder)}.
        '';

    validateOrderKeyMapping = input: match-porder:
      if builtins.all (k: builtins.hasAttr k input) match-porder then true
      else
        throw ''
          enum::match: Input missing keys from '${config.keys.reserved.__PORDER__}': ${
            builtins.concatStringsSep ", " (
              builtins.filter (k: !builtins.hasAttr k input) match-porder
            )
          }'';

    validateMultiPatternTp = path: node:
      if types.isMatchMultiInstPatternTp node then true
      else
        throw ''
          Invalid pattern structure at '${if path == [ ] then "<root>" else builtins.concatStringsSep "." path}':
            Expected function or nested attrset, got ${types.descTp node}
            Fix: Patterns must be nested attrsets ending in functions
            (e.g., Red.Circle.local = {c,s,p}: ...)
        '';

    validateMultiPatternUnique = patternKeys: uniqueKeys:
      if (builtins.length patternKeys) == (builtins.length uniqueKeys) then true
      else
        let
          dups = builtins.filter
            (k: (utils.count (x: x == k) patternKeys) > 1) uniqueKeys;
        in
        throw ''
          Pattern conflict: Duplicate pattern path(s) detected. Check: ${
            builtins.concatStringsSep ", " dups
          }'';

    validateMultiMatchRst =
      matched: params-mapping: len: instanceTags: patternList:
      if (matched != null) then true
      else
        let
          avail = builtins.map (p: p.originalKey) patternList;
          wildcard = builtins.concatStringsSep "."
            (builtins.genList (_: config.keys.matchWildCard) len);
          paramExample =
            if params-mapping != null then
              builtins.concatStringsSep ", " params-mapping
            else
              builtins.concatStringsSep ", "
                (builtins.genList (i: "_${builtins.toString (i + 1)}") len);
          inputHint =
            if params-mapping != null then
              "\nNote: Attrset keys sorted dictionary-order: [${builtins.concatStringsSep ", " params-mapping}]"
            else "";
        in
        throw ''
          Pattern match non-exhaustive for tags [${builtins.concatStringsSep ", " instanceTags}]!${inputHint}
          Defined patterns: ${if avail == [ ] then "(none)" else builtins.concatStringsSep ", " avail}
          Defined patterns (ordered by specificity): ${builtins.concatStringsSep "\n  " (
            builtins.map (p: "${builtins.toString p.specificity}: ${p.originalKey}") patternList
          )}
          Hint: Add wildcard handler:
            ${wildcard} = { ${paramExample} }: ...;
          Tip: More specific patterns (fewer '_') match first.
               Add missing pattern or wildcard '${wildcard}'.
        '';
  };
}
