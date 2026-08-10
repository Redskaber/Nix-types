# @path: test/cases/shared.nix
# @description: Shared fixtures used by multiple test case modules.

let
  libMod = import ../../lib/default.nix;
in
{
  inherit (libMod) enum types lib;

  # 1. unit enum
  Color = libMod.enum "Color" [ "Red" "Green" "Blue" ];
  Position = libMod.enum "Position" [ "local" "remote" ];
  Singleton = libMod.enum "Singleton" [ "Only" ];

  # 2. mixed literal + enum-typed variants
  Drive = libMod.enum "Drive" {
    self                = (libMod.enum "Color" [ "Red" "Green" "Blue" ]).Red;
    intel               = "intel";
    amd                 = "amd";
    nvidia              = "nvidia";
    nvidia-prime        = "nvidia-prime";
    intel-nvidia        = [ "intel" "nvidia" ];
    amd-nvidia          = [ "amd" "nvidia" ];
    intel-nvidia-prime  = [ "intel" "nvidia-prime" ];
    amd-nvidia-prime    = [ "amd" "nvidia-prime" ];
  };

  # 3. all-literal enum (exercises every supported literal type)
  Literals = libMod.enum "Literals" {
    Int    = 1024;
    Float  = 10.24;
    Bool   = true;
    Str    = "enum-string-variant";
    Path   = ./sample.txt;
    Null   = null;
    DeepList = [ "first" "second" ];
    DeepNestedList = [ [ "a" "b" ] [ "c" ] ];
  };
}
