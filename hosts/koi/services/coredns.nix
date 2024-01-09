{ abs, pkgs, config, ... }@inputs:

let
  coredns = pkgs.callPackage (abs "packages/coredns.nix") {};

  hosts = pkgs.writeText "hosts" ''
    10.42.0.1 keenetic.stupid.fish
    10.42.0.2 torrent.stupid.fish
    10.42.0.2 koi.stupid.fish
    10.42.0.2 hass.stupid.fish
    10.42.0.2 very.stupid.fish
    10.42.0.5 puffer.stupid.fish
  '';

  package = coredns.override {
    externalPlugins = [{
      name = "docker";
      repo = "github.com/kevinjqiu/coredns-dockerdiscovery";
      version = "06643b6edfed621b4153b5b2ab783ec5d4a6e697";
    }];
    vendorHash = "sha256-URLiZXTj8Z/wDNI8gxVFthjitVxL9rugySDXYzDxNJg=";
  };
in
{
  services.coredns = {
    enable = true;
    config = ''
        (local_only) {
          acl {
            allow net 127.0.0.0/8 # localhost
            allow net 172.16.0.0/12 # docker
            allow net 10.42.0.0/24 # nixos containers
            block
          }
        }

      .:53 {
        cache
        header {
          response set ra # https://github.com/coredns/coredns/issues/3690#issuecomment-1573865953
        }
        hosts ${hosts} {
          reload 0
          fallthrough
        }
        forward . 8.8.8.8 8.8.4.4
      }

      docker:53 {
        import local_only
        docker {
          compose_domain docker
        }
      }

      # nixos puts ip addresses of the containers into /etc/hosts with `.containers` suffix
      # let's just re-use that as is
      containers:53 {
        import local_only
        hosts
      }
    '';
    package = package;
  };

  systemd.services.coredns = {
    serviceConfig = {
      DynamicUser = pkgs.lib.mkForce false;
      User = "coredns";
    };
  };

  users.users.coredns = {
    isNormalUser = true;
    extraGroups = [ "docker" ];
    createHome = false;
    shell = pkgs.shadow;
  };

  networking.firewall.allowedUDPPorts = [ 53 ];
}
