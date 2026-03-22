let
  # --------------------------------------------------------------------------
  # LAYER 0: 配置与常量
  # --------------------------------------------------------------------------
  config = {
    debug.enable = true;
    const = {
      non-postable = null;
    };
    keys = {
      generic = {
        isGenericInst = "isGenericInst";
        genericParams = "genericParams";
      };
      internal = [
        "__IS_ENUM_INSTANCE_MASKER_V1__"
        "toString"
        "value"
        "type"
      ];
      external = { tag = "tag"; };
      reserved = { __PORDER__ = "__PORDER__"; __throw = "__throw"; };
      postables = [
        "int" "float" "bool" "null" "string" "path"
        "list" "set" "lambda"  # lambda = function
      ];
      postableValidRstTypes = [ "bool" "set" ]; # enumInst in set
      matchValidTypes = [ "list" "set" ];
      matchValidMultiInstPatternTypes = [ "set" "lambda" ];
      matchWildCard = "_";
      genericIdents = [ "__typename__" "__isGeneric__" "__genericParams__" "__arity__" "__functor" "instantiate" ];
      typeIdents = [ "__typename__" "__meta__" "match" "serialize" ];
      instIdents = [ "__IS_ENUM_INSTANCE_MASKER_V1__" "type" "tag" "value" "toString" ];
      fn.toString = "toString";
    };
    types = {
      literals = [ "int" "float" "bool" "null" "string" "path" ];
      containers = [ "list" "set" ]; # set = attrset
    };
  };

  # --------------------------------------------------------------------------
  # LAYER 1: 核心工具库
  # --------------------------------------------------------------------------
  lib = rec {
    fn-addContextFrom = src: target: builtins.substring 0 0 src + target;
    fn-count = pred: builtins.foldl' (c: x: if pred x then c + 1 else c) 0;
    fn-escape = list: builtins.replaceStrings list (map (c: "\\${c}") list);
    fn-escapeRegex = fn-escape (fn-stringToCharacters "\\[{()^$?*+|.");
    fn-min = x: y: if x < y then x else y;
    fn-optionalString = cond: string: if cond then string else "";
    fn-unique = builtins.foldl' (acc: e: if builtins.elem e acc then acc else acc ++ [ e ]) [ ];
    fn-replacePlaceholders = value: substitutions:
      if builtins.isString value && builtins.hasAttr value substitutions
      then substitutions.${value}
      else if builtins.isList value
      then map (elem: fn-replacePlaceholders elem substitutions) value
      else if builtins.isAttrs value
      then builtins.mapAttrs (k: v: fn-replacePlaceholders v substitutions) value
      else value;
    fn-stringToCharacters = s: builtins.genList (p: builtins.substring p 1 s) (builtins.stringLength s);
    fn-splitString = sep: s:
      let
        splits = builtins.filter builtins.isString (
          builtins.split (fn-escapeRegex (toString sep)) (toString s)
        );
      in map (fn-addContextFrom s) splits;
    fn-trim = fn-trimWith { start = true; end = true; };
    fn-trimWith = { start ? false, end ? false, }:
      let
        chars = " \t\r\n";
        regex =
          if start && end then
            "[${chars}]*(.*[^${chars}])[${chars}]*"
          else if start then
            "[${chars}]*(.*)"
          else if end then
            "(.*[^${chars}])[${chars}]*"
          else
            "(.*)";
      in
      s:
      let
        res = builtins.match regex s;
      in fn-optionalString (res != null) (builtins.head res);
    fn-zipListsWith = f: fst: snd:
      (fn-min (builtins.length fst) (builtins.length snd))
      |>(min-length:
        builtins.genList (n: f
          (builtins.elemAt fst n)
          (builtins.elemAt snd n)
        ) min-length
      );
    fn-indexedAttrs = list: extractor:
      let length = builtins.length list; in
      builtins.listToAttrs (builtins.genList (index: {
        name = "_${builtins.toString index}";
        value = extractor (builtins.elemAt list index);
      }) length);
    fn-listToIndexedAttrs = list: fn-indexedAttrs list (x: x);

    __fn-logger__ = msg: content: func:
      if config.debug.enable then builtins.trace "${msg}\t\t${func content}" content
      else content;
  };

  # --------------------------------------------------------------------------
  # LAYER 2: 类型系统
  # --------------------------------------------------------------------------
  types = rec {
    fn-isLiteral = v: builtins.any (t: (builtins.typeOf v) == t) config.types.literals;
    fn-isContainer = v: builtins.any (t: (builtins.typeOf v) == t) config.types.containers;
    fn-isEnum = v: (builtins.isAttrs v) && (builtins.all (k: builtins.hasAttr k v) config.keys.typeIdents);
    fn-isInst = v: (builtins.isAttrs v) && (builtins.all (k: builtins.hasAttr k v) config.keys.instIdents);
    fn-isGeneric = v: (builtins.isAttrs v) && ((builtins.all (k: builtins.hasAttr k v) config.keys.genericIdents) && v.__isGeneric__);
    fn-isPostable = v: builtins.any (t: (builtins.typeOf v) == t) config.keys.postables;
    fn-isPostableValidRst = v: builtins.any (t: (builtins.typeOf v) == t) config.keys.postableValidRstTypes;
    fn-isMatchInputTp = v: builtins.any (t: (builtins.typeOf v) == t) config.keys.matchValidTypes;
    fn-isMatchMultiInstPatternTp = v: builtins.any (t: (builtins.typeOf v) == t) config.keys.matchValidMultiInstPatternTypes;
    fn-isType = v: t:
      if (fn-isGeneric v)   then v == t
      else if (fn-isEnum v) && (t ? __meta__) then v.__meta__ == t.__meta__
      else if (fn-isInst v) && (t ? __meta__) then v.type == t.__meta__
      else false;
    fn-descTp = v:
      if fn-isGeneric v   then "enum::${v.__typename__}<${builtins.concatStringsSep "," v.__genericParams__}>"
      else if fn-isEnum v then "enum::${v.__typename__}${
        if v.__meta__.isGenericInst then
          "<${builtins.concatStringsSep "," (builtins.attrValues v.__meta__.rParams)}>"
        else ""
      }"
      else if fn-isInst v then v.toString
      else builtins.typeOf v;
    fn-parseTypeSignature = type-signature:
      let
        trimmed = lib.fn-trim type-signature;
        genericMatch = builtins.match "^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*<[[:space:]]*([^<>]+)[[:space:]]*>$" trimmed;
        simpleMatch = builtins.match "^([A-Za-z_][A-Za-z0-9_]*)$" trimmed;
        fn-isValidParam = p: (builtins.match "^[A-Za-z_][A-Za-z0-9_]*$" (lib.fn-trim p)) != null;

        fn-processGeneric = typename: raw-params-str:
          let
            rawParams = lib.fn-splitString "," raw-params-str;
            cleaned = map lib.fn-trim rawParams;
            nonEmpty = builtins.filter (p: p != "") cleaned;
          in
            builtins.seq (validators.types.fn-validator_parseTypeGenericParamsHasEmptySolt rawParams type-signature) (
              builtins.seq (validators.types.fn-validator_parseTypeGenericParamsNonEmpty nonEmpty type-signature) (
                builtins.seq (validators.types.fn-validator_parseTypeGenericParamsValid fn-isValidParam nonEmpty type-signature) (
                  types.EnumInstMeta {
                    typename = typename;
                    gParams = nonEmpty;
                    rParams = [];
                    isGeneric = true;
                    isGenericInst = false;
                    genericParams = {};
                  }
                )
              )
            );
        # Process non-generic case
        fn-processSimple = typename:
          types.EnumInstMeta {
            typename = typename;
            gParams = [];
            rParams = [];
            isGeneric = false;
            isGenericInst = false;
            genericParams = {};
          };

      in
      builtins.seq (validators.types.fn-validator_parseTypeGenericMatchType genericMatch simpleMatch type-signature) (
        if genericMatch != null then
          fn-processGeneric (builtins.elemAt genericMatch 0) (builtins.elemAt genericMatch 1)
        else # ssimpleMatch
          fn-processSimple (builtins.elemAt simpleMatch 0)
      );

    # Enum::EnumGenericTypeStruct
    EnumGenericTypeStruct = {
      __typename__,
      __isGeneric__ ? false,
      __genericParams__ ? [],
      __arity__ ? 0,
      __functor,
      instantiate,
    } @generic-params: generic-params;

    # Enum::EnumRealStruct

    # Enum::<TupleVariant|PostableVariant>::Type::Meta
    # { meta={...}; ... }
    EnumInstMeta = {
      typename,
      isGeneric ? false,
      gParams ? [],
      rParams ? {},
      isGenericInst ? false,
      genericParams ? {},
      ...
    }@params: params;

    # Struct::EnumInstStruct
    # { ... }
    EnumInstStruct = {
      meta ? EnumInstMeta,
      variants ? TupleVariant.value || PostableVariant.value,
    } @params: params;

    # Struct::EnumTypeFuncs
    # { ... }
    EnumTypeFuncs = {
      __typename__,
      __meta__,
      match,
      serialize,
      # toType,
      ...
    } @funcs: funcs;

    # Enum::<TupleVariant|PostableVariant>::Variant::Instance::VariantInstValueBase
    # { ... }
    VariantInstValueBase = {
      tag,
      type ? EnumInstMeta,
      value,
      __IS_ENUM_INSTANCE_MASKER_V1__,
      toString,
    } @params: params;

    # Enum::PostableVariant::Variant::Instance::VVariantInstValuePostable
    VariantInstValuePostable = {
      # User custom Postable define and used ...
    };

    # Enum::TupleVariant::Variant
    # { name=value; }
    TupleVariant = {
      name,
      value ? VariantInstValueBase,
    } @params: params;

    # Enum::PostableVariant::Variant
    # { name=value; }
    PostableVariant = {
      name,
      value ? VariantInstValuePostable // VariantInstValueBase,
    } @params: params;

  };

  # --------------------------------------------------------------------------
  # LAYER 3: 验证层
  # --------------------------------------------------------------------------
  validators = {
    types = {
      fn-validator_parseTypeGenericParamsHasEmptySolt = rawParams: type-signature:
        if (builtins.any (p: lib.fn-trim p == "") rawParams) then
          throw ''
            Invalid generic syntax in '${type-signature}'
            → Empty parameter slot detected (e.g., trailing comma, consecutive commas)
            Examples of INVALID patterns: "Demo<T,>", "Box<A,,B>", "List<,T>"
            Fix: Ensure every comma separates two valid identifiers
          ''
        else true;
      fn-validator_parseTypeGenericParamsNonEmpty = cleaned-nonEmpty: type-signature:
        if cleaned-nonEmpty == [] then
          throw ''
            Invalid generic syntax in '${type-signature}'
            → Generic parameter list cannot be empty
            Example: "Container<>" is invalid. Use "Container" for non-generic type.
          ''
        else true;
      fn-validator_parseTypeGenericParamsValid = fn-isValidParam: cleaned-nonEmpty: type-signature:
        if !(builtins.all fn-isValidParam cleaned-nonEmpty) then
          let
            invalid = builtins.filter (p: !(fn-isValidParam p)) cleaned-nonEmpty;
          in
          throw ''
            Invalid generic parameter(s) in '${type-signature}'
            → Found invalid identifier(s): ${builtins.concatStringsSep ", " invalid}
            Rules: Must start with letter/_, contain only letters, digits, or underscores
            Example: [OK]"MyType<Valid1, _ok>" | [ERR]"MyType<123, hy-phen>"
          ''
      else true;
      fn-validator_parseTypeGenericMatchType = genericMatch: simpleMatch: type-signature:
        if genericMatch == null && simpleMatch == null then
          throw ''
            Unparseable type signature: '${type-signature}'

            Expected formats:
              • Non-generic: "TypeName"          (e.g., "User", "HttpResponse")
              • Generic:     "TypeName<Param1, Param2>" (e.g., "Result<T, E>", "Vec<Item>")

            Common errors detected:
              • Nested brackets:        "Wrapper<A<B>>" → Use flat parameters only
              • Mismatched brackets:    "List<T" or "Map<K>>"
              • Invalid characters:     "Hyphen-Type<T>", "NumberStart<1T>"
              • Whitespace issues:      "Bad < T >" (no space before <)

            Tip: Generic parameters must be simple identifiers (no spaces, brackets, or operators)
          ''
        else true;
    };

    generic = rec {
      fn-validator_genericInvalidPattern = meta: variants:
        if builtins.isAttrs variants then true
        else throw ''
          enum error: Generic enum '${meta.typename
          }' requires attrset variants (parameterized). Tuple variants (list) are invalid for generics.
        '';
      /* ---------- STAGE 1: GENERIC ARG VALIDATION (CRITICAL BARRIER) ---------- */
      fn-validator_genericParamRealType = real-type:
        if (types.fn-isEnum real-type) || (types.fn-isLiteral real-type) then true
        else throw ''
            enum error: Generic Instantiator validator.
              Invalid generic params type.
              Expected Generic Instantiator real type (enum,int,float,bool,null,path,string). found `${types.fn-descTp real-type}`.
          '';
      fn-validator_genericSupportRealTypeParams = generic-realtypes:  # onlylist-params
        builtins.foldl' (status: realtype:
          builtins.seq (fn-validator_genericParamRealType realtype) status
        ) true generic-realtypes;
      fn-validator_genericTupleRealTypeCountCheker = generic-enum-meta: generic-tuple-realtypes: generic-labelparams-length: generic-realtype-length:
        if generic-labelparams-length == generic-realtype-length then true else throw ''
          enum error: Generic instantiator validator tuple generic-labelparams-length != generic-realtyps-length: ${
            builtins.toString generic-labelparams-length} != ${builtins.toString generic-realtype-length}
            fragment:
              generic-labelparams: ${builtins.toString generic-enum-meta.gParams};
              generic-realtypes: ${
                builtins.toString (
                  map (realparam:
                    "${fn-mkGenericParamRealType realparam}"
                  ) generic-tuple-realtypes
                )
              };
          '';
      fn-validator_genericTupleRealType = generic-enum-meta: generic-tuple-realtypes:
        let
          generic-labelparams-length = builtins.length generic-enum-meta.gParams;
          generic-realtype-length = builtins.length generic-tuple-realtypes;
          validator-count-cheker = fn-validator_genericTupleRealTypeCountCheker
            generic-enum-meta
            generic-tuple-realtypes
            generic-labelparams-length
            generic-realtype-length;
          validator-rparams-support-checker = fn-validator_genericSupportRealTypeParams generic-tuple-realtypes;
        in
          builtins.seq validator-count-cheker validator-rparams-support-checker;
      fn-validator_genericAttrRealTypeCountCheker = generic-enum-meta: generic-attr-realtypes: generic-labelparams-length: generic-realtype-length:
        if generic-labelparams-length == generic-realtype-length then true else throw ''
          enum error: Generic instantiator validator tuple generic-labelparams-length != generic-realtyps-length: ${
            builtins.toString generic-labelparams-length} != ${builtins.toString generic-realtype-length}
            fragment:
              generic-labelparams: ${builtins.toString generic-enum-meta.gParams};
              generic-realtypes: ${
                builtins.toString (
                  builtins.attrValues (
                    builtins.mapAttrs (lebal: realtype:
                      "${lebal}:${fn-mkGenericParamRealType realtype}"
                    ) generic-attr-realtypes
                  )
                )
              };
          '';
      fn-validator_genericAttrRealTypeLabelCheker = generic-enum-meta: generic-attr-realtypes:
        if generic-enum-meta.gParams == (builtins.attrNames generic-attr-realtypes) then true else throw ''
          enum error: Generic instantiator validator attrs generic-label-names != generic-reallabel-names:
            fragment:
              generic-label-names: ${builtins.toString generic-enum-meta.gParams};
              generic-reallabel-namess: ${
                builtins.toString (builtins.attrNames generic-attr-realtypes)
              };
          '';
      fn-validator_genericAttrRealType = generic-enum-meta: generic-attr-realtypes:
        let
          generic-labelparams-length = builtins.length generic-enum-meta.gParams;
          generic-realtype-length = builtins.length (builtins.attrNames generic-attr-realtypes);
          validator-count-cheker = fn-validator_genericAttrRealTypeCountCheker
            generic-enum-meta
            generic-attr-realtypes
            generic-labelparams-length
            generic-realtype-length;
          validator-label-cheker = fn-validator_genericAttrRealTypeLabelCheker
            generic-enum-meta
            generic-attr-realtypes;
          validator-rparams-support-checker = fn-validator_genericSupportRealTypeParams
            (builtins.attrValues generic-attr-realtypes);
        in
          builtins.seq validator-count-cheker (
            builtins.seq validator-label-cheker validator-rparams-support-checker
          );
      fn-validator_genericRealTypeDispatcher = generic-enum-meta: generic-realtype-args:
        if builtins.isList generic-realtype-args
          then fn-validator_genericTupleRealType generic-enum-meta generic-realtype-args
        else if types.fn-isEnum generic-realtype-args then
          throw ''
            enum error: Generic Instantiator validator.
              Expected Generic Instantiator params type (list | attr), found enum type.
          ''
        else if builtins.isAttrs generic-realtype-args
          then fn-validator_genericAttrRealType generic-enum-meta generic-realtype-args
        else throw ''
            enum error: Generic Instantiator validator.
              Expected Generic Instantiator params type (list | attr), found ${types.fn-descTp generic-realtype-args}.
          '';
    };

    postable = rec {
      fn-validator_postableValue = postable-value:
        if types.fn-isPostable postable-value then true
        else throw "Enum::variant: Expected (enum, list, function, literals), found ${types.fn-descTp postable-value}";

      fn-validator_postableEnumValue = postable-value: postable-args: # enum: instance:
        if ! types.fn-isInst postable-args then
          if types.fn-isEnum postable-args then
            throw ''
              Validation failed: Expected ${types.fn-descTp postable-value
              } instance, found enum type ${types.fn-descTp postable-args}.
            ''
          else
            throw ''
              Validation failed: Expected ${types.fn-descTp postable-value
              } instance, found ${types.fn-descTp postable-args}.
            ''
        else if !(builtins.hasAttr "__meta__" postable-value) then
          throw "Validation failed: Constraint enum missing '__meta__' (outdated definition)"
        else if !(types.fn-isType postable-args postable-value) then
          throw ''
            Type mismatch in variant argument:
              Expected: ${types.fn-descTp postable-value}
              Got: ${types.fn-descTp postable-args}
          ''
        else if ! (builtins.hasAttr postable-args.tag postable-value)
          then throw ''
            Validation failed: '${postable-args.tag}' is not a valid variant of enum.
            Available variants: ${builtins.concatStringsSep ", " (builtins.attrNames postable-value)}
          ''
        else true;

      fn-validator_postableTupleCountCheker = enum-struct: postable-variant: postable-values: postable-args:
        let
          enumTypes-count = builtins.length postable-values;
          enumInsts-count = builtins.length postable-args;
        in
        if (enumTypes-count == enumInsts-count) then true else throw ''
          Argument count mismatch in ${enum-struct.meta.typename}::${postable-variant}:
            Expected ${builtins.toString enumTypes-count} arguments: [${builtins.concatStringsSep ", " (
              map (desc:
                if types.fn-isEnum desc then types.fn-descTp desc
                else if builtins.isList desc then "tuple<...>"
                else if builtins.isFunction desc then "validator-fn"
                else types.fn-descTp desc
              ) postable-values
            )}]
            Got ${builtins.toString enumInsts-count} arguments
        '';
      fn-validator_postableTuplePositionArg = postable-value: postable-arg: postable-ctx:
        let
          ctx-info = "at ${postable-ctx.path} (variant '${postable-ctx.variant}' of enum '${postable-ctx.enumType}')";
          exp-type = builtins.typeOf postable-value;
          act-type = builtins.typeOf postable-arg;
        in
        if types.fn-isLiteral postable-value then
          if exp-type == act-type then true else throw ''
            enum error: Type mismatch ${ctx-info}:
            Expected ${exp-type}, found ${act-type}
          ''
        else if types.fn-isEnum postable-value then
          builtins.seq (validators.postable.fn-validator_postableEnumValue postable-value postable-arg) {}
        else if builtins.isList postable-value then
          if ! (builtins.isList postable-arg) then throw ''
            enum error: Type mismatch ${ctx-info}:
            Expected tuple (list), found ${act-type}
            ''
          else if (builtins.length postable-value) != (builtins.length postable-arg) then throw ''
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
                builtins.seq (fn-validator_postableTuplePositionArg
                  (builtins.elemAt postable-value index)
                  (builtins.elemAt postable-arg index)
                  nested-pctx
                ) status
            ) true (builtins.genList (n: n) (builtins.length postable-value))
        else if builtins.isFunction postable-value then
          postable-value postable-arg
        else throw ''
          enum error: Unsupported type descriptor ${ctx-info}: ${types.fn-descTp postable-value}
        '';
      fn-validator_postableTuplePositionType = enum-struct: postable-variant: postable-values: postable-args:
        let
          postable-position-arg-ctx = {
            enumType = enum-struct.meta.typename;
            variant = postable-variant;
            path = "args";
          };
          enumTypes-count = builtins.length postable-values;
          validators = builtins.genList (index:
            fn-validator_postableTuplePositionArg
              (builtins.elemAt postable-values index)
              (builtins.elemAt postable-args index)
              (postable-position-arg-ctx // { path = "args[${builtins.toString index}]"; })
          ) enumTypes-count;
        in
          builtins.foldl' (status: validator-parg: builtins.seq validator-parg status) true validators;

      fn-validator_postableTupleValue = enum-struct: postable-variant: postable-values: postable-args:
        builtins.seq
          (fn-validator_postableTupleCountCheker enum-struct postable-variant postable-values postable-args)
          (fn-validator_postableTuplePositionType enum-struct postable-variant postable-values postable-args);

      fn-validator_postableFunRst = rst-postable: postable-args:
        if types.fn-isPostableValidRst rst-postable then
          if rst-postable == false then
            throw ''
              [custom-handle] Validation failed for arguments (return false). Check validator logic or input constraints.
            ''
          else if types.fn-isEnum rst-postable then
            throw ''
              Validation only result (bool | error attrset), find enum type ${types.fn-descTp rst-postable}
            ''
          else if types.fn-isInst rst-postable then
            throw ''
              Validation only result (bool | error attrset), find enum instance ${types.fn-descTp rst-postable}
            ''
          else if builtins.isAttrs rst-postable && rst-postable ? __throw then
            throw ''
              [custom-handle] Validation failed:
                ${rst-postable.__throw}
            ''
          else rst-postable
        else
          throw ''
          Enum Validation Error: Expected return bool or attr error, find ${types.fn-descTp rst-postable}.
          '';
      fn-validator_postableArgTp = postable:
        if (types.fn-isLiteral postable) || (types.fn-isContainer postable) || builtins.isFunction postable then true
        else
          throw ''
            enum::args unsupported type: ${postable}
              Expected type (literals | function | list | attrs(enum,inst),...), find ${types.fn-descTp postable}
          '';
    };

    fn = {
      fn-validator_fn_match_InputType = input:
        if types.fn-isMatchInputTp input then true
        else
        throw ''
          enum::match: Invalid input type '${builtins.typeOf input}'
          Expected: [Inst]enum instance | [List]list of enum instances | [Attr]attrset of enum instances
          Find: ${types.fn-descTp input}.
        '';
      fn-validator_fn_match_InputNonEmpty = input:
        if builtins.isList input && input != [] then true
        else if builtins.isAttrs input && input != {} then true
        else
        throw ''
          enum::match: Empty input '${if builtins.isList input then "[]" else "{}"}'
          Expected: enum-instance(s) [list or attrset]
          Find: ${types.fn-descTp input}.
        '';
      fn-validator_fn_match_patternsType = patterns:
        if builtins.isAttrs patterns then true
        else
          throw ''
          enum::macth: Expected patterns is attrset, found ${types.fn-descTp patterns}.
        '';
      fn-validator_fn_match_OrderKeyTp = match-porder:
        if (builtins.isList match-porder) && (builtins.all (key: builtins.isString key) match-porder) then true
        else
          throw ''
            enum::match: Expected __PORDER__ must be a list of strings, found ${types.fn-descTp match-porder}.
          '';
      fn-validator_fn_match_OrderKeyCount = input: match-porder:
        if builtins.length (builtins.attrNames input) == builtins.length match-porder then true
        else
          throw ''
            enum::match: Expected __PORDER__ length(members) = length(inputs), found ${
              builtins.length input} != ${builtins.length match-porder}.
          '';
      fn-validator_fn_match_OrderKeyMapping = input: match-porder:
        if builtins.all (k: builtins.hasAttr k input) match-porder then true
        else
          throw ''
            enum::match: Input missing keys from '${config.keys.reserved.__PORDER__}': ${
            builtins.concatStringsSep ", " (
              builtins.filter (k: !builtins.hasAttr k input) match-porder
            )
          }'';
      fn-validator_fn_match_multiPatternTp = path: node:
        if types.fn-isMatchMultiInstPatternTp node then true
        else
          throw ''
            Invalid pattern structure at '${if path == [] then "<root>" else builtins.concatStringsSep "." path}':
              Expected function or nested attrset, got ${types.fn-descTp node}
              Fix: Patterns must be nested attrsets ending in functions (e.g., Red.Circle.local = {c,s,p}: ...)
          '';
      fn-validator_fn-match_multiPatternUniqueChecker = patternKeys: uniqueKeys:
        if (builtins.length patternKeys) == (builtins.length uniqueKeys) then true
        else
          throw ''
            Pattern conflict: Duplicate pattern path(s) detected. Check: ${
            builtins.concatStringsSep ", " (builtins.filter (k: (lib.fn-count (x: x == k) patternKeys) > 1) uniqueKeys)
          }'';
      fn-validator_fn_match_multiMatchRst = matched: params-mapping: len: instanceTags: patternList:
        if (matched != null) then true
        else
        let
          avail = builtins.map (p: p.originalKey) patternList;
          wildcard = builtins.concatStringsSep "." (builtins.genList (x: config.keys.matchWildCard) len);
          paramExample =
            if params-mapping != null then
              builtins.concatStringsSep ", " params-mapping
            else
              builtins.concatStringsSep ", " (builtins.genList (i: "_${builtins.toString (i+1)}") len);
          inputHint =
            if params-mapping != null then
              "\nNote: Attrset keys sorted dictionary-order: [${builtins.concatStringsSep ", " params-mapping}]"
            else "";
        in throw ''
          Pattern match non-exhaustive for tags [${builtins.concatStringsSep ", " instanceTags}]!${inputHint}
          Defined patterns: ${if avail == [] then "(none)" else builtins.concatStringsSep ", " avail}
          Defined patterns (ordered by specificity): ${builtins.concatStringsSep "\n  " (builtins.map (p:
            "${builtins.toString p.specificity}: ${p.originalKey}"
            ) patternList
          )}
          Hint: Add wildcard handler:
            ${wildcard} = { ${paramExample} }: ...;
          Tip: More specific patterns (fewer '_') match first.
              Add missing pattern or wildcard '_._._'.
        '';
    };
    fn-validator_variantsInvalidType = variants:
      if types.fn-isContainer variants then true
      else throw ''
        enum error: Expected list (unit-enum) or attrset (param-enum), found ${types.fn-descTp variants}
      '';
  };


  fn-externalKeysFnGenerator = postable: builtins.getAttr config.keys.external.tag postable;
  fn-mkPostableStringArgs = postable-args:
    if postable-args == config.const.non-postable then []
    else if builtins.isList postable-args         then postable-args
    else [ postable-args ];
  fn-mkPostableArgToString = postable-arg:
    if postable-arg == config.const.non-postable  then "<non-postable>"
    else if builtins.isAttrs postable-arg
      && builtins.hasAttr config.keys.fn.toString postable-arg then postable-arg.toString
    else if builtins.isString postable-arg        then postable-arg
    else if builtins.isInt postable-arg
      || builtins.isFloat postable-arg      then builtins.toString postable-arg
    else if builtins.isBool postable-arg    then if postable-arg then "true" else "false"
    else if builtins.isList postable-arg    then "<list>"
    else if builtins.isAttrs postable-arg   then "<attrset>"
    else "<${builtins.typeOf postable-arg}>";
  fn-mkPostableVariantString = enum-struct: postable-variant: postable-args:
    (fn-mkPostableStringArgs postable-args)
    |> (pstArgs: if pstArgs == [] then "" else "(${
          builtins.concatStringsSep "," (builtins.map fn-mkPostableArgToString pstArgs)
       })")
    |> (postable-args-display: "enum::${enum-struct.meta.typename}${
        if enum-struct.meta.isGenericInst then
          "<${builtins.concatStringsSep "," (builtins.attrValues enum-struct.meta.rParams)}>"
        else ""
      }::${postable-variant}${postable-args-display}");

  fn-getAttrBasePostable = postable: builtins.removeAttrs postable config.keys.internal;
  fn-getTupleBasePostable = tuple-postable: extractor:
    (builtins.map (postable: fn-getAttrBasePostable postable) tuple-postable)
    |> (plst: lib.fn-indexedAttrs plst extractor);
  fn-getBasePostable = postable:
    if builtins.isAttrs postable
      then fn-getAttrBasePostable postable
    else if builtins.isList postable
      then fn-getTupleBasePostable postable fn-externalKeysFnGenerator # expend-point
    else {};
  fn-mkVariantInstValuePostableExpand = postable: fn-getBasePostable postable;

  fn-mkMapTuplePostable = postable:
    builtins.seq (validators.postable.fn-validator_postableArgTp postable) (
      if postable != config.const.non-postable then
        if types.fn-isLiteral postable  then
          postable
        else if builtins.isList postable then
          lib.fn-listToIndexedAttrs postable
        else if builtins.isAttrs postable then
          postable
        else # builtins.isFunction postable
          postable
      else config.const.non-postable
    );
  fn-mkPostableVariantInstance = enum-struct: postable-variant: postable-value: postable-args:
    (fn-mkVariantInstValuePostableExpand postable-args) // types.VariantInstValueBase {
      tag = postable-variant;
      type = enum-struct.meta;
      value = fn-mkMapTuplePostable postable-args;  # postable params
      toString = fn-mkPostableVariantString enum-struct postable-variant postable-args;
      __IS_ENUM_INSTANCE_MASKER_V1__ = true;
    };


  fn-postableEnumConstructor = enum-struct: postable-variant: postable-value: postable-args:
    builtins.seq
      (validators.postable.fn-validator_postableEnumValue postable-value postable-args)
      (fn-mkPostableVariantInstance enum-struct postable-variant postable-value postable-args);
  fn-postableTupleConstructor = enum-struct: postable-variant: postable-values: postable-args:
    builtins.seq
      (validators.postable.fn-validator_postableTupleValue enum-struct postable-variant postable-values postable-args)
      (fn-mkPostableVariantInstance enum-struct postable-variant postable-values postable-args);
  fn-postableFunConstructor = enum-struct: postable-variant: postable-values: postable-args:
    let
      rstpst = if builtins.hasAttr config.keys.generic.isGenericInst enum-struct.meta then
        let
          G = if builtins.hasAttr config.keys.generic.genericParams enum-struct.meta then
            enum-struct.meta.genericParams else {};
        in postable-values G postable-args
        else postable-values postable-args;
    in
      builtins.seq
        (validators.postable.fn-validator_postableFunRst rstpst postable-args)
        (fn-mkPostableVariantInstance enum-struct postable-variant postable-values postable-args);


  fn-postableLiteralConstructor = enum-struct: postable-variant: postable-value:
    fn-mkPostableLiteralVariantInstance enum-struct postable-variant postable-value;
  fn-mkPostableLiteralVariantInstance = enum-struct: postable-variant: postable-value:
    types.VariantInstValueBase {
      tag = postable-variant;
      type = enum-struct.meta;
      value = postable-value;
      toString = fn-mkPostableVariantString enum-struct postable-variant postable-value;
      __IS_ENUM_INSTANCE_MASKER_V1__ = true;
    };

  fn-postableDispatchConstructor = enum-struct: postable-variant: postable-value:
    builtins.seq (validators.postable.fn-validator_postableValue postable-value)
    (types.fn-isLiteral postable-value)
    |> (isLiteral:
      if isLiteral
        then fn-postableLiteralConstructor enum-struct postable-variant postable-value
      else if types.fn-isEnum postable-value
        then (postable-args: fn-postableEnumConstructor enum-struct postable-variant postable-value postable-args)
      else if builtins.isList postable-value
        then (postable-args: fn-postableTupleConstructor enum-struct postable-variant postable-value postable-args)
      else if builtins.isFunction postable-value
        then (postable-args: fn-postableFunConstructor enum-struct postable-variant postable-value postable-args)
      else
        # builtins.isAttrs postable-value
        fn-postableLiteralConstructor enum-struct postable-variant postable-value
    );
  fn-mkPostableVariantDispatchs = enum-struct:
    builtins.mapAttrs (postable-variant: postable-value:
      fn-postableDispatchConstructor enum-struct postable-variant postable-value
    ) enum-struct.variants;


  fn-mkTupleVariantInstance = enum-struct: variant:
    types.VariantInstValueBase {
      tag = variant;
      type = enum-struct.meta;
      value = config.const.non-postable;
      toString = fn-mkPostableVariantString enum-struct variant config.const.non-postable;
      __IS_ENUM_INSTANCE_MASKER_V1__ = true;
    };
  fn-mkTupleVariant = enum-struct: variant:
    types.TupleVariant {
      name  = variant;
      value = fn-mkTupleVariantInstance enum-struct variant;
    };
  fn-mkEnumInstStructTupleVariants = enum-struct:
    (map(variant: fn-mkTupleVariant enum-struct variant) enum-struct.variants)
    |> (vars: builtins.listToAttrs vars)
    |> (constructors: fn-mkEnumStructFunction enum-struct constructors);


  fn-match-once = enum-instance: patterns:
    if builtins.hasAttr enum-instance.tag patterns
      then patterns.${enum-instance.tag}
    else if builtins.hasAttr config.keys.matchWildCard patterns
      then patterns._
    else throw ''
      Pattern match non-exhaustive!
      Required variant: ${enum-instance.tag}
      Available patterns: ${builtins.concatStringsSep ", " (builtins.attrNames patterns)}
      Hint: Add '${config.keys.matchWildCard}' wildcard or handle '${enum-instance.tag}'
    '';

  fn-match-multiFlattenPatterns = patterns:
    let
      fn-recurse = path: node:
        builtins.seq (validators.fn.fn-validator_fn_match_multiPatternTp path node) (
        if builtins.isFunction node then
          [{
            patternTags = path;
            handler     = node;
            originalKey = if path == [] then config.keys.matchWildCard else builtins.concatStringsSep "." path;
            specificity = builtins.length (builtins.filter (t: t != config.keys.matchWildCard) path);
          }]
        else # builtins.isAttrs node
          builtins.concatMap (key:
            fn-recurse (path ++ [key]) node.${key}
          ) (builtins.attrNames node)
        );
      rawPatterns = fn-recurse [] patterns;
      patternKeys = map (p: builtins.concatStringsSep "." p.patternTags) rawPatterns;
      uniqueKeys = lib.fn-unique patternKeys;
      sortedPatterns = builtins.sort (a: b:
        if a.specificity != b.specificity then
          a.specificity > b.specificity
        else
          a.originalKey < b.originalKey
      ) rawPatterns;
    in
      builtins.seq rawPatterns (
        builtins.seq patternKeys (
          builtins.seq uniqueKeys (
            builtins.seq (validators.fn.fn-validator_fn-match_multiPatternUniqueChecker
              patternKeys uniqueKeys
            ) sortedPatterns
          )
        )
      );
  fn-match-multiMatched = len: instanceTags: patternList:
    builtins.foldl' (acc: pat:
      if acc != null then acc
      else if builtins.length pat.patternTags != len then null
      else if builtins.all (index:
        let p = builtins.elemAt pat.patternTags index;
            t = builtins.elemAt instanceTags index;
        in p == config.keys.matchWildCard || p == t
      ) (builtins.genList (x: x) len) then pat
      else null
    ) null patternList;
  fn-match-multi = enum-instances: patterns: params-mapping:
    let
      len = builtins.length enum-instances;
      instanceTags = builtins.map (inst: inst.tag) enum-instances;
      # [{patternTags, handler, originalKey, specificity}]
      patternList = fn-match-multiFlattenPatterns patterns;
      matched = fn-match-multiMatched len instanceTags patternList;
      handler = matched.handler;

      boundArgs = if params-mapping != null then
        builtins.listToAttrs (builtins.genList (index: {
          name = builtins.elemAt params-mapping index;
          value = builtins.elemAt enum-instances index;
        }) len)
      else
        builtins.listToAttrs (builtins.genList (index: {
          name = "_${builtins.toString (index + 1)}";
          value = builtins.elemAt enum-instances index;
        }) len);
    in
      builtins.seq (validators.fn.fn-validator_fn_match_multiMatchRst
          matched params-mapping len instanceTags patternList
      ) (handler boundArgs);

  fn-match-tryPorderKeys = input: patterns:
    if builtins.hasAttr config.keys.reserved.__PORDER__  patterns then
      let pattern_order = builtins.getAttr config.keys.reserved.__PORDER__ patterns; in
      builtins.seq (validators.fn.fn-validator_fn_match_OrderKeyTp pattern_order) (
        builtins.seq (validators.fn.fn-validator_fn_match_OrderKeyCount input pattern_order) (
          builtins.seq (validators.fn.fn-validator_fn_match_OrderKeyMapping input pattern_order)
            pattern_order
        )
      )
    else builtins.attrNames input;

  fn-match-patternAttrs = input: patterns:
    let
      keys = fn-match-tryPorderKeys input patterns;
      instances = builtins.map (k: input.${k}) keys;
      clean-patterns = builtins.removeAttrs patterns [ config.keys.reserved.__PORDER__ ];
    in
      fn-match-multi instances clean-patterns keys;

  fn-match = input: patterns:
    builtins.seq (validators.fn.fn-validator_fn_match_InputType input) (
      builtins.seq (validators.fn.fn-validator_fn_match_InputNonEmpty input) (
        builtins.seq (validators.fn.fn-validator_fn_match_patternsType patterns) (
        if builtins.isList input then
          fn-match-multi input patterns null
        else if types.fn-isInst input then
          let handler = fn-match-once input patterns;
          in if builtins.isFunction handler then handler input else handler
        else
          fn-match-patternAttrs input patterns
        )
      )
    );

  fn-serialize = enum-instance:
    {
      tag = enum-instance.tag;
      type = enum-instance.type;
      value =
        if enum-instance.value == config.const.non-postable
          then config.const.non-postable
        else if types.fn-isInst enum-instance.value
          then enum-instance.value.tag
        else enum-instance.value;
    };


  fn-mkEnumStructFunction = enum-struct: constructors:
    (constructors // types.EnumTypeFuncs {
      __typename__ = enum-struct.meta.typename;
      __meta__ = enum-struct.meta;
      __variants__ = enum-struct.variants;
      match = fn-match;
      serialize = fn-serialize;
      # toType = lib: lib.types.enum (builtins.attrnames constructors);
    });
  fn-mkEnumInstStructPostableVariants = enum-struct:
    (fn-mkPostableVariantDispatchs enum-struct)
    |> (constructors: fn-mkEnumStructFunction enum-struct constructors);


/* ---------- STAGE 2: GERNRIC META CONSTRUCTION (SAFE AFTER VALIDATION) ---------- */
  fn-mkGenericParamsMapping = generic-labelparams: generic-realtype-args:
    if builtins.isList generic-realtype-args then
      builtins.listToAttrs (
        lib.fn-zipListsWith (name: value: { name = name; value = value; })
          generic-labelparams
          generic-realtype-args
      )
    else
      generic-realtype-args;
  fn-mkGenericParamRealType = real-type:
    if types.fn-isEnum real-type then real-type.__typename__
    else builtins.typeOf real-type;
  fn-mkGenericRealTypeParamsInstiator = generic-labels: generic-realtype-args:    # onlylist
    builtins.listToAttrs (
      lib.fn-zipListsWith (generic-label: real-type: {
        name = generic-label;
        value = fn-mkGenericParamRealType real-type;
      })
      generic-labels
      generic-realtype-args
    );
  fn-mkGenericParamsToTupleRealType = generic-enum-meta: generic-realtype-args:
    let
      real-typename-params = fn-mkGenericRealTypeParamsInstiator generic-enum-meta.gParams generic-realtype-args;
      genericParams = fn-mkGenericParamsMapping generic-enum-meta.gParams generic-realtype-args;
      isGenericInst = true;
    in
      builtins.seq real-typename-params (
        generic-enum-meta // {
          isGeneric = false;
          gParams = [];
          rParams = real-typename-params;
          genericParams = genericParams;
          isGenericInst = isGenericInst;
        }
      );
  fn-mkGenericParamsToAttrRealType = generic-enum-meta: generic-realtype-args:
    let
      realtype-params = map (param: generic-realtype-args.${param}) generic-enum-meta.gParams;
      real-typename-params = fn-mkGenericRealTypeParamsInstiator generic-enum-meta.gParams realtype-params;
      genericParams = fn-mkGenericParamsMapping generic-enum-meta.gParams generic-realtype-args;
      isGenericInst = true;
    in
      builtins.seq realtype-params (
        builtins.seq real-typename-params (
          generic-enum-meta // {
            isGeneric = false;
            gParams = [];
            rParams = real-typename-params;
            genericParams = genericParams;
            isGenericInst = isGenericInst;
          }
        )
      );
  fn-mkGenericFixedParamsToRealTypeDispatcher = generic-enum-meta: generic-realtype-args:  # => real-meta rParams
    if builtins.isList generic-realtype-args
      then fn-mkGenericParamsToTupleRealType generic-enum-meta generic-realtype-args
    else
      # builtins.isAttrs generic-realtype-args
      fn-mkGenericParamsToAttrRealType generic-enum-meta generic-realtype-args;

/* ---------- STAGE 3: GENERIC VARIANT INSTANTIATION (PURE TRANSFORMATION) ---------- */
  fn-genericVariantsRealTypeInstantiator = generic-enum-meta: generic-realtype-args: generic-postable-variants:
    let
      params-mapping = fn-mkGenericParamsMapping generic-enum-meta.gParams generic-realtype-args;
      replace-placeholder = lib.fn-replacePlaceholders generic-postable-variants params-mapping;
    in builtins.seq params-mapping replace-placeholder;
  fn-genericMetaRealTypeInstantiator = generic-enum-meta: generic-realtype-args:
    builtins.seq
      (validators.generic.fn-validator_genericRealTypeDispatcher generic-enum-meta generic-realtype-args)
      (fn-mkGenericFixedParamsToRealTypeDispatcher generic-enum-meta generic-realtype-args);

/* ---------- STAGE 4: GENERIC STRUCT ASSEMBLY (FINAL COMPOSITION) ---------- */
  fn-mkGenericStructInstantiator = generic-enum-meta: generic-postable-variants: generic-realtype-args:
    let
      meta = fn-genericMetaRealTypeInstantiator generic-enum-meta generic-realtype-args;
      variants = fn-genericVariantsRealTypeInstantiator generic-enum-meta generic-realtype-args generic-postable-variants;
    in
      builtins.seq meta (
        builtins.seq variants (
          types.EnumInstStruct { inherit meta variants; }
        )
      );
  fn-mkGenericEnumTypeStructInstantiator = generic-enum-meta: instantiator:
    types.EnumGenericTypeStruct {
      __typename__ = generic-enum-meta.typename;
      __isGeneric__ = true;
      __genericParams__ = generic-enum-meta.gParams;
      __arity__ = builtins.length generic-enum-meta.gParams;
      __functor = self: args: instantiator args;
      instantiate = args: instantiator args;
    };
  fn-mkGenericEnumTypeInstantiator = generic-enum-meta: generic-postable-variants: generic-realtype-args:
    (fn-mkGenericStructInstantiator generic-enum-meta generic-postable-variants generic-realtype-args)
    |> (fixed-real-enum-struct: fn-mkEnumInstStructPostableVariants fixed-real-enum-struct);


  fn-mkEnumInstDispatcher = meta: variants:
    if builtins.isList variants then
      fn-mkEnumInstStructTupleVariants (types.EnumInstStruct { inherit meta variants; })
    else
      # bbuiltins.isAttrs variants
      fn-mkEnumInstStructPostableVariants (types.EnumInstStruct { inherit meta variants; });
  fn-mkEnumDispatcher = meta: variants:
    let
      validator-generic = validators.generic.fn-validator_genericInvalidPattern meta variants;
      validator-variant = validators.fn-validator_variantsInvalidType variants;
    in
      if meta.isGeneric then
        builtins.seq validator-generic
          (fn-mkGenericEnumTypeInstantiator meta variants)
          |> (instantiator: fn-mkGenericEnumTypeStructInstantiator meta instantiator)
      else
        builtins.seq validator-variant
          (fn-mkEnumInstDispatcher meta variants);

  enum = enumType: variants:
    (types.fn-parseTypeSignature enumType)
    |> (meta: fn-mkEnumDispatcher meta variants);


in {
  inherit enum lib types;
}


