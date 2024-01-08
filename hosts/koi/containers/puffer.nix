{ abs, lib, pkgs, ... }@inputs:

let
  containers = (import (abs "lib/containers.nix") inputs);
  avahi = (import (abs "lib/avahi.nix") inputs);
  systemd = (import (abs "lib/systemd.nix") inputs);
in
containers.mkNixosContainer {
  name = "puffer";
  ip = "10.42.0.5";
  private = false;

  config = { ... }: {
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

    imports = [
      (systemd.mkOneshot {
        name = "smb-guest-setup";
        # for whatever reason smbd refuses to write unless we set the password
        script = "${pkgs.samba}/bin/smbpasswd -a smb-guest -n";
      })
      (avahi.setup {
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
      })
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

  };

  mounts = {
    "/mnt/puffer" = {
      hostPath = "/mnt/puffer";
      isReadOnly = false;
    };
  };
}

