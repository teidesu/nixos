{ pkgs, ... }@inputs:

let
  mkDiskFlags = disks: if (builtins.length disks == 0) then [ ] else
  ([
    "-object iothread,id=thread-scsi"
    "-device virtio-scsi-pci,bus=pcie.0,num_queues=8,iothread=thread-scsi,id=scsi"
  ] ++ map
    (
      disk:
      let
        name = disk.name;
        driver = disk.driver or "qcow2";
        path = disk.path;
      in
      builtins.concatStringsSep " " [
        "-blockdev driver=${driver},file.driver=file,file.filename=${path},file.aio=io_uring,discard=unmap,detect-zeroes=unmap,read-only=off,cache.direct=on,node-name=${name}"
        "-device scsi-hd,drive=${name},bus=scsi.0,rotation_rate=1,physical_block_size=512,logical_block_size=512,id=scsi-${name}"
      ]
    )
    disks);

  mkUsbFlags = usbs: if (builtins.length usbs == 0) then [ ] else
  ([
    "-device qemu-xhci,id=xhci"
  ] ++ pkgs.lib.imap0
    (
      idx: usb: "-device ${usb},bus=xhci.0,port=${toString (idx + 1)},id=usb${toString idx}"
    )
    usbs);

  tapStartCommands = tap: bridge: ''
    ${tapStopCommands tap}
    ${pkgs.iproute2}/bin/ip tuntap add dev ${tap} mode tap
    ${pkgs.iproute2}/bin/ip link set ${tap} up promisc on
    ${pkgs.bridge-utils}/sbin/brctl addif ${bridge} ${tap}
    ${pkgs.iproute2}/bin/ip link set dev ${tap} master ${bridge}
  '';

  tapStopCommands = tap: ''
    if (${pkgs.iproute2}/bin/ip tuntap show | grep "^${tap}:"); then
      ${pkgs.iproute2}/bin/ip tuntap del ${tap} mode tap
    fi
  '';

  mkQemuFlags =
    { efi ? true
    , cores ? "4"
    , memory ? "4G"
    , disks ? [ ]
    , usbs ? [ ]
    , extraFlags ? [ ]
    , OVMF ? pkgs.OVMF.override {
        secureBoot = true;
      }
    , enableTpm ? false
    , vnc ? null
    , network ? true
    , cpufeatures ? "+topoext,+invtsc,host-cache-info=on,l3-cache=on,x2apic=off,+kvm_pv_eoi,+kvm_pv_unhalt"
    , hvflags ? (
        builtins.concatStringsSep "," [
          "hv-relaxed"
          "hv-vapic"
          "hv-spinlocks=0x1fff"
          "hv-vpindex"
          "hv-runtime"
          "hv-crash"
          "hv-time"
          "hv-synic"
          "hv-stimer"
          "hv-tlbflush"
          "hv-ipi"
          "hv-reset"
          "hv-frequencies"
          "hv-stimer-direct"
          "hv-avic"
          "hv-no-nonarch-coresharing=on"
        ]
      )
    , tap ? null
    , macAddress ? "01:23:45:67:89:ab"
    , display ? true
    }: [
      "-nodefaults"
      "-no-user-config"
      "-enable-kvm"
      "-cpu host,check,enforce,migratable=no,kvm=on,${cpufeatures},${hvflags}"
      "-smp ${cores}"
      "-m ${memory}"
      "-M q35,hpet=off,mem-merge=off"
      "-device qemu-xhci"
      "-global kvm-pit.lost_tick_policy=discard"
    ] ++ pkgs.lib.optionals display [
      "-device qxl-vga,xres=1920,yres=1080,max_outputs=1"
    ] ++ pkgs.lib.optionals efi [
      "-bios ${OVMF.fd}/FV/OVMF.fd"
    ] ++ pkgs.lib.optionals enableTpm [
      "-chardev socket,id=chrtpm,path=tpm.sock"
      "-tpmdev emulator,id=tpm0,chardev=chrtpm"
      "-device tpm-tis,tpmdev=tpm0"
    ] ++ (if (vnc != null) then [
      "-vnc ${vnc}"
    ] else [
      "-display none"
    ]) ++ pkgs.lib.optionals (tap != null) [
      "-netdev tap,id=net0,ifname=${tap},script=no,downscript=no"
      "-device virtio-net-pci,netdev=net0,mac=${macAddress}"
    ] ++ (mkDiskFlags disks) ++ (mkUsbFlags usbs) ++ extraFlags;
in
{
  mkSystemdService =
    { name
    , qemu ? "${pkgs.qemu}/bin/qemu-system-x86_64"
    , tapName ? "tap-${name}"
    , qemuOptions ? { }
    , bridgeName ? "br0"
    , beforeStart ? ""
    , afterEnd ? ""
    ,
    }:
    let
      sockPath = "/run/qemu-${name}.mon.sock";
      qemuParams = mkQemuFlags (qemuOptions // {
        tap = tapName;
        extraFlags =
          (qemuOptions.extraFlags or [ ]) ++
            [ "-monitor unix:${sockPath},server,nowait" ];
      });
    in
    {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig.PrivateTmp = true;
      script = ''
        set -euxo pipefail

        ${if (tapName != null) then (tapStartCommands tapName bridgeName) else ""}
        ${beforeStart}

        ${qemu} ${builtins.concatStringsSep " " qemuParams}

        ${afterEnd}
        ${if (tapName != null) then (tapStopCommands tapName) else ""}
      '';

      preStop = ''
        echo 'system_powerdown' | ${pkgs.socat}/bin/socat - UNIX-CONNECT:${sockPath}
        sleep 10
      '';

      postStop = ''
        ${if (tapName != null) then (tapStopCommands tapName) else ""}
      '';
    };
}
