{ pkgs, ... }@inputs:

let
  utils = import ./utils.nix inputs;
  autounattend = import ./autounattend.nix inputs;
in
rec {
  makeUnattendedImage =
    { windowsIso
    , name ? "windows"
    , params ? { }
    ,
    }:
    let
      efi = params.uefi or true;
      autounattendXml = pkgs.writeText "autounattend.xml"
        (autounattend.mkAutoUnattend (params));
    in
    pkgs.runCommand "unattended-${name}.img" { buildInputs = [ pkgs.p7zip pkgs.guestfs-tools pkgs.wimlib ]; } ''
      #!${pkgs.runtimeShell}
      set -euxo pipefail

      mkdir -p win
      7z x -y ${windowsIso} -owin

      # Split image so it fits in FAT32 partition
      wimsplit win/sources/install.wim win/sources/install.swm 4070
      rm win/sources/install.wim

      cp ${autounattendXml} win/autounattend.xml

      ${if efi then ''
        virt-make-fs --partition --type=fat win/ image.img
      '' else ''
        ${pkgs.cdrkit}/bin/mkisofs -iso-level 4 -l -R -udf -D -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -hide boot.catalog -eltorito-alt-boot -o image.img win/
      ''}
      rm -rf win

      mv image.img $out
    '';

  makeBootstrapImage =
    { virtioWinIso ? utils.virtioWinIso
    , additionalFiles ? [ ]
    ,
    }: pkgs.runCommand "win-bootstrap.img" { buildInputs = [ pkgs.p7zip pkgs.guestfs-tools ]; } ''
      #!${pkgs.runtimeShell}
      set -euxo pipefail

      mkdir -p pkgs;

      # Extract virtio drivers
      7z x -y ${virtioWinIso} -opkgs/virtio

      # Extract additional files
      ${
        builtins.concatStringsSep "\n" (
          builtins.map 
            ({ name, path }: 
              if builtins.readFileType path == "directory" then
                "cp -r ${path} pkgs/${name}"
              else
                "cp ${path} pkgs/${name}"
            ) 
            additionalFiles
        )
      }

      virt-make-fs --partition --type=fat pkgs/ $out
    '';

  makeBaseImage =
    { windowsIso
    , virtioWinIso ? utils.virtioWinIso
    , diskImageSize ? "80G"
    , additionalFiles ? [ ]
    , name ? "windows"
    , unattendedParams ? { }
    , qemuOptions ? { }
    , postInstallScript ? null
    , preLoginScript ? null
    , tapName ? "tap0"
    , bridgeName ? "br0"
    ,
    }: pkgs.runCommand "system-${name}.img" { buildInputs = [ pkgs.qemu ]; } (
      let
        efi = qemuOptions.efi or true;
        enableTpm = qemuOptions.enableTpm or true;

        postInstallScriptFile =
          if postInstallScript == null then null
          else pkgs.writeText "post-install.bat" postInstallScript;

        preLoginScriptFile =
          if preLoginScript == null then null
          else pkgs.writeText "pre-login.bat" preLoginScript;

        installerImage = makeUnattendedImage {
          inherit windowsIso name;
          params = unattendedParams // {
            driverPaths = [
              "D:\\"
              "E:\\"
              "C:\\virtio\\amd64\\w11"
              "C:\\virtio\\NetKVM\\w11\\amd64"
              "C:\\virtio\\viogpudo\\w11\\amd64"
            ] ++ (unattendedParams.driverPaths or [ ]);
            afterInstallCommands =
              (unattendedParams.afterInstallCommands or [ ])
                ++ (if postInstallScript == null then [ ] else [
                "cmd /C FOR %i IN (c d e f g h i j k l m n o p q r s t u v w x y z) DO IF EXIST %i:\\post-install.bat START /WAIT %i:\\post-install.bat %i"
              ]);
            beforeFirstLoginCommands =
              (unattendedParams.beforeFirstLoginCommands or [ ])
                ++ (if preLoginScriptFile == null then [
                "shutdown /s /t 0"
              ] else [
                "cmd /C FOR %i IN (c d e f g h i j k l m n o p q r s t u v w x y z) DO IF EXIST %i:\\pre-login.bat START /WAIT %i:\\pre-login.bat %i"
              ]);
          };
        };

        bootstrapImage = makeBootstrapImage {
          inherit virtioWinIso;
          additionalFiles =
            additionalFiles ++
            (if postInstallScriptFile == null then [ ] else [{
              name = "post-install.bat";
              path = postInstallScriptFile;
            }]) ++
            (if preLoginScriptFile == null then [ ] else [{
              name = "pre-login.bat";
              path = preLoginScriptFile;
            }]);
        };

        qemuParams = utils.mkQemuFlags (qemuOptions // {
          vnc = qemuOptions.vnc or ":1";
          extraFlags = [
            # "CD" drive with bootstrap pkgs
            "-drive id=virtio-win,file=${bootstrapImage},if=none,format=raw,readonly=on"
            "-device usb-storage,drive=virtio-win"
            # USB boot (installer)
            "-drive id=win-install,file=${installerImage},if=none,format=raw,readonly=on,media=${if efi then "disk" else "cdrom"}"
            "-device usb-storage,drive=win-install"
            # Output image (installed OS)
            "-object iothread,id=thread-scsi"
            "-device virtio-scsi-pci,bus=pcie.0,num_queues=8,iothread=thread-scsi,id=scsi"
            "-blockdev driver=qcow2,file.driver=file,file.filename=output.img,file.aio=io_uring,discard=unmap,detect-zeroes=unmap,read-only=off,cache.direct=on,node-name=drive-system"
            "-device scsi-hd,drive=drive-system,bus=scsi.0,rotation_rate=1,physical_block_size=512,logical_block_size=512,id=scsi-drive-system"
            # "-drive file=output.img,index=0,media=disk,cache=unsafe"
            "-monitor stdio"
            "-device virtio-net-pci,netdev=n1"
            "-netdev user,id=n1,net=192.168.1.0/24,restrict=on"
          ] ++ (qemuOptions.extraFlags or [ ]);
          tap = null;
        });
      in
      ''
        #!${pkgs.runtimeShell}
        set -euxo pipefail
        ${if enableTpm then utils.tpmStartCommands else ""}
      
        qemu-img create -f qcow2 output.img ${diskImageSize}
        qemu-system-x86_64 ${builtins.concatStringsSep " " qemuParams}
      
        ${if enableTpm then utils.tpmStopCommands else ""}

        mv output.img $out
      ''
    );

  makeSystemdService =
    { systemImage
    , name ? "windows"
    , tapName ? "tap-${name}"
    , bridgeName ? "br0"
    , userImagePath ? "/etc/vms/user-disks/"
    , userImageSize ? "10G"
    , qemuOptions ? { }
    , tempDir ? "/tmp"
    ,
    }:
    let
      enableTpm = qemuOptions.enableTpm or true;
      userImage = "${userImagePath}${name}.img";
      sockPath = "/run/qemu-${name}.mon.sock";
      qemuParams = utils.mkQemuFlags (qemuOptions // {
        extraFlags = [
          "-object iothread,id=thread-scsi"
          "-device virtio-scsi-pci,bus=pcie.0,num_queues=8,iothread=thread-scsi,id=scsi"
          # System image (installed OS)
          "-blockdev driver=qcow2,file.driver=file,file.filename=system.img,file.aio=io_uring,discard=unmap,detect-zeroes=unmap,read-only=off,cache.direct=on,node-name=drive-system"
          "-device scsi-hd,drive=drive-system,bus=scsi.0,rotation_rate=1,physical_block_size=512,logical_block_size=512,id=scsi-drive-system"
          # User image (persistent data)
          "-blockdev driver=qcow2,file.driver=file,file.filename=${userImage},file.aio=io_uring,discard=unmap,detect-zeroes=unmap,read-only=off,cache.direct=on,node-name=drive-user"
          "-device scsi-hd,drive=drive-user,bus=scsi.0,rotation_rate=1,physical_block_size=512,logical_block_size=512,id=scsi-drive-user"
          # "-drive file=output.img,index=0,media=disk,cache=unsafe"
          "-monitor unix:${sockPath},server,nowait"
        ] ++ (qemuOptions.extraFlags or [ ]);
        tap = tapName;
      });
    in
    {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig.PrivateTmp = true;
      script = ''
        set -euxo pipefail

        cd ${tempDir}
        cp ${systemImage} system.img
      
        if ! test -f ${userImage}; then 
          mkdir -p ${userImagePath}
          ${pkgs.qemu}/bin/qemu-img create -f qcow2 ${userImage} ${userImageSize}
        fi

        ${if enableTpm then utils.tpmStartCommands else ""}
        ${utils.tapStartCommands tapName bridgeName}

        ${pkgs.qemu}/bin/qemu-system-x86_64 ${builtins.concatStringsSep " " qemuParams}

        ${if enableTpm then utils.tpmStopCommands else ""}
        ${utils.tapStopCommands tapName}
      '';

      preStop = ''
        echo 'system_powerdown' | ${pkgs.socat}/bin/socat - UNIX-CONNECT:${sockPath}
        sleep 10
      '';
    };
}
