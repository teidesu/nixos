{ pkgs, ... }:

{
  virtioWinIso = pkgs.fetchurl {
    url = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.229-1/virtio-win-0.1.229.iso";
    hash = "sha256-yIoN3jRgXq7mz4ifPioMKvPK65G130WhJcpPcBrLu+A=";
  };

  openSshServerPackage = {
    name = "OpenSSH-Win64.zip";
    path = pkgs.fetchurl {
      url = "https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.2.2.0p1-Beta/OpenSSH-Win64.zip";
      hash = "sha256-7IFEoQcBR0DsPOFuxRcQOY/DkPylNEkxwVBufMLhgfM==";
    };
  };

  mkQemuFlags =
    { efi ? true
    , cores ? "4"
    , memory ? "4G"
    , extraFlags ? [ ]
    , OVMF ? pkgs.OVMF.override {
        secureBoot = true;
      }
    , enableTpm ? true
    , vnc ? ":0"
    , network ? true
    , cpufeatures ? "+topoext,+invtsc,host-cache-info=on,l3-cache=on,x2apic=off"
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
    ,
    }: [
      "-nodefaults"
      "-no-user-config"
      "-enable-kvm"
      "-cpu host,check,enforce,migratable=no,kvm=on,${cpufeatures},${hvflags}"
      "-smp ${cores}"
      "-m ${memory}"
      "-M q35,hpet=off,mem-merge=off"
      "-device qxl-vga,xres=1920,yres=1080,max_outputs=1"
      "-device qemu-xhci"
      "-global kvm-pit.lost_tick_policy=discard"
    ] ++ pkgs.lib.optionals efi [
      "-bios ${OVMF.fd}/FV/OVMF.fd"
    ] ++ pkgs.lib.optionals enableTpm [
      "-chardev socket,id=chrtpm,path=tpm.sock"
      "-tpmdev emulator,id=tpm0,chardev=chrtpm"
      "-device tpm-tis,tpmdev=tpm0"
    ] ++ pkgs.lib.optionals (vnc != null) [
      "-vnc ${vnc}"
    ] ++ pkgs.lib.optionals (tap != null) [
      "-netdev tap,id=n1,ifname=${tap},script=no,downscript=no"
      "-device virtio-net-pci,netdev=n1,mac=${macAddress}"
    ] ++ extraFlags;

  tpmStartCommands = ''
    mkdir -p tpmstate
    ${pkgs.swtpm}/bin/swtpm socket \
      --tpmstate dir=tpmstate \
      --ctrl type=unixio,path=tpm.sock &
    echo $! > tpm.pid
    disown
  '';

  tpmStopCommands = ''
    kill $(cat tpm.pid) || true
    rm tpm.pid
    rm -rf tpmstate
  '';

  tapStartCommands = tap: bridge: ''
    ${pkgs.iproute2}/bin/ip tuntap add dev ${tap} mode tap
    ${pkgs.iproute2}/bin/ip link set ${tap} up promisc on
    ${pkgs.bridge-utils}/sbin/brctl addif ${bridge} ${tap}
    ${pkgs.iproute2}/bin/ip link set dev ${tap} master ${bridge}
  '';

  tapStopCommands = tap: ''
    ${pkgs.iproute2}/bin/ip tuntap del ${tap} mode tap
  '';
}
