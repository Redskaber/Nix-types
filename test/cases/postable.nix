# @path: test/cases/postable.nix
# @description: Postable enum test cases — enum-typed, tuple, function validator.

let
  fw = import ../framework.nix { };
  shared = import ./shared.nix;
  inherit (shared) Color Position types;

  LocalShape = shared.enum "Shape" {
    Circle   = Color;
    Square   = [ Color Color Color ];
    Triangle = { pos1, pos2, pos3 }@instance:
      if pos1.tag == pos2.tag
        then { inherit pos1 pos2 pos3; }
      else { __throw__ = "Triangle requires pos1 == pos2, found `${pos1.tag} != ${pos2.tag}`"; };
    Rhombus = { pos1, pos2, pos3, ... }@instance:
      if pos1.tag == pos2.tag
        then { inherit pos1 pos2 pos3; }
      else { __throw__ = "Rhombus requires pos1 == pos2, found `${pos1.tag} != ${pos2.tag}`"; };
  };

  sc = LocalShape.Circle Color.Red;
  ss = LocalShape.Square [ Color.Red Color.Green Color.Blue ];
in
fw.runAll [
  # --- enum-typed variant ---
  { name = "postable.enum.01-create-instance";
    test = sc.tag == "Circle"; }
  { name = "postable.enum.02-instance-value-tag";
    test = sc.value.tag == "Red"; }
  { name = "postable.enum.03-instance-display";
    test = sc.display == "enum::Shape::Circle(enum::Color::Red)"; }
  { name = "postable.enum.04-instance-meta-typename";
    test = sc.__meta__.typename == "Shape"; }
  { name = "postable.enum.05-wrong-enum-rejected";
    test = fw.assertThrows "postable.enum.05"
      (LocalShape.Circle Position.local); }
  { name = "postable.enum.06-enum-type-rejected";
    test = fw.assertThrows "postable.enum.06"
      (LocalShape.Circle Position); }
  { name = "postable.enum.07-instance-passes-isType";
    test = types.isType sc LocalShape; }
  { name = "postable.enum.08-value-passes-isInst";
    test = types.isInst sc.value; }

  # --- tuple variant ---
  { name = "postable.tuple.01-create-instance";
    test = ss.tag == "Square"; }
  { name = "postable.tuple.02-indexed-access-_0";
    test = ss.value._0.tag == "Red"; }
  { name = "postable.tuple.03-indexed-access-_1";
    test = ss.value._1.tag == "Green"; }
  { name = "postable.tuple.04-indexed-access-_2";
    test = ss.value._2.tag == "Blue"; }
  { name = "postable.tuple.05-wrong-arity-rejected";
    test = fw.assertThrows "postable.tuple.05"
      (LocalShape.Square [ Color.Red Color.Green ]); }
  { name = "postable.tuple.06-wrong-element-type-rejected";
    test = fw.assertThrows "postable.tuple.06"
      (LocalShape.Square [ Color.Red Position.local Color.Blue ]); }
  { name = "postable.tuple.07-extra-args-rejected";
    test = fw.assertThrows "postable.tuple.07"
      (LocalShape.Square [ Color.Red Color.Green Color.Blue Color.Red ]); }
  { name = "postable.tuple.08-empty-tuple-list-rejected";
    test = fw.assertThrows "postable.tuple.08"
      (LocalShape.Square [ ]); }
  { name = "postable.tuple.09-display-with-multiple-args";
    test = ss.display == "enum::Shape::Square(enum::Color::Red,enum::Color::Green,enum::Color::Blue)"; }

  # --- function validator ---
  { name = "postable.fun.01-validator-passes";
    test = (LocalShape.Triangle { pos1=Color.Red; pos2=Color.Red; pos3=Color.Blue; }).tag == "Triangle"; }
  { name = "postable.fun.02-validator-fails-with-throw";
    test = fw.assertThrows "postable.fun.02"
      (LocalShape.Triangle { pos1=Color.Red; pos2=Color.Green; pos3=Color.Blue; }); }
  { name = "postable.fun.03-validator-rhombus-with-extra-fields";
    test = (LocalShape.Rhombus { pos1=Color.Green; pos2=Color.Green; pos3=Color.Red; _0=Color.Blue; }).tag == "Rhombus"; }
  { name = "postable.fun.04-validator-rhombus-fails";
    test = fw.assertThrows "postable.fun.04"
      (LocalShape.Rhombus { pos1=Color.Green; pos2=Color.Red; pos3=Color.Blue; }); }
  { name = "postable.fun.05-validator-returning-true-passes";
    test = (let E = shared.enum "V" { Ok = _: true; }; in (E.Ok { x = 1; }).tag == "Ok"); }
  { name = "postable.fun.06-validator-returning-false-throws";
    test = fw.assertThrows "postable.fun.06"
      (let E = shared.enum "V" { Bad = _: false; }; in E.Bad { x = 1; }); }
  { name = "postable.fun.07-validator-returning-enum-throws";
    test = fw.assertThrows "postable.fun.07"
      (let E = shared.enum "V" { Bad = _: Color; }; in E.Bad { x = 1; }); }

  # --- mixed literal + enum-typed variants ---
  { name = "postable.mixed.01-enum-inst-variant-tag";
    test = shared.Drive.self.tag == "self"; }
  { name = "postable.mixed.02-enum-inst-variant-value-tag";
    test = shared.Drive.self.value.tag == "Red"; }
  { name = "postable.mixed.03-string-variant-value";
    test = shared.Drive.intel.value == "intel"; }
  { name = "postable.mixed.04-list-of-strings-elem-0";
    test = builtins.elemAt shared.Drive.intel-nvidia.value 0 == "intel"; }
  { name = "postable.mixed.05-list-of-strings-elem-1";
    test = builtins.elemAt shared.Drive.intel-nvidia.value 1 == "nvidia"; }
  { name = "postable.mixed.06-list-2-elems-elem-1";
    test = builtins.elemAt shared.Drive.intel-nvidia-prime.value 1 == "nvidia-prime"; }
  { name = "postable.mixed.07-display-of-literal";
    test = shared.Drive.intel.display == "enum::Drive::intel(\"intel\")"; }
  { name = "postable.mixed.08-display-of-tuple-of-literals";
    test = shared.Drive.intel-nvidia.display == "enum::Drive::intel-nvidia(\"intel\",\"nvidia\")"; }
]
