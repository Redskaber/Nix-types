# @path: lib/types/match.nix
# @description: Pattern matching engine.
#
# This is a **pure library-level function** — it does not close over any
# enum-specific state. The enum-carried `Shape.match` is a thin alias
# that delegates here.
#
# Supports three input shapes:
#   1. Single enum instance:
#        Inst -> { tag = ...; _ = ...; } -> result
#   2. List of instances (positional binding _1, _2, ...):
#        [Inst] -> { Tag.Tag... = { _1, _2, ... }: ...; _._ = ...; }
#        Patterns sorted by specificity (more specific first).
#   3. Attrset of instances (named binding + explicit ordering):
#        { k1 = Inst; k2 = Inst; ... } ->
#        { __PORDER__ = [ "k1" "k2" ]; Tag.Tag... = { k1, k2 }: ...; }

{ config, types }:
let
  utils = import ./utils.nix;
  validators = import ./validators.nix { inherit config types; };
in rec {
  # --- Public entry point --------------------------------------------
  # Dispatches on the shape of `input`:
  #   - list    → multi-match with positional binding
  #   - Inst    → single match
  #   - attrset → multi-match with named binding (uses __PORDER__ if present)
  match = input: patterns:
    builtins.seq (validators.match.validateInputType input)
      (builtins.seq (validators.match.validateInputNonEmpty input)
        (builtins.seq (validators.match.validatePatternsType patterns)
          (if builtins.isList input then
            # Multi-instance list match: validate elements are instances.
            builtins.seq (validators.match.validateInputElements input)
              (matchMulti input patterns null)
          else if types.isInst input then
            let handler = matchOnce input patterns; in
            if builtins.isFunction handler then handler input else handler
          else
            # Multi-instance attrset match: validate elements are instances.
            builtins.seq (validators.match.validateInputElements input)
              (matchAttrs input patterns))));

  # --- Single-instance match -----------------------------------------
  # Falls back to wildcard `_` if defined, else throws non-exhaustive.
  matchOnce = enum-instance: patterns:
    if builtins.hasAttr enum-instance.tag patterns then
      patterns.${enum-instance.tag}
    else if builtins.hasAttr config.keys.matchWildCard patterns then
      patterns._
    else
      throw ''
        Pattern match non-exhaustive!
        Required variant: ${enum-instance.tag}
        Available patterns: ${builtins.concatStringsSep ", " (builtins.attrNames patterns)}
        Hint: Add '${config.keys.matchWildCard}' wildcard or handle '${enum-instance.tag}'
      '';

  # --- Multi-instance pattern flattening -----------------------------
  # Flatten a nested pattern attrset into a list of:
  #   { patternTags = [t1, t2, ...]; handler = fn;
  #     originalKey = "t1.t2..."; specificity = N; }
  # Sort by specificity (more specific = fewer wildcards = higher priority),
  # then by original key for stable tie-breaking.
  flattenPatterns = patterns:
    let
      recurse = path: node:
        builtins.seq (validators.match.validateMultiPatternTp path node) (
          if builtins.isFunction node then
            [{
              patternTags = path;
              handler = node;
              originalKey =
                if path == [ ] then config.keys.matchWildCard
                else builtins.concatStringsSep "." path;
              specificity =
                builtins.length (builtins.filter (t: t != config.keys.matchWildCard) path);
            }]
          else # builtins.isAttrs node
            builtins.concatMap
              (key: recurse (path ++ [ key ]) node.${key})
              (builtins.attrNames node));
      rawPatterns = recurse [ ] patterns;
      patternKeys = map (p: builtins.concatStringsSep "." p.patternTags) rawPatterns;
      uniqueKeys = utils.unique patternKeys;
      sortedPatterns = builtins.sort (a: b:
        if a.specificity != b.specificity then a.specificity > b.specificity
        else a.originalKey < b.originalKey) rawPatterns;
    in
    # Only force the duplicate-pattern check (to surface errors eagerly).
    # The other values are already forced by their dependent computations.
    builtins.seq
      (validators.match.validateMultiPatternUnique patternKeys uniqueKeys)
      sortedPatterns;

  # Find the first pattern that matches the given instance tags.
  # A pattern matches iff every position is either `_` or equals the instance tag.
  findMatchingPattern = len: instanceTags: patternList:
    builtins.foldl' (acc: pat:
      if acc != null then acc
      else if builtins.length pat.patternTags != len then null
      else if builtins.all (index:
        let
          p = builtins.elemAt pat.patternTags index;
          t = builtins.elemAt instanceTags index;
        in
        p == config.keys.matchWildCard || p == t
      ) (builtins.genList (x: x) len) then pat
      else null) null patternList;

  # Multi-instance match over a list of instances.
  # `params-mapping` is the list of attr keys to bind to
  # (or null for positional _1, _2, ...).
  matchMulti = enum-instances: patterns: params-mapping:
    let
      len = builtins.length enum-instances;
      instanceTags = builtins.map (inst: inst.tag) enum-instances;
      patternList = flattenPatterns patterns;
      matched = findMatchingPattern len instanceTags patternList;
      handler = matched.handler;
      boundArgs =
        if params-mapping != null then
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
    builtins.seq
      (validators.match.validateMultiMatchRst
        matched params-mapping len instanceTags patternList)
      (handler boundArgs);

  # If patterns has `__PORDER__`, validate it and return the ordering;
  # otherwise default to `builtins.attrNames input`.
  tryPorderKeys = input: patterns:
    if builtins.hasAttr config.keys.reserved.__PORDER__ patterns then
      let porder = builtins.getAttr config.keys.reserved.__PORDER__ patterns; in
      builtins.seq (validators.match.validateOrderKeyTp porder)
        (builtins.seq (validators.match.validateOrderKeyCount input porder)
          (builtins.seq (validators.match.validateOrderKeyMapping input porder)
            porder))
    else builtins.attrNames input;

  matchAttrs = input: patterns:
    let
      keys = tryPorderKeys input patterns;
      instances = builtins.map (k: input.${k}) keys;
      clean-patterns = builtins.removeAttrs patterns [ config.keys.reserved.__PORDER__ ];
    in
    matchMulti instances clean-patterns keys;
}
