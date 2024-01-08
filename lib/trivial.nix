{ pkgs, ... }@inputs:

{
  storeDirectory = dir:
    let
      dirName = builtins.baseNameOf dir;
      drv = derivation {
        name = dirName;
        src = dir;
        builder = pkgs.writeShellScript "builder.sh" ''
          ${pkgs.coreutils}/bin/mkdir -p $out/${dirName}
          ${pkgs.coreutils}/bin/cp -rf $src/* $out/${dirName}
          ${pkgs.coreutils}/bin/cp -rf $src/.* $out/${dirName}
        '';
        system = pkgs.system;
      };
    in
    "${drv}/${dirName}";
}
