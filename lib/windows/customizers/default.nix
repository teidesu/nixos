{ pkgs, abs, ... }:

let
  batch = import (abs "lib/batch.nix") { inherit pkgs; };
in
rec {
  inherit batch;

  explorer = import ./explorer.nix { inherit pkgs batch; };
  debloat = import ./debloat.nix { inherit pkgs batch; };
  system = import ./system.nix { inherit pkgs batch; };
  network = import ./network.nix { inherit pkgs batch; };
  software = import ./software.nix { inherit pkgs batch; };

  compile = lines:
    "@echo off\n" +
    "rem !! This script was auto-generated with nix, don't edit\n" +
    "set SCRIPT_DRIVE=%1\n" +
    batch.compile lines +
    # "";
    "\nshutdown /s /t 0";
}
