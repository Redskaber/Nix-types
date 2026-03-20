# @path: ~/projects/nixproj/nixpkgs/type/flake.nix
# @author: redskaber
# @datetime: 2026-03-10
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html

{
  description = "Kilig(Redskaber)'s declarative development environment (expend types)";
  inputs = {};

  outputs =
  {
    self,
    ...
  } @ inputs: let
    lib = import ./lib;
    export = {
      test = import ./test;
    } // lib;
  in export;
}


