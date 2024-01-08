{ abs, pkgs, ... }@inputs:

let
  windows = import (abs "lib/windows") inputs;
in
with windows; {
  systemd.services.windows = makeSystemdService {
    systemImage = makeBaseImage {
      name = "kyoko";
      windowsIso = /etc/iso/win11.iso;
      unattendedParams = {
        users = { };
        administators = {
          "teidesu" = "0";
        };
      };
      preLoginScript = with custom; compile [
        (system.withHostname "KYOKO")
        (system.withKmsActivation {
          # todo change with personal vlmcsd instance
          kmsServer = "kms.digiboy.ir";
        })
        (system.withLongPaths)

        (debloat.withoutOnedrive)
        (debloat.withoutBloatApps { })
        (debloat.withoutTelemetry)
        (debloat.withoutDefender)
        (debloat.withoutTaskbarItems { })

        (network.withStaticIp {
          ip = "10.42.0.4";
          mask = "255.255.0.0";
          gateway = "10.42.0.1";
          dns = "10.42.0.1";
        })
        (network.withRdpServer)
        (network.withSshServer {
          keys = [
            (abs "ssh/teidesu.pub")
          ];
        })
        (network.withSmbServer {
          shares = {
            "Ephemeral" = {
              path = "C:/Shared";
              grants = {
                "Everyone" = "Full";
              };
            };
            "Persistent" = {
              path = "D:/Shared";
              grants = {
                "Everyone" = "Full";
              };
              onBoot = true;
            };
          };
        })

        (explorer.withFileExtensions)
        (explorer.withHiddenFiles)
        (explorer.withOldExplorerMenu)
        (explorer.withCompactExplorerView)
        (explorer.withoutFoldersInThisPc)
        (explorer.withCustomUserDirectories {
          desktop = "D:/Desktop";
          documents = "D:/Documents";
          downloads = "D:/Downloads";
          pictures = "D:/Pictures";
          music = "D:/Music";
          videos = "D:/Videos";
        })

        (software.edge.setUserDataDirectory ''D:/EdgeData/''${user_name}'')
        (software._7zip.install { })
        (software.python3_11_5.install { })
        (software.vcredist.install)
        (software.nomachine.install)
      ];
      additionalFiles = with custom; [
        utils.openSshServerPackage
        software._7zip.package
        software.python3_11_5.package
        software.vcredist.package
        software.nomachine.package
      ];
    };
    name = "kyoko";
    userImageSize = "100G";
    qemuOptions = {
      macAddress = "00:16:D0:3B:E2:DC";
      extraFlags = [
        "-usbdevice tablet"
      ];
    };
  };
}
