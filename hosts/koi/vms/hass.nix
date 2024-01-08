{ abs, pkgs, ... }@inputs:

let
  qemu = import (abs "lib/qemu.nix") inputs;
in
{
  systemd.services.hass = qemu.mkSystemdService {
    name = "hass";
    qemuOptions = {
      cores = "2";
      disks = [
        {
          name = "haos";
          path = "/etc/vms/haos.img";
        }
      ];
      usbs = [
        # Silicon Labs CP210x UART Bridge (for Zigbee2MQTT)
        "usb-host,vendorid=0x10c4,productid=0xea60"
      ];
      macAddress = "38:5b:4b:db:f9:76";
    };
  };

  services.nginx.virtualHosts."hass.stupid.fish" = {
    forceSSL = true;
    useACMEHost = "stupid.fish";

    locations."/" = {
      proxyPass = "http://10.42.0.3:8123/";
      proxyWebsockets = true;
    };
  };
}
