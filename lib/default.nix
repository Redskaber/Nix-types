# @path: ~/projects/nixproj/nixpkgs/type/lib/default.nix
# @author: redskaber
# @datetime: 2026-03-10
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html

{ nixpkgs, ... }:
{
  imports = [
    ./enum
  ];
}


