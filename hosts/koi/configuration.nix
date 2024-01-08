{ pkgs
, abs
, inputs
, ...
}:

{
  imports = [
    (abs "hosts/nixos-common.nix")
    (abs "users/teidesu/default.nix")
    ./hardware-configuration.nix

    ./partials/fde.nix

    ./services/ss-client.nix
    ./services/coredns.nix
    ./services/nginx.nix

    ./containers/torrent.nix
    ./containers/puffer.nix
    ./containers/sharkey
    ./vms/hass.nix
    # ./vms/windows.nix
  ];

  networking = {
    hostName = "koi";
    # nftables.enable = true;

    useDHCP = false;
    interfaces = {
      br0 = {
        ipv4.addresses = [{
          address = "10.42.0.2";
          prefixLength = 16;
        }];
      };
    };

    bridges = {
      br0 = {
        interfaces = [ "enp2s0" ];
      };
    };

    nat = {
      enable = true;
      internalInterfaces = [ "ve-+" "vb-+" "veth+" ];
      externalInterface = "br0";
    };

    defaultGateway = {
      address = "10.42.0.1";
      interface = "br0";
    };
    nameservers = [
      "127.0.0.1"
      "8.8.8.8"
      "8.8.4.4"
    ];
  };

  virtualisation.libvirtd = {
    enable = true;
    qemu.ovmf.enable = true;
    allowedBridges = [ "br0" ];
  };
  
  virtualisation.docker = {
    enable = true;
  };
  
  boot.extraModprobeConfig = ''
    options kvm_amd avic=1 nested=0
    options kvm ignore_msrs=N report_ignored_msrs=Y
  '';

  hardware.bluetooth.enable = true;
}

