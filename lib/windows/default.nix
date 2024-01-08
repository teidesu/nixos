{ abs, ... }@inputs:

{
  autounattend = import ./autounattend.nix inputs;
  custom = import ./customizers inputs;
  utils = import ./utils.nix inputs;
} // (import ./windows.nix inputs)
