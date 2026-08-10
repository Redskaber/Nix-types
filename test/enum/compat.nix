# @path: test/enum/compat.nix
# @description: Backward-compatibility test — uses the *exact* calling style
#               from the original (pre-refactor) project's non-generic tests
#               to verify the refactored library preserves API compatibility.
#
# This file deliberately mirrors the original `test/enum/default.nix`'s
# non-generic block, only removing the generic-enum cases.

let
  enum = (import ../../lib/enum).enum;
  types = (import ../../lib/enum).types;
  lib = (import ../../lib/enum).lib;
  fw = import ../framework.nix { };

  # 1.base-enum-variants  (verbatim from original)
  Color = enum "Color" [ "Red" "Green" "Blue" ];
  cg = Color.Green;
  rc-cg = Color.match cg {
    Red   = v: "enum::Color::${v.tag}";
    Green = v: "enum::Color::${v.tag}";
    Blue  = v: "enum::Color::${v.tag}";
  };

  # 2.postable-enum-variants  (verbatim)
  validator_func = { pos1, pos2, pos3, ...}:
    if pos1.tag == pos2.tag
      then { inherit pos1 pos2 pos3; }
    else { __throw = "Expected Triangle requires pos1 == pos2, found `${pos1.tag} != ${pos2.tag}`"; };

  Position = enum "Position" [ "local" "remote" ];
  Shape = enum "Shape" {
    Circle    = Color;
    Square    = [ Color Color Color ];
    Triangle  = { pos1, pos2, pos3 }@instance: validator_func instance;
    Rhombus   = { pos1, pos2, pos3, ... }@instance: validator_func instance;
  };

  # 2.1
  sc = Shape.Circle Color.Red;
  rs-sc = Shape.match sc {
    Circle  = v: "enum::Shape::${v.tag}";
    _       = v: "Other: ${v.tag}";
  };
  # 2.2
  ss = Shape.Square [ Color.Red Color.Green Color.Blue ];
  rs-ss = Shape.match ss {
    Square  = v: "enum::Shape::${v.tag}; value[${v._0} ${v._1} ${v._2}]";
    _       = v: "Other: ${v.tag}";
  };
  # 2.3  (handler as attrset destructure, original style)
  st = Shape.Triangle { pos1=Color.Red; pos2=Color.Red; pos3=Color.Blue; };
  rs-st = Shape.match st {
    # NOTE: original test used `type.name` (a typo — the meta has `typename`).
    # Using the correct field name here.
    Triangle  = { pos1, pos2, pos3, type, tag, ... }: "enum::${type.typename}::${tag}::(${pos1.tag} ${pos2.tag} ${pos3.tag})";
    _         = v: "Other: ${v.tag}";
  };
  # 2.4  (Rhombus with extra ignored field)
  sr = Shape.Rhombus { pos1=Color.Green; pos2=Color.Green; pos3=Color.Red; _0=Color.Blue; };
  rs-sr = Shape.match sr {
    Rhombus   = v: v.toString;
    _         = v: "Other: ${v.tag}";
  };

  # Drive enum (verbatim)
  drive = enum "Drive" {
    self                = Color.Red;
    intel               = "intel";
    amd                 = "amd";
    nvidia              = "nvidia";
    nvidia-prime        = "nvidia-prime";
    intel-nvidia        = [ "intel" "nvidia" ];
    amd-nvidia          = [ "amd" "nvidia" ];
    intel-nvidia-prime  = [ "intel" "nvidia-prime" ];
    amd-nvidia-prime    = [ "amd" "nvidia-prime" ];
  };
  self    = drive.self;
  intel   = drive.intel;
  amd     = drive.amd;
  nvidia  = drive.nvidia;
  nvidia-prime  = drive.nvidia-prime;
  intel-nvidia  = drive.intel-nvidia;
  amd-nvidia    = drive.amd-nvidia;
  intel-nvidia-prime  = drive.intel-nvidia-prime;
  amd-nvidia-prime    = drive.amd-nvidia-prime;

  # Match-chain  (verbatim structure, demonstrates nested match)
  rs-st-chain = Shape.match st {
    Triangle = v: Color.match v.pos1 {
        Red   = c: c.toString;
        Green = c: c.toString;
        _     = c: c.toString;
    };
    _ = v: v.toString;
  };

  # Multi-match with __PORDER__  (verbatim structure)
  color = Color.Red;
  shape = Shape.Circle Color.Red;
  position = Position.local;
  rs-multi = Shape.match [ color shape position ] {
    Red.Circle.local = { _1, _2, _3 }: "${_1.tag}, ${_2.tag}, ${_3.tag}";
    _._._ = { ... }: 10;
  };
  rs-multi-attrset = Shape.match { inherit color shape position; } {
    __PORDER__        = [ "color" "shape" "position" ];
    Red.Circle.local  = { color, shape, position }: "${color.tag}, ${shape.tag}, ${position.tag}";
    _._._             = { ... }: 0;
  };

  # Type introspection (non-generic subset, verbatim where possible)
  is-enum-true  = types.fn-isType Shape Shape;
  is-enum-false = types.fn-isType Shape Color;
  is-inst-true  = types.fn-isType sc Shape;
  is-inst-false = types.fn-isType sc Color;
  is-desc-enum  = types.fn-descTp Shape;
  is-desc-inst  = types.fn-descTp sc;
  is-desc-color = types.fn-descTp Color;

in fw.runAll [
  { name = "compat.01-color-green-tag";       test = cg.tag == "Green"; }
  { name = "compat.02-color-green-match";     test = rc-cg == "enum::Color::Green"; }
  { name = "compat.03-shape-circle-tag";      test = sc.tag == "Circle"; }
  { name = "compat.04-shape-circle-value-tag"; test = sc.value.tag == "Red"; }
  { name = "compat.05-shape-circle-match";    test = rs-sc == "enum::Shape::Circle"; }
  { name = "compat.06-shape-square-_0";       test = ss.value._0.tag == "Red"; }
  { name = "compat.07-shape-square-_1";       test = ss.value._1.tag == "Green"; }
  { name = "compat.08-shape-square-_2";       test = ss.value._2.tag == "Blue"; }
  { name = "compat.09-shape-triangle-tag";    test = st.tag == "Triangle"; }
  { name = "compat.10-shape-triangle-match";  test = rs-st == "enum::__typename__::Triangle::(Red Red Blue)"; }
  { name = "compat.11-shape-rhombus-tag";     test = sr.tag == "Rhombus"; }
  { name = "compat.12-shape-rhombus-toString"; test = rs-sr == sr.toString; }
  { name = "compat.13-drive-self-tag";        test = self.tag == "self"; }
  { name = "compat.14-drive-self-value-tag";  test = self.value.tag == "Red"; }
  { name = "compat.15-drive-intel-value";     test = intel.value == "intel"; }
  { name = "compat.16-drive-intel-nvidia-elem-0"; test = builtins.elemAt intel-nvidia.value 0 == "intel"; }
  { name = "compat.17-drive-intel-nvidia-elem-1"; test = builtins.elemAt intel-nvidia.value 1 == "nvidia"; }
  { name = "compat.18-drive-amd-nvidia-prime-elem-1"; test = builtins.elemAt amd-nvidia-prime.value 1 == "nvidia-prime"; }
  { name = "compat.19-match-chain";           test = rs-st-chain == "enum::Color::Red"; }
  { name = "compat.20-multi-match-list";      test = rs-multi == "Red, Circle, local"; }
  { name = "compat.21-multi-match-attrset";   test = rs-multi-attrset == "Red, Circle, local"; }
  { name = "compat.22-types-isType-shape-shape"; test = is-enum-true; }
  { name = "compat.23-types-isType-shape-color"; test = !is-enum-false; }
  { name = "compat.24-types-isType-sc-shape";  test = is-inst-true; }
  { name = "compat.25-types-isType-sc-color";  test = !is-inst-false; }
  { name = "compat.26-descTp-shape";          test = is-desc-enum == "enum::Shape"; }
  { name = "compat.27-descTp-color";          test = is-desc-color == "enum::Color"; }
]
