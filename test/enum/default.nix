# @path: ~/projects/nixproj/nixpkgs/type/test/enum/default.nix
# @author: redskaber
# @datetime: 2026-03-10
# @description: type::test::enum::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
#
# enum = pattern: {};
#
# # 1.base-enum-variants
# Color = enum [ "Red" "Green" "Blue" ];
#
# # validator-function-example
# Validator_func = { ... }@ validator_args: validator_args.first // validator_args.second;
#
# # 2.postable-enum-variants
# Shape = enumType1: enumType2: enumType3: enum {
#   CirCle    = enumType1;
#   Square    = [ enumType2 enumType3 enumType2];
#   Triangle  = { pos1, pos2, pos3 }@instane: Validator_func instane;
#   Rhombus   = { pos1, pos2, pos3, ...}@instane: Validator_func instane;
# };
#
# # 3.enum.match variant
# # 3.1 base-enum-variants
# c_example = Color.Red;
# Color.match c_example {
#   Color.Red   = v: "enum::${v.tag} == enum::Color::Red";
#   Color.Green = v: "enum::${v.tag} == enum::Color::Green";
#   Color.Blue  = v: "enum::${v.tag} == enum::Color::Blue";
# };
# #3.2 postable-enum-variants
# Color3Shape = Shape Color Color Color;
# c3s_example = Color3Shape.Triangle { pos1=Color.Red; pos2=Color.Green; pos3=Color.Blue; };
# Color3Shape.match c3s_example {
#   Color3Shape.CirCle    = v: "enum::${v.tag} == enum::Shape::CirCle; Color: ${v.value}; or Color: ${v._0}";
#   Color3Shape.Square    = v: "enum::${v.tag} == enum::Shape::Square; Color: ${v.value}; or Color: ${v._0} ${v._1} ${v._2}";
#   Color3Shape.Triangle  = v: "enum::${v.tag} == enum::Shape::Triangle; Color: ${v.value}; or Color: ${v._0} ${v._1} ${v._2}; or ${v.pos1} ${v.pos2} ${v.pos3}";
#   _                     = v: "Other enum::${v.tag}";
# };
#
# # mk: csc = ColorShape.Circle Color.Red;
# #   get: (csc._0 => Color.Red) | (csc.value => Color.Red)
# # mk: css = ColorShape.Square [ Color.Red Color.Blue ];
# #   get: (css._0 => Color.Red, css._1 => Color.Blue) | (css.value => [ Color.Red Color.Blue ] )
# # mk: cst = ColorShape.Triangle { Color.Red Color.Green Color.Blue };
# #   get: (cst._0 => Color.Red, cst._1 => Color.Green, cst._2 => Color.Blue) | (cst.value => [ Color.Red Color.Green Color.Blue ] )
# # mk: csr = ColorShape.Rectangle { first=Color.Red; second=Color.Green; };
# #   get: (csr.first => Color.Red, csr.second => Color.Green) | (csr.value => { first = Color.Red; second = Color.Green; } )


let
  enum = (import ../../lib/enum).enum;
  types = (import  ../../lib/enum).types;
  lib = (import ../../lib/enum).lib;

  # 1.base-enum-variants
  Color = enum "Color" [ "Red" "Green" "Blue" ];
  cg = Color.Green;
  rc-cg = Color.match cg {
    Red   = v: "enum::Color::${v.tag}";
    Green = v: "enum::Color::${v.tag}";
    Blue  = v: "enum::Color::${v.tag}";
  };

  # 2.postable-enum-variants
  validator_func = { pos1, pos2, pos3, ...}:
    if pos1.tag == pos2.tag
      then { inherit pos1 pos2 pos3; }
    else { __throw = "Expected Triangle requires pos1 == pos2, found `${pos1.tag} != ${pos2.tag}`"; };

  Position = enum "Position" [ "local" "remote" ];
  Shape = enum "Shape" {
    Circle    = Color;
    Square    = [ Color Color Color ];
    Triangle  = { pos1, pos2, pos3 }@instane: validator_func instane;
    Rhombus   = { pos1, pos2, pos3, ...}@instane: validator_func instane;
  };

  # sp = Shape.Circle Postion.local;
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
  # 2.3
  st = Shape.Triangle { pos1=Color.Red; pos2=Color.Red; pos3=Color.Blue; };
  rs-st = Shape.match st {
    # Triangle  = v: "enum::${v.type.name}::${v.tag}::(${v.pos1.tag} ${v.pos2.tag} ${v.pos3.tag})";
    Triangle  = { pos1, pos2, pos3, type, tag, ... }: "enum::${type.name}::${tag}::(${pos1.tag} ${pos2.tag} ${pos3.tag})";
    _         = v: "Other: ${v.tag}";
  };
  # 2.4
  sr = Shape.Rhombus { pos1=Color.Green; pos2=Color.Green; pos3=Color.Red; _0=Color.Blue; };  # _0: ignore used
  rs-sr = Shape.match sr {
    Rhombus   = v: v.toString;
    _         = v: "Other: ${v.tag}";
  };

  sc-ty = Shape.toType builtins.lib;

  # 2.5 Generic Enumeration (exp)
  Graph = x: y: z: enum "Graph" {
    Beijing = { x, y, z }@instane: (a: { inherit (a) x y z; }) instane;
  };
  Graph3 = Graph Color Color Color;
  g3 = Graph3.Beijing { x=Color.Red; y=Color.Blue; z=Color.Green; };
  rs-g3 = Graph3.match g3 {
    Beijing = {x, y, z, type, tag, ...}: "enum::${type.name}::${tag}(${x.toString}, ${y.toString}, ${z.toString})";
    _       = v: "Other::${v.toString}";
  };

  # 2.6 Match-chian
  rs-g3c = Graph3.match g3 {
    Beijing = v: Color.match v.x {
        Red   = v: v.toString;
        Green = v: v.toString;
        _  = v: v.toString;
    };
    _ = v: v.toString;
  };

  # 2.7 Match-More-chain
  # Graph3.match [ Color Color Color] {
  #   (enum::Color::Red, enum::Color::Green, enum::Color::Blue) => {}
  # }
  constraint_validator_func = G: inst:
    if inst.pos1.type != G.X.__meta__ then {
        __throw = "Expected pos1 type ${G.X.__type__}, found ${inst.pos1.type.typename}";
      }
    else true;
  constraint_validator_func2 = G: inst: {};
  # GenericBase = enum "GenericBase<T,R>" [ "T" "R" ];  # tuple-enum should not generic-params
  # gen-t = GenericBase.T;
  GenericPostable = enum "GenericPostable<X,Y,Z>" {
    Int       = 1024;
    Float     = 10.24;
    Bool      = true;
    String    = "enum-string-variant";
    Path      = ./vers/v1.nix;
    Null      = null;
    Attr    = { a=100; b=20.0; };     # attr need used enum type
    Color     = Color;                # non-constraints
    ADT       = "X";
    Position  = [ "X" "Y" "Z" ];
    Currenter = G:{ pos1 ? "" , pos2 ? "", pos3 ? "" }@inst: inst;  # default only chioces
    Constraint= G:{ pos1, pos2, pos3 }@inst: constraint_validator_func G inst;
    ConFun    = G:{pos1, pos2, pos3 }@inst: constraint_validator_func2 G inst;
  };
  # Tips: constraints is type, don't instance(is real-type). and type no-only enumtype, nixtype (int, float, bool, string, path, null)
  #
  # => GenericPostable = X: Y: Z: enum "GenericPostable<X,Y,Z>" { ... }
  # or
  # => GenericPostable = {X, Y, Z}: eenum "GGenericPostable<X,Y,Z>" { ... }
  #
  # impl used GenericPostable Generic-enum to get real-enum:
  #   GG = GenericPostable [ Color Shape Position ];              # placeholder-mapping
  # or
  #   GG = GenericPostable { X=Color; Y=Shape; Z=Position; };
  #
  # GP = GenericPostable [ Color Shape Position ];
  GP = GenericPostable { X=Color; Y=Shape; Z=Position; };
  # GP = GenericPostable Color;
  gen-pi      = GP.Int;
  gen-pf      = GP.Float;
  gen-bo      = GP.Bool;
  gen-str     = GP.String;
  gen-path    = GP.Path;
  gen-null    = GP.Null;
  gen-pattr   = GP.Attr;
  gen-pcr     = GP.Color Color.Red;
  gen-adt     = GP.ADT Color.Blue;
  gen-pp      = GP.Position [ Color.Red (Shape.Circle Color.Red) Position.local ];   # position constraints
  gen-cur     = GP.Currenter { pos1=Color.Green; pos2=Color.Green; pos3=Color.Blue; };  # mapping constraints and through default-value placeholder-mapping type used constraints    (一样的)
  gen-dcur    = GP.Currenter { pos2=Color.Red; };
  gen-cons    = GP.Constraint { pos1=Color.Red; pos2=(Shape.Circle Color.Red); pos3=Position.local; };
  # gen-cons    = GP.Constraint { pos1=Position.local; };
  gen-cf      = GP.ConFun { pos1=Color.Green; pos2=(Shape.Circle Color.Blue); pos3=Position.remote; };

  rs-gp = GP.match gen-cons {
    Constraint = v: v.toString;
    # Constraint = { pos1, pos2, pos3, ...}: pos1.toString;
  };

  color = Color.Red;
  shape = Shape.Circle Color.Red;
  position = Position.local;
  # rs-example = GP.match [ color shape position ] {
  #   Red.Circle.local = { colorname, shapename, positionname }: ...;
  #   _._._ = { colorname, shapename, positionname }: ...;
  # };
  # EBNF
  # ::match       => "[" identifiter (identifiter)*? "]" "{" ::pattern  "}"
  # ::pattern     => "_" | indentifiter (.identifiter)*?  "=" ::handle_func
  # ::handle_func => "{" identifiter (, identifiter)*? "}" ":" ... ";"
  #
  rs-gps = GP.match [ color shape position ] {
    Red.Circle.local = { _1, _2, _3 }: "${_1.tag}, ${_2.tag}, ${_3.tag}";
    _._._ = { ... }: 10;
  };
  # builtins.attrNames patterns     # [ "Red" "_" ]
  # builtins.attrValues patterns    # [ { Circle = { local = «lambda local @ /nix/store/h8fgwcnmvxmr6mfp00bpi8xgpaf43gdg-source/test/enum/default.nix:241:24»; }; } { _ = { _ = «lambda _ @ /nix/store/h8fgwcnmvxmr6mfp00bpi8xgpaf43gdg-source/test/enum/default.nix:242:13»; }; } ]
  # patterns ? Red && patterns.Red ? Circle && patterns.Red.Circle ? local ...

  rs-gpsd = GP.match { inherit color shape position; } {
    __PORDER__        = [ "color" "shape" "position" ];
    Red.Circle.local  = { color, shape, position }: "${color.tag}, ${shape.tag}, ${position.tag}";
    Red.Circle._      = { color, shape, position }: 10;
    _._._             = { ... }: 0;
  };

in
{
  inherit
    Color Shape Position
    cg      rc-cg
    sc      rs-sc
    ss      rs-ss
    st      rs-st
    sr      rs-sr
    sc-ty
    Graph   Graph3
    g3      rs-g3
    rs-g3c

    # GenericBase
    # gen-t
    GenericPostable
    GP
    gen-pi
    gen-pf
    gen-bo
    gen-str
    gen-path
    gen-null
    gen-pattr
    gen-adt
    gen-pcr
    gen-pp
    gen-cur
    gen-dcur
    gen-cons
    gen-cf
    rs-gp
    rs-gps
    rs-gpsd
    color shape position
    lib
    types
  ;
}


