{ config, abs, pkgs, ... }@inputs:

let
  secrets = import (abs "lib/secrets.nix");
in
{
  imports = [
    (secrets.declare [ "ss-desu-arm-password" "ss-desu-arm-ip" ])
    ((import (abs "services/shadowsocks-rust.nix") inputs) {
      serverFile = config.age.secrets.ss-desu-arm-ip.path;
      port = 9000;
      passwordFile = config.age.secrets.ss-desu-arm-password.path;
      mode = "tcp_and_udp";
      fastOpen = true;
      encryptionMethod = "chacha20-ietf-poly1305";

      client = true;
      localPort = 7890;
    })
  ];

  # http -> socks5 proxy
  services.privoxy = {
    enable = true;
    settings = {
      listen-address = "0.0.0.0:7891";
      forward-socks5 = "/ 127.0.0.1:7890 .";
    };
  };

  networking.firewall.allowedTCPPorts = [ 7890 7891 ];
}
