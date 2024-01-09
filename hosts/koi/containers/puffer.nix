{ abs, lib, config, pkgs, ... }@inputs:

let
  containers = import (abs "lib/containers.nix") inputs;
  avahi = import (abs "lib/avahi.nix") inputs;
  systemd = import (abs "lib/systemd.nix") inputs;
  sftpgo = import (abs "services/sftpgo.nix") inputs;
  secrets = import (abs "lib/secrets.nix");

  sftpKey = secrets.mount config "sftpgo-ed25519";

  sambaConfig = {
    imports = [
      (systemd.mkOneshot {
        name = "smb-guest-setup";
        # for whatever reason smbd refuses to write unless we set the password
        script = "${pkgs.samba}/bin/smbpasswd -a smb-guest -n";
      })
    ];

    services.samba = {
      enable = true;
      openFirewall = true;

      securityType = "user";
      extraConfig = ''
        workgroup = WORKGROUP
        server string = puffer
        netbios name = puffer
        security = user
        hosts allow = 10.0.0.0/8
        hosts deny = 0.0.0.0/0
        guest account = smb-guest
        map to guest = bad user
        inherit permissions = yes

        # Performance
        socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
        read raw = yes
        write raw = yes
        server signing = no
        strict locking = no
        min receivefile size = 16384
        use sendfile = Yes
        aio read size = 16384
        aio write size = 16384

        # Fruit global config
        fruit:aapl = yes
        fruit:nfs_aces = no
        fruit:copyfile = no
        fruit:model = MacSamba
      '';

      shares =
        let
          publicShare = {
            browseable = "yes";
            "read only" = "no";
            "guest ok" = "yes";
            "create mask" = "2775";
            "directory mask" = "2775";
            "force user" = "smb-guest";
            "force group" = "puffer";
          };
        in
        {
          Downloads = {
            path = "/mnt/puffer/Downloads";
            browseable = "yes";
            "read only" = "yes";
            "guest ok" = "yes";
          };

          Public = publicShare // {
            path = "/mnt/puffer/Public";
          };

          # its ok for this to be local-public, since Time Machine 
          # backups are to be encrypted anyway
          # (and also im too lazy to set up users here)
          Backups = publicShare // {
            path = "/mnt/puffer/Backups";
            # whatever this means
            "vfs objects" = "catia fruit streams_xattr";
            "fruit:time machine" = "yes";
            "fruit:time machine max size" = "100G";
          };
        };
    };
  };

  avahiConfig = avahi.setup {
    name = "puffer";
    services = [
      { type = "_smb._tcp"; port = 445; }
      # cancer stuff for macs to see this disk as a time machine-compatible disk
      [
        { type = "_adisk._tcp"; port = 9; }
        { txt-record = "sys=waMa=0,adVF=0x100"; }
        { txt-record = "dk0=adVN=Puffer TimeMachine,adVF=0x82"; }
      ]
      { type = "_device-info._tcp"; port = 0; txt-record = "model=TimeCapsule8,119"; }
    ];
  };

  sftpgoConfig = sftpgo.setup {
    package = pkgs.callPackage (abs "packages/sftpgo.nix") {
      tags = [ "nogcs" "nos3" "noazblob" "nobolt" "nomysql" "nopgsql" "nometrics" "bundle" ];
    };

    config = {
      sftpd = {
        bindings = [
          { port = 22; }
        ];
        host_keys = [ "id_ed25519" ];
      };
    };
    keys.ed25519 = sftpKey.path;

    users.guest = {
      # bcrypt-hashed 0
      password = "$2a$10$IcGdNtx10ycmPRD6lA4c0uNfRXTEchFRzCZEDkngTjzForn6pd0Wa";
    };

    folders.Public.path = "/mnt/puffer/Public";

    usersFolders = [
      { username = "guest"; folder = "Public"; }
    ];
  };

  container = containers.mkNixosContainer {
    name = "puffer";
    ip = "10.42.0.5";
    private = false;

    config = { ... }: {
      imports = [
        sambaConfig
        avahiConfig
        sftpgoConfig
      ];

      users.groups.puffer = { };
      users.users.smb-guest = {
        isNormalUser = true;
        description = "Guest account for Samba";
        extraGroups = [ "puffer" ];
        createHome = false;
        shell = pkgs.shadow;
      };

      systemd.tmpfiles.rules = [
        "d /mnt/puffer/Public 0755 smb-guest puffer - -"
        "d /mnt/puffer/Backups 0755 smb-guest puffer - -"
      ];

      networking.firewall.allowedTCPPorts = [ 22 ];
    };

    mounts = {
      "/mnt/puffer" = {
        hostPath = "/mnt/puffer";
        isReadOnly = false;
      };
    } // (sftpKey.mounts);
  };
in
{
  imports = [
    (secrets.declare [ "sftpgo-ed25519" ])
    container
  ];
}

