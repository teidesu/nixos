{ config, abs, lib, pkgs, modulesPath, ... }@inputs:

let
  systemd = import (abs "lib/systemd.nix") inputs;
in
{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      (systemd.mkOneshot {
        name = "puffer-spindown";
        script = "${pkgs.hdparm}/bin/hdparm -S 120 /dev/disk/by-uuid/42d1c1e4-57c8-4249-b6e7-1233803b3798";
      })
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usbhid" "uas" "usb_storage" "sd_mod" "tpm_crb" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/49a88223-231b-4fe4-8d2f-13799a3fad32";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/5DAC-EE9F";
    fsType = "vfat";
  };

  fileSystems."/mnt/puffer" =
    {
      device = "/dev/mapper/puffer";
      fsType = "ext4";
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/c418bb69-15cf-4d47-b9a0-0cf7191551da"; }];
  boot.initrd.luks.devices.root = {
    device = "/dev/disk/by-uuid/57d168a4-2bc6-4f6c-9cd6-d2d5c775de7d";
    preLVM = true;
    allowDiscards = true;
  };
  boot.initrd.luks.devices.puffer = {
    device = "/dev/disk/by-uuid/42d1c1e4-57c8-4249-b6e7-1233803b3798";
    preLVM = true;
    allowDiscards = true;
  };
  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp2s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
