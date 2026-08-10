# @path: test/cases/library.nix
# @description: Tests for the library-level function API and utility helpers.

let
  fw = import ../framework.nix { };
  shared = import ./shared.nix;
  inherit (shared) Color Position lib;
in
fw.runAll [
  # === match is a top-level library export ===
  { name = "lib.match.01-is-callable-without-enum-type";
    test = lib.match Color.Red { Red = v: "r"; _ = v: "other"; } == "r"; }
  { name = "lib.match.02-works-on-list-input";
    test = lib.match [ Color.Red Color.Green ] {
      Red.Green = { _1, _2 }: "rg";
      _._ = { ... }: "other";
    } == "rg"; }
  { name = "lib.match.03-works-on-attrset-input";
    test =
      let c = Color.Red; in
      lib.match { inherit c; } {
        __PORDER__ = [ "c" ];
        Red = { c }: "ok";
        _ = { ... }: 0;
      } == "ok"; }

  # === serialize is a top-level library export ===
  { name = "lib.serialize.01-is-callable-without-enum-type";
    test = (lib.serialize Color.Red).tag == "Red"; }
  { name = "lib.serialize.02-flat-output-shape";
    test = builtins.attrNames (lib.serialize Color.Red) == [ "tag" "typename" "value" ]; }

  # === enum-carried match is the same function as library match ===
  { name = "lib.match.03-alias-and-lib-produce-same-result-single";
    test = Color.match Color.Red { Red = v: "r"; _ = v: "x"; }
          == lib.match Color.Red { Red = v: "r"; _ = v: "x"; }; }
  { name = "lib.match.04-alias-and-lib-produce-same-result-list";
    test = Color.match [ Color.Red Color.Green ] {
            Red.Green = { _1, _2 }: "rg"; _._ = { ... }: "x";
          }
          == lib.match [ Color.Red Color.Green ] {
            Red.Green = { _1, _2 }: "rg"; _._ = { ... }: "x";
          }; }

  # === enum-carried serialize is the same function as library serialize ===
  { name = "lib.serialize.03-alias-and-lib-produce-same-result";
    test = Color.serialize Color.Red == lib.serialize Color.Red; }

  # === isEnum/isInst/isType are top-level exports ===
  { name = "lib.top-level.01-isEnum-exported";
    test = shared.lib.isEnum Color; }
  { name = "lib.top-level.02-isInst-exported";
    test = shared.lib.isInst Color.Red; }
  { name = "lib.top-level.03-isType-exported";
    test = shared.lib.isType Color.Red Color; }
  { name = "lib.top-level.04-descTp-exported";
    test = shared.lib.descTp Color == "enum::Color"; }
  { name = "lib.top-level.05-parseTypeName-exported";
    test = (shared.lib.parseTypeName "Color").typename == "Color"; }

  # === utility helpers are top-level exports ===
  { name = "lib.top-level.06-trim-exported";
    test = shared.lib.trim "  hello  " == "hello"; }
  { name = "lib.top-level.07-splitString-exported";
    test = shared.lib.splitString "," "a,b,c" == [ "a" "b" "c" ]; }
  { name = "lib.top-level.08-unique-exported";
    test = shared.lib.unique [ 1 2 2 3 3 3 ] == [ 1 2 3 ]; }
  { name = "lib.top-level.09-count-exported";
    test = shared.lib.count (x: x > 2) [ 1 2 3 4 5 ] == 3; }
  { name = "lib.top-level.10-listToIndexedAttrs-exported";
    test = shared.lib.listToIndexedAttrs [ "a" "b" ] == { _0 = "a"; _1 = "b"; }; }
]
