# @path: lib/types/predicates.nix
# @description: Type predicates and descriptors.
#
# These functions classify Nix values: literal vs container, enum-type vs
# enum-instance, etc. They are the foundation for all type-aware logic.
#
# Convention: every predicate returns a strict `bool` (never throws).

{ config }:
rec {
  # --- Primitive classification --------------------------------------------

  # Leaf type? (int/float/bool/null/string/path)
  isLiteral = v:
    builtins.any (t: (builtins.typeOf v) == t) config.types.literals;

  # A "deep literal" is a literal OR a homogeneous list of deep literals.
  # Used to distinguish a literal list value (e.g., ["a" "b"]) from a
  # tuple-of-types descriptor (e.g., [Color Color Color]).
  isDeepLiteral = v:
    if v == null then true
    else if builtins.isList v then builtins.all (x: isDeepLiteral x) v
    else if builtins.isAttrs v then false
    else (builtins.any (t: (builtins.typeOf v) == t) config.types.literals);

  # list or attrset?
  isContainer = v:
    builtins.any (t: (builtins.typeOf v) == t) config.types.containers;

  # --- Enum / instance classification (duck-typed) -------------------------

  # Is `v` an enum type (has the standard type-level attrs)?
  isEnum = v:
    (builtins.isAttrs v)
    && (builtins.all (k: builtins.hasAttr k v) config.keys.typeIdents);

  # Is `v` an enum instance (has the standard instance attrs)?
  isInst = v:
    (builtins.isAttrs v)
    && (builtins.all (k: builtins.hasAttr k v) config.keys.instIdents);

  # --- Postable classification ---------------------------------------------

  # Can `v` be used as a variant value descriptor?
  isPostable = v:
    builtins.any (t: (builtins.typeOf v) == t) config.keys.postables;

  # Is `v` a valid return from a validator function? (bool/set)
  isPostableValidRst = v:
    builtins.any (t: (builtins.typeOf v) == t) config.keys.postableValidRstTypes;

  # --- Match-input classification ------------------------------------------

  isMatchInputTp = v:
    builtins.any (t: (builtins.typeOf v) == t) config.keys.matchValidTypes;

  isMatchMultiInstPatternTp = v:
    builtins.any (t: (builtins.typeOf v) == t) config.keys.matchValidMultiInstPatternTypes;

  # --- Type equality -------------------------------------------------------
  # Is `v` an instance of (or the same enum type as) `t`?
  # Both enum types and instances carry `__meta__`, so we can unify the check.
  isType = v: t:
    if ((isEnum v) || (isInst v)) && (t ? __meta__) then v.__meta__ == t.__meta__
    else false;

  # --- Human-readable type description -------------------------------------
  descTp = v:
    if isEnum v then "enum::${v.__meta__.typename}"
    else if isInst v then v.display
    else builtins.typeOf v;

  # --- Typename parser ----------------------------------------------------
  # Validates that `typename` is a legal identifier (no generic syntax).
  # Returns `{ typename = ...; }` — the canonical enum meta record.
  # Throws *eagerly* (via `seq`) if invalid so the error fires at the call
  # site rather than being deferred until a variant is accessed.
  # Also guards against non-string inputs (which would otherwise produce
  # an uncatchable builtin error from `builtins.match`).
  parseTypeName = typename:
    if !builtins.isString typename then
      builtins.seq
        (throw ''
          Invalid enum type name: expected string, found ${builtins.typeOf typename}
            Example: [OK] "Color" | [ERR] 42, true, { ... }
        '')
        { typename = typename; }
    else
      let
        ok = builtins.match "^[A-Za-z_][A-Za-z0-9_]*$" typename != null;
      in
      builtins.seq
        (if ok then true
         else throw ''
           Invalid enum type name: '${typename}'
             Expected: alphanumeric identifier starting with letter or underscore.
             Rules: letters, digits, underscores only; must not start with a digit.
             Example: [OK] "Color", "HttpVerb", "Shape_2D" | [ERR] "Foo<T>", "hy-phen", "1st"
         '')
        { typename = typename; };

  # --- Struct definitions (documentation / pattern sugar) -----------------
  # These are passthrough pattern-match constructors that document the
  # shape of internal records and provide stable destructuring points.
  EnumMeta = { typename, ... }@params: params;
  EnumInstStruct = { meta ? { }, variants ? { } }@params: params;
  TupleVariant = { name, value ? { } }@params: params;
}
