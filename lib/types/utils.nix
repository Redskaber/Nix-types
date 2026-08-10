# @path: lib/types/utils.nix
# @description: Pure helper functions with zero internal dependencies.
#
# All functions here are safe to reuse externally — they only call builtins
# and other helpers within this same file. None touches the type system.
#
# Naming conventions:
#   - Public functions exported from this module: bare camelCase
#     (e.g., `addContextFrom`, `splitString`, `listToIndexedAttrs`).
#   - Internal parameters and `let` bindings in type modules may use
#     kebab-case (e.g., `postable-args`, `enum-struct`) — this is a Nix
#     idiom for multi-word locals and does not affect the public API.

let
  # Prepend a 0-length slice of `src` to `target` so the resulting string
  # inherits `src`'s source location for error reporting.
  addContextFrom = src: target: builtins.substring 0 0 src + target;

  # Count elements in a list that satisfy a predicate.
  count = pred: builtins.foldl' (c: x: if pred x then c + 1 else c) 0;

  # Escape each character in `list` for use in a regex.
  escape = list: builtins.replaceStrings list (map (c: "\\${c}") list);
  escapeRegex = escape (stringToCharacters "\\[]{()^$?*+|.");

  min = x: y: if x < y then x else y;

  optionalString = cond: string: if cond then string else "";

  # De-duplicate a list, preserving first-occurrence order.
  unique = builtins.foldl' (acc: e: if builtins.elem e acc then acc else acc ++ [ e ]) [ ];

  # Recursively replace string placeholders in any nested structure.
  # Placeholders are string keys present in `substitutions`.
  replacePlaceholders = value: substitutions:
    if builtins.isString value && builtins.hasAttr value substitutions
    then substitutions.${value}
    else if builtins.isList value
    then map (elem: replacePlaceholders elem substitutions) value
    else if builtins.isAttrs value
    then builtins.mapAttrs (_: v: replacePlaceholders v substitutions) value
    else value;

  stringToCharacters = s:
    builtins.genList (p: builtins.substring p 1 s) (builtins.stringLength s);

  splitString = sep: s:
    let
      splits = builtins.filter builtins.isString (
        builtins.split (escapeRegex (toString sep)) (toString s)
      );
    in map (addContextFrom s) splits;

  trim = trimWith { start = true; end = true; };
  trimWith = { start ? false, end ? false }:
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
    let res = builtins.match regex s; in
    optionalString (res != null) (builtins.head res);

  # Zip two lists with a function, stopping at the shorter list.
  zipListsWith = f: fst: snd:
    let min-length = min (builtins.length fst) (builtins.length snd); in
    builtins.genList (n: f (builtins.elemAt fst n) (builtins.elemAt snd n)) min-length;

  # Convert a list to an indexed attrset { "_0" = x; "_1" = y; ... }.
  indexedAttrs = list: extractor:
    let length = builtins.length list; in
    builtins.listToAttrs (builtins.genList (index: {
      name = "_${builtins.toString index}";
      value = extractor (builtins.elemAt list index);
    }) length);

  listToIndexedAttrs = list: indexedAttrs list (x: x);
in {
  inherit
    addContextFrom count escape escapeRegex
    min optionalString unique replacePlaceholders
    stringToCharacters splitString trim trimWith
    zipListsWith indexedAttrs listToIndexedAttrs;
}
