{ pkgs, abs, config, ... }@inputs:

let 
  secrets = import (abs "lib/secrets.nix");
in {
  # sadly due to our network setup we cant properly extract this to a container
  # not a big deal though, since we only need to run it once
  imports = [
    (secrets.declare ["cloudflare-email" "cloudflare-token"])
  ];

  services.nginx = {
    enable = true;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    statusPage = true;
    enableReload = true;

    commonHttpConfig = ''
      set_real_ip_from 103.21.244.0/22;
      set_real_ip_from 103.22.200.0/22;
      set_real_ip_from 103.31.4.0/22;
      set_real_ip_from 104.16.0.0/13;
      set_real_ip_from 104.24.0.0/14;
      set_real_ip_from 108.162.192.0/18;
      set_real_ip_from 131.0.72.0/22;
      set_real_ip_from 141.101.64.0/18;
      set_real_ip_from 162.158.0.0/15;
      set_real_ip_from 172.64.0.0/13;
      set_real_ip_from 173.245.48.0/20;
      set_real_ip_from 188.114.96.0/20;
      set_real_ip_from 190.93.240.0/20;
      set_real_ip_from 197.234.240.0/22;
      set_real_ip_from 198.41.128.0/17;
      set_real_ip_from 2400:cb00::/32;
      set_real_ip_from 2606:4700::/32;
      set_real_ip_from 2803:f800::/32;
      set_real_ip_from 2405:b500::/32;
      set_real_ip_from 2405:8100::/32;
      set_real_ip_from 2c0f:f248::/32;
      set_real_ip_from 2a06:98c0::/29;
      real_ip_header CF-Connecting-IP;

      proxy_headers_hash_bucket_size 128;
    '';

    # default server that would reject all unmatched requests
    appendHttpConfig = ''
      server {
        listen 80 http2 default_server;
        listen 443 ssl http2 default_server;

        ssl_reject_handshake on;
        return 444;
      }
    '';

    # declared in the relevant service nixfiles
    # virtualHosts = { ... };
  };

  security.acme.acceptTerms = true;
  security.acme.certs."stupid.fish" = {
    email = "alina@tei.su";
    group = "nginx";
    dnsProvider = "cloudflare";
    extraDomainNames = [ "*.stupid.fish" ];
    credentialFiles = {
      "CLOUDFLARE_EMAIL_FILE" = config.age.secrets.cloudflare-email.path;
      "CLOUDFLARE_API_KEY_FILE" = config.age.secrets.cloudflare-token.path;
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
