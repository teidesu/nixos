{ pkgs, lib, ... }@inputs:
let
  trivial = import ./trivial.nix inputs;
in
{
  # this function is quite deeply tied to my home network setup
  # i should make it more generic one day
  mkNixosContainer =
    { name
    , config
    , ip
    , private ? true
    , mounts ? { }
    , containerConfig ? { }
    , ephemeral ? true
    }: {
      containers.${name} = {
        autoStart = true;
        ephemeral = ephemeral;
        privateNetwork = true;

        config = { lib, ... }: {
          imports = [
            config
          ];

          networking = {
            defaultGateway = "10.42.0.1";

            # https://github.com/NixOS/nixpkgs/issues/162686
            useHostResolvConf = lib.mkForce false;

            nameservers = [
              "10.42.0.2"
              "8.8.8.8"
              "8.8.4.4"
            ];
          };
          system.stateVersion = "24.05";
        };

        bindMounts = mounts;
      } // (if private then {
        hostAddress = "10.88${ip}";
        localAddress = "10.89${ip}";
      } else {
        hostBridge = "br0";
        localAddress = "${ip}/16";
      }) // containerConfig;
    };

  # nixos oci-containers fucking suck, so we just do a one-shot 
  # systemd service that invokes docker-compose
  #
  # not very reproducible nor declarative, but compatible with pretty much
  # anything, which is (imo) more important for a home server
  mkDockerComposeContainer =
    { directory
    , name ? builtins.baseNameOf directory
    , autoStart ? true
    , extraConfig ? { }
    , env ? { }
    , envFiles ? [ ]
    , extraFlags ? [ ]
    }:
    let
      # referencing the file directly would make the service dependant
      # on the entire flake, resulting in the container being restarted
      # every time we change anything at all
      storeDir = trivial.storeDirectory directory;

      cmdline = [
        "--build"
        "--remove-orphans"
      ] ++ map (env: "--env-file ${env}") envFiles
      ++ map (name: "-e ${name}=${lib.escapeShellArg env.${name}}") (builtins.attrNames env)
      ++ extraFlags;
    in
    {
      systemd.services."docker-compose-${name}" = {
        wantedBy = if autoStart then [ "multi-user.target" ] else [ ];
        after = [ "docker.service" "docker.socket" ];
        serviceConfig = {
          WorkingDirectory = storeDir;
          ExecStart = "${pkgs.docker}/bin/docker compose up ${builtins.concatStringsSep " " cmdline}";
          ExecStopPost = "${pkgs.docker}/bin/docker compose down";
        } // (extraConfig.serviceConfig or { });
      } // (builtins.removeAttrs extraConfig [ "serviceConfig" ]);
    };
}
