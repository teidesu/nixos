{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    oh-my-zsh = {
      enable = true;
      theme = "agnoster";
      extraConfig = ''
        zstyle ':bracketed-paste-magic' active-widgets '.self-*'
      '';
    };

    syntaxHighlighting.enable = true;
    enableAutosuggestions = true;

    shellAliases = {
      "rm" = "rm -f";
      "systemctl" = "sudo systemctl";
      "entervenv" = "source venv/bin/activate";
    };

    initExtra = ''
      unsetopt correct_all
      export CURRENT_BG="$(( `hostname | cksum | cut -f 1 -d ' '` % 255 ))"
    '';
  };
}
