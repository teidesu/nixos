{ abs, pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "@wheel" ];
  # nix.settings.sandbox = false;

  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_US.UTF-8";
  security.sudo.wheelNeedsPassword = false;

  age.identityPaths = [
    "/etc/ssh/agenix_key"
  ];

  programs.zsh.enable = true;
  environment.systemPackages = with pkgs; [
    git
    micro
    wget
    pciutils
    dnsutils
    bridge-utils
    screen
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  system.stateVersion = "23.05";
}
