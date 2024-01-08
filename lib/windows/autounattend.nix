{ pkgs, abs, ... }:

let
  xml = import (abs "lib/xml.nix");
in
rec {
  mkSettings = pass: value: {
    settings = {
      _attrs = {
        pass = pass;
      };

      _value = value;
    };
  };

  mkComponent = arch: name: value: {
    component = {
      _attrs = {
        name = name;
        processorArchitecture = arch;
        publicKeyToken = "31bf3856ad364e35";
        language = "neutral";
        versionScope = "nonSxS";
      };

      _value = value;
    };
  };

  mkCommands' = name: commands: pkgs.lib.imap1
    (i: command: {
      ${name} = {
        _attrs = { "wcm:action" = "add"; };

        Order = i;
        Path = command;
      };
    })
    commands;

  mkRunSynchronous = commands: pkgs.lib.imap1
    (i: command: {
      RunSynchronousCommand = {
        _attrs = { "wcm:action" = "add"; };

        Order = i;
        Path = command;
      };
    })
    commands;
  mkSynchronousCommand = commands: pkgs.lib.imap1
    (i: command: {
      SynchronousCommand = {
        _attrs = { "wcm:action" = "add"; };

        Order = i;
        CommandLine = command;
      };
    })
    commands;

  mkUsers = group: groupDef: map
    (name: {
      LocalAccount = {
        _attrs = { "wcm:action" = "add"; };

        Password = {
          Value = groupDef.${name};
          PlainText = "true";
        };
        Group = group;
        Name = name;
      };
    })
    (builtins.attrNames groupDef);

  mkCreatePartition = { order, type, size ? null }: {
    CreatePartition = {
      _attrs = { "wcm:action" = "add"; };
      Order = order;
      Type = type;
    } // (if size != null then { Size = size; } else { Extend = "true"; });
  };

  mkModifyPartition = { order, format ? null, label ? null, letter ? null }: {
    ModifyPartition = {
      _attrs = { "wcm:action" = "add"; };
      Order = order;
      PartitionID = order;
    } // (if format != null then { Format = format; } else { })
    // (if label != null then { Label = label; } else { })
    // (if letter != null then { Letter = letter; } else { });
  };

  mkAutoUnattend =
    { edition ? "Windows 11 Pro"
    , efi ? true
    , locale ? "en-US"
    , arch ? "amd64"
    , keyboardLayout ? "0409:00000409"
    , # default configuration has 2 additional disks (0: installer usb, 1: bootstrap usb)
      installToDisk ? 2
    , installToPartition ? 3
    , partitions ? null
    , productKey ? "VK7JG-NPHTM-C97JM-9MPGT-3V66T"
    , # Windows 10/11 Pro

      beforeInstallCommands ? [ ]
    , afterInstallCommands ? [ ]
    , beforeFirstLoginCommands ? null
    , users ? {
        "User" = "password";
      }
    , administators ? {
        "Administrator" = "password";
      }
    , autoLogon ? (builtins.head (builtins.attrNames administators))
    , computerName ? null
    , driverPaths ? null
    ,
    }:
    let
      partitions_ =
        if partitions != null then partitions else {
          create = [
            (mkCreatePartition { order = 1; type = if efi then "EFI" else "Primary"; size = 300; })
            (mkCreatePartition { order = 2; type = if efi then "MSR" else "Primary"; size = 16; })
            (mkCreatePartition { order = 3; type = "Primary"; })
          ];
          modify = [
            (mkModifyPartition { order = 1; format = if efi then "FAT32" else "NTFS"; label = "EFI"; })
            (mkModifyPartition { order = 2; })
            (mkModifyPartition { order = 3; format = "NTFS"; label = "Windows"; letter = "C"; })
          ];
        };
    in
    xml.generateXML {
      unattend = {
        _attrs = {
          xmlns = "urn:schemas-microsoft-com:unattend";
          "xmlns:wcm" = "http://schemas.microsoft.com/WMIConfig/2002/State";
        };

        _value = [
          (mkSettings "windowsPE" [
            (if driverPaths == null then { } else
            (mkComponent arch "Microsoft-Windows-PnpCustomizationsWinPE" {
              DriverPaths =
                pkgs.lib.imap1
                  (i: path: {
                    PathAndCredentials = {
                      _attrs = {
                        "wcm:action" = "add";
                        "wcm:keyValue" = i;
                      };

                      Path = path;
                    };
                  })
                  driverPaths;
            })
            )

            (mkComponent arch "Microsoft-Windows-International-Core-WinPE" {
              SetupUILanguage = {
                UILanguage = locale;
              };
              InputLocale = keyboardLayout;
              SystemLocale = locale;
              UILanguage = locale;
              UserLocale = locale;
            })

            (mkComponent arch "Microsoft-Windows-Setup" {
              DiskConfiguration = {
                Disk = {
                  _attrs = { "wcm:action" = "add"; };

                  CreatePartitions = partitions_.create;
                  ModifyPartitions = partitions_.modify;
                  WillWipeDisk = "true";
                  DiskID = installToDisk;
                };
              };

              ImageInstall = {
                OSImage = {
                  InstallTo = {
                    DiskID = installToDisk;
                    PartitionID = installToPartition;
                  };

                  InstallFrom = {
                    Path = "\\install.swm";
                    MetaData = {
                      _attrs = { "wcm:action" = "add"; };
                      Key = "/IMAGE/NAME";
                      Value = edition;
                    };
                  };
                };
              };

              UserData = {
                AcceptEula = "true";
                ProductKey = {
                  Key = productKey;
                };
              };

              Diagnostics = {
                OptIn = "false";
              };

              DynamicUpdate = {
                Enable = "false";
                WillShowUI = "OnError";
              };

              RunSynchronous = mkRunSynchronous beforeInstallCommands;
            })
          ])

          (mkSettings "offlineServicing" [ ])

          (mkSettings "oobeSystem" [
            (mkComponent arch "Microsoft-Windows-International-Core" {
              InputLocale = keyboardLayout;
              SystemLocale = locale;
              UILanguage = locale;
              UserLocale = locale;
            })

            (mkComponent arch "Microsoft-Windows-Shell-Setup" ({
              UserAccounts = {
                LocalAccounts =
                  (mkUsers "Users" users) ++
                    (mkUsers "Administrators" administators);
              };

              OOBE = {
                ProtectYourPC = "3";
                SkipMachineOOBE = "true";
                SkipUserOOBE = "true";
                HideEULAPage = "true";
                HideLocalAccountScreen = "true";
                HideOnlineAccountScreens = "true";
                HideWirelessSetupInOOBE = "true";
                NetworkLocation = "Home";
              };
            } // (if autoLogon == null then { } else {
              AutoLogon = {
                Enabled = "true";
                Password = {
                  Value = (users.${autoLogon} or administators.${autoLogon});
                  PlainText = "true";
                };
                Username = autoLogon;
              };
            }) // (if beforeFirstLoginCommands == null then { } else {
              FirstLogonCommands = mkSynchronousCommand beforeFirstLoginCommands;
            }) // (if computerName == null then { } else {
              ComputerName = computerName;
            })))
          ])

          (mkSettings "generalize" [ ])

          (mkSettings "specialize" [
            (mkComponent arch "Microsoft-Windows-Deployment" {
              RunSynchronous = mkRunSynchronous afterInstallCommands;
            })

            (mkComponent arch "Microsoft-Windows-Security-SPP-UX" {
              SkipAutoActivation = "true";
            })

            (mkComponent arch "Microsoft-Windows-SQMApi" {
              CEIPEnabled = 0;
            })
          ])

          (mkSettings "auditSystem" [ ])
          (mkSettings "auditUser" [ ])
        ];
      };
    };
}
