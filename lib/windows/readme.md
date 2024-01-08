Utils for Windows VMs provisioning and management (for fun)

The idea is first to create a base image with all the required software and then create a VM from it.
Base system image is ephemeral and is reset on every boot. User data is stored in a separate persistent image, which is mounted as D: drive.

The downside of this approach is that it takes a lot of time to create a base image, and every software install requires basically reinstalling windows.
The upside is that the system is always in a clean state and you can easily create a new VM from the base image.

## Usage
- Download Windows ISO from Microsoft
- List available editions in the ISO:
  ```bash
  nix-shell -p wimlib
  mkdir isomnt
  sudo mount -o loop /etc/iso/win11.iso isomnt
  wiminfo ./mnt/sources/install.wim | grep "^Name:"
  sudo umount isomnt
  rm -rf isomnt
  ```
- Create a base image:
  ```nix
  let 
    windows = import ./windows.nix { inherit pkgs; };
  in {
    some-image = windows.makeBaseImage { 
      windowsIso = /etc/iso/win11.iso;
      additionalFiles = [
        # optional, for ssh server
        windows.utils.openSshServerPackage
      ];
      unattendedParams = {
        users = {};
        administators = {
          "teidesu" = "0";
        };
        edition = "Windows 11 Pro";
      };
      preLoginScript = with windows.custom; compile [
        (system.withHostname "TEST")
        (network.withSshServer {
          keys = [
            ../ssh/teidesu.pub
          ];
        })
        # ...
      ];
    };
  }
  ```
- Create a VM: 
  ```nix
  systemd.services.windows = makeSystemdService {
    systemImage = some-image;
    name = "kyoko";
    userImageSize = "100G";
    qemuOptions = {
      macAddress = "00:16:D0:3B:E2:DC";
      extraFlags = [
        "-usbdevice tablet"
      ];
    };
  }
  ```

### Networking
When the VM is booted for the first time to make the base image, 
it will use qemu dhcp server to get an ip address. This is done to 
avoid having issues with access to `/dev/net/tun` for nix builder.

After that, when running as a systemd service, the VM will use an automatically managed TAP. By default, it is configured to use `br0`.

## Acknowledgements:
- [wfvm](https://git.m-labs.hk/M-Labs/wfvm)
