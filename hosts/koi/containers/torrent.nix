{ abs, lib, pkgs, ... }@inputs:
let
  containers = (import (abs "lib/containers.nix") inputs);
  vueTorrent = pkgs.fetchurl {
    url = "https://github.com/WDaan/VueTorrent/releases/download/v2.4.0/vuetorrent.zip";
    hash = "sha256-ZM2AAJVqlzCXxvWnWhYDVBXZqpe0NzkFfYLvUTyzlZM=";
  };
in
{
  imports = [
    (containers.mkNixosContainer {
      name = "torrent";
      ephemeral = false;
      ip = ".0.2";
      private = true;

      config = { ... }: {
        imports = [
          (import (abs "services/qbittorrent.nix") inputs {
            port = 80;
            customFrontend = vueTorrent;
            customFrontendFolder = "vuetorrent";
            serviceConfig = {
              AmbientCapabilities = "CAP_NET_BIND_SERVICE";
            };
            setup = ''
              mkdir -p /var/lib/qbittorrent/temp
            '';
            config = {
              Preferences = {
                "WebUI\\Username" = "torrent";
                "WebUI\\Password_PBKDF2" = "\"@ByteArray(Gi7vRUB4k9veY9rOKmTRzw==:Mt0Dhy7rEV+ynH9+Jvm/UwnsNV1KOOQCY1g0QF4TTR1kvT27drZO/zaebH+LTcB3tT52m2T6eikpHxg8NcmXDg==)\"";
              };
              BitTorrent = {
                "Session\\DefaultSavePath" = "/mnt/download";
                "Session\\DisableAutoTMMByDefault" = "false";
                # puffer is an hdd, which bottlenecks the download speed
                # upload speed doesn't matter that much
                "Session\\TempPath" = "/var/lib/qbittorrent/temp";
                "Session\\TempPathEnabled" = "true";
              };
              Network = {
                "Proxy\\IP" = "10.42.0.2";
                "Proxy\\Port" = "@Variant(\\0\\0\\0\\x85\\x1e\\xd2)"; # 7890
                "Proxy\\Type" = "SOCKS5";
                "Proxy\\HostnameLookupEnabled" = "true";
              };
            };
          })
        ];
        networking.firewall.allowedTCPPorts = [ 80 ];
      };

      mounts = {
        "/mnt/download" = {
          hostPath = "/mnt/puffer/Downloads";
          isReadOnly = false;
        };
      };
    })
  ];

  services.nginx.virtualHosts."torrent.stupid.fish" = {
    forceSSL = true;
    useACMEHost = "stupid.fish";

    locations."/" = {
      proxyPass = "http://torrent.containers/";

      # https://github.com/qbittorrent/qBittorrent/issues/6962
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Host $host:$server_port;
        proxy_hide_header   Referer;
        proxy_hide_header   Origin;
        proxy_set_header    Referer           ''';
        proxy_set_header    Origin            ''';
      '';
    };
  };
}
