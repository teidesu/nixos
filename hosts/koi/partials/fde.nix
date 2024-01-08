{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    sbctl
    cryptsetup
    sbsigntool
  ];
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.secureboot = {
    enable = true;
    # generated with sbctl
    signingKeyPath = "/etc/secureboot/keys/db/db.key";
    signingCertPath = "/etc/secureboot/keys/db/db.pem";
  };
  boot.loader.systemd-boot.configurationLimit = 15;

  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices.root.crypttabExtraOpts = [ "tpm2-device=auto" ];
}
