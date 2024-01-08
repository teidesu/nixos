# nixos 

ok hi this is my nixos config. i use it only for my home server (for now).

the config is pretty much a mess and the code sucks.

## code style
a few rules i came up with for myself to avoid blackbox magic:
- no indirect imports using `readDir` or whatever
- no custom overlays - any custom utils are explicitly imported. 
  the only exception - globally available `abs` (in `specialArgs`) for absolute paths.
- no custom options - only options defined in [nixos search](https://search.nixos.org/options?channel=23.05) can be used.

there isn't much other than that, im just starting out.

## impure dependencies
note to self on what needs to be installed on the host manually:

- ~~`/etc/iso/win11.iso` - iso containing windows 11 installer (e.g. this: [magnet](magnet:?xt=urn:btih:56197d53136ffcecbae5225f0ac761121eacdac6&dn=Win11_22H2_English_x64v1.iso&tr=udp%3a%2f%2ftracker.torrent.eu.org%3a451%2fannounce&tr=udp%3a%2f%2ftracker.tiny-vps.com%3a6969%2fannounce&tr=udp%3a%2f%2fopen.stealth.si%3a80%2fannounce))~~ currently unused
- `/etc/vms/haos.img` - qcow2 image for haos vm (can be downloaded from the official website, the KVM/Proxmox image).
- `/etc/ssh/agenix_key` - private key for secret decryption
- `/etc/secureboot/keys` - secure boot keys, generated with `sudo nix-shell -p sbctl --run "sbctl create-keys"`
- to enroll fde onto tpm: `sudo systemd-cryptenroll /dev/nvme0n1p2 --tpm2-device=auto --tpm2-pcrs=0+2+7`

nginx may not start the first time, its fine, just run `sudo systemctl restart nginx` and it should work.
its likely due to docker containers not resolving yet.

## cat in a readme 🐈

![cat](https://cataas.com/cat)