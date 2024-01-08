{ lib, pkgs, ... }:

{
  # qBittorrent web UI port.
  port ? 8080
, # The directory where qBittorrent will create files
  dataDir ? "/var/lib/qbittorrent"
, # Number of files to allow qBittorrent to open
  openFilesLimit ? 4096
, # ZIP containing custom frontend
  customFrontend ? null
, # Folder name inside ZIP containing custom frontend
  customFrontendFolder ? null
, # Additional qbittorrent config
  config ? { }
, user ? "qbittorrent"
, group ? "qbittorrent"
, # Systemd service name
  serviceName ? "qbittorrent-nox"
, serviceConfig ? { }
  # Custom setup script
, setup ? ""
, # qbittorrent-nox package
  package ? pkgs.qbittorrent-nox
}:

let
  configMerged = config // {
    Preferences = {
      "WebUI\\Port" = toString port;
      "WebUI\\AlternativeUIEnabled" = if customFrontend != null then "true" else "false";
      "WebUI\\RootFolder" = if customFrontend != null then "${dataDir}/frontend" else "";
    } // (config.Preferences or { });
  };

  ini = lib.generators.toINI { } configMerged;
  iniFile = pkgs.writeText "qBittorrent.conf" ini;
in
{
  systemd.services.${serviceName} = {
    description = "qbittorrent-nox Daemon";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      PrivateTmp = true;
      # To prevent "Quit & shutdown daemon" from working; we want systemd to manage it!
      Restart = "on-success";
      User = user;
      Group = group;
      UMask = "0002";
      LimitNOFILE = openFilesLimit;
    } // serviceConfig;

    script = ''
      ${lib.optionalString (customFrontend != null) ''
        set -euxo pipefail

        if [[ -d ${dataDir}/frontend ]]; then
          rm -rf ${dataDir}/frontend
        fi

        mkdir -p ${dataDir}/frontend
        ${pkgs.unzip}/bin/unzip -o ${customFrontend} -d ${dataDir}/frontend

        ${lib.optionalString (customFrontendFolder != null) ''
          mv ${dataDir}/frontend/${customFrontendFolder}/* ${dataDir}/frontend
          rm -rf ${dataDir}/frontend/${customFrontendFolder}
        ''}
      ''}

      mkdir -p ${dataDir}/qBittorrent/config
      cp ${iniFile} ${dataDir}/qBittorrent/config/qBittorrent.conf
      ${setup}
      ${package}/bin/qbittorrent-nox --webui-port=${toString port} --profile=${dataDir}
    '';
  };

  users.users.${user} = {
    isNormalUser = true;
    group = group;
    home = dataDir;
    createHome = true;
    description = "qbittorrent-nox user";
  };

  users.groups.${group} = {
    gid = null;
  };
}
