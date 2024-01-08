{ pkgs, batch }:

{
  withoutOnedrive = [
    (batch.ifExists "%systemroot%/System32/OneDriveSetup.exe" [
      (batch.run "%systemroot%/System32/OneDriveSetup.exe" [ "/uninstall" ])
    ])
    (batch.ifExists "%systemroot%/SysWOW64/OneDriveSetup.exe" [
      (batch.run "%systemroot%/SysWOW64/OneDriveSetup.exe" [ "/uninstall" ])
    ])

    (batch.rmrf "%localappdata%/Microsoft/OneDrive")
    (batch.rmrf "%programdata%/Microsoft OneDrive")
    (batch.rmrf "%systemdrive%/OneDriveTemp")

    (batch.registry.mkdirIfNotExists
      "HKLM/SOFTWARE/Wow6432Node/Policies/Microsoft/Windows/OneDrive")
    (batch.registry.add {
      key = "HKLM/SOFTWARE/Wow6432Node/Policies/Microsoft/Windows/OneDrive";
      value = "DisableFileSyncNGSC";
      type = "REG_DWORD";
      data = "1";
      withMkdir = true;
    })

    (batch.registry.add {
      key = "HKCR/CLSID/{018D5C66-4533-4307-9B53-224DE2ED1FE6}";
      value = "System.IsPinnedToNameSpaceTree";
      type = "REG_DWORD";
      data = "0";
      withMkdir = true;
    })
    (batch.registry.add {
      key = "HKCR/Wow6432Node/CLSID/{018D5C66-4533-4307-9B53-224DE2ED1FE6}";
      value = "System.IsPinnedToNameSpaceTree";
      type = "REG_DWORD";
      data = "0";
      withMkdir = true;
    })

    (batch.registry.withLoad "hku/Default" "C:/Users/Default/NTUSER.DAT" [
      (batch.registry.delete {
        key = "HKU/DEFAULT/SOFTWARE/Microsoft/Windows/CurrentVersion/Run";
        value = "OneDriveSetup";
      })
    ])

    (batch.rmFile "%userprofile%/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/OneDrive.lnk")
    (batch.scheduler.findAndUnschedule "OneDrive*")
  ];

  # https://github.com/W4RH4WK/Debloat-Windows-10/blob/master/scripts/remove-default-apps.ps1
  withoutBloatApps = { keep ? [ ] }:
    let
      apps = [
        # default Windows 10 apps
        "Microsoft.3DBuilder"
        "Microsoft.Appconnector"
        "Microsoft.BingFinance"
        "Microsoft.BingNews"
        "Microsoft.BingSports"
        "Microsoft.BingTranslator"
        "Microsoft.BingWeather"
        "Microsoft.FreshPaint"
        "Microsoft.GamingServices"
        "Microsoft.MicrosoftOfficeHub"
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.MicrosoftStickyNotes"
        "Microsoft.MinecraftUWP"
        "Microsoft.NetworkSpeedTest"
        "Microsoft.Office.OneNote"
        "Microsoft.People"
        "Microsoft.Print3D"
        "Microsoft.SkypeApp"
        "Microsoft.Wallet"
        "Microsoft.WindowsAlarms"
        "Microsoft.WindowsCamera"
        "Microsoft.WindowsMaps"
        "Microsoft.WindowsPhone"
        "Microsoft.WindowsSoundRecorder"
        "Microsoft.Xbox.TCUI"
        "Microsoft.XboxApp"
        "Microsoft.XboxGameOverlay"
        "Microsoft.XboxSpeechToTextOverlay"
        "Microsoft.YourPhone"
        "Microsoft.ZuneMusic"
        "Microsoft.ZuneVideo"

        "Microsoft.CommsPhone"
        "Microsoft.ConnectivityStore"
        "Microsoft.GetHelp"
        "Microsoft.Getstarted"
        "Microsoft.Messaging"
        "Microsoft.Office.Sway"
        "Microsoft.OneConnect"
        "Microsoft.WindowsFeedbackHub"

        "Microsoft.Microsoft3DViewer"
        "Microsoft.MSPaint"

        "Microsoft.BingFoodAndDrink"
        "Microsoft.BingHealthAndFitness"
        "Microsoft.BingTravel"
        "Microsoft.WindowsReadingList"

        "Microsoft.MixedReality.Portal"
        "Microsoft.ScreenSketch"
        "Microsoft.XboxGamingOverlay"

        "2FE3CB00.PicsArt-PhotoStudio"
        "46928bounde.EclipseManager"
        "4DF9E0F8.Netflix"
        "613EBCEA.PolarrPhotoEditorAcademicEdition"
        "6Wunderkinder.Wunderlist"
        "7EE7776C.LinkedInforWindows"
        "89006A2E.AutodeskSketchBook"
        "9E2F88E3.Twitter"
        "A278AB0D.DisneyMagicKingdoms"
        "A278AB0D.MarchofEmpires"
        "ActiproSoftwareLLC.562882FEEB491" # next one is for the Code Writer from Actipro Software LLC
        "CAF9E577.Plex"
        "ClearChannelRadioDigital.iHeartRadio"
        "D52A8D61.FarmVille2CountryEscape"
        "D5EA27B7.Duolingo-LearnLanguagesforFree"
        "DB6EA5DB.CyberLinkMediaSuiteEssentials"
        "DolbyLaboratories.DolbyAccess"
        "DolbyLaboratories.DolbyAccess"
        "Drawboard.DrawboardPDF"
        "Facebook.Facebook"
        "Fitbit.FitbitCoach"
        "Flipboard.Flipboard"
        "GAMELOFTSA.Asphalt8Airborne"
        "KeeperSecurityInc.Keeper"
        "NORDCURRENT.COOKINGFEVER"
        "PandoraMediaInc.29680B314EFC2"
        "Playtika.CaesarsSlotsFreeCasino"
        "ShazamEntertainmentLtd.Shazam"
        "SlingTVLLC.SlingTV"
        "SpotifyAB.SpotifyMusic"
        "TheNewYorkTimes.NYTCrossword"
        "ThumbmunkeysLtd.PhototasticCollage"
        "TuneIn.TuneInRadio"
        "WinZipComputing.WinZipUniversal"
        "XINGAG.XING"
        "flaregamesGmbH.RoyalRevolt2"
        "king.com.*"
        "king.com.BubbleWitch3Saga"
        "king.com.CandyCrushSaga"
        "king.com.CandyCrushSodaSaga"
        "A025C540.Yandex.Music"
        "Clipchamp.Clipchamp"
        "Microsoft.Todos"
      ];
      cdm = [
        "ContentDeliveryAllowed"
        "FeatureManagementEnabled"
        "OemPreInstalledAppsEnabled"
        "PreInstalledAppsEnabled"
        "PreInstalledAppsEverEnabled"
        "SilentInstalledAppsEnabled"
        "SubscribedContent-314559Enabled"
        "SubscribedContent-338387Enabled"
        "SubscribedContent-338388Enabled"
        "SubscribedContent-338389Enabled"
        "SubscribedContent-338393Enabled"
        "SubscribedContentEnabled"
        "SystemPaneSuggestionsEnabled"
      ];
      toDelete = builtins.filter (it: !(builtins.elem it keep)) apps;
    in
    [
      (batch.runPsScript "uninstall-apps" ''
        $apps = @(
          ${
            builtins.concatStringsSep "\n    "
              (builtins.map (it: "\"${it}\"") toDelete)
          }
        );

        $appxprovisionedpackage = Get-AppxProvisionedPackage -Online

        foreach ($app in $apps) {
            Write-Output "Trying to remove $app"

            Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers

            ($appxprovisionedpackage).Where( {$_.DisplayName -EQ $app}) |
                Remove-AppxProvisionedPackage -Online
        }
      '')

      (map
        (it: batch.registry.add {
          key = "HKCU/Software/Microsoft/Windows/CurrentVersion/ContentDeliveryManager";
          value = it;
          type = "REG_DWORD";
          data = "0";
          withMkdir = true;
        })
        cdm
      )

      (batch.registry.add {
        key = "HKLM/SOFTWARE/Policies/Microsoft/WindowsStore";
        value = "AutoDownload";
        type = "REG_DWORD";
        data = "2";
        withMkdir = true;
      })

      # Prevents "Suggested Applications" returning
      (batch.registry.add {
        key = "HKLM/SOFTWARE/Policies/Microsoft/Windows/CloudContent";
        value = "DisableWindowsConsumerFeatures";
        type = "REG_DWORD";
        data = "1";
        withMkdir = true;
      })
      (batch.registry.add {
        key = "HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/SearchSettings";
        value = "IsDynamicSearchBoxEnabled";
        type = "REG_DWORD";
        data = "0";
        withMkdir = true;
      })
    ];

  withoutTelemetry = [
    (batch.registry.add {
      key = "HKLM/SOFTWARE/Policies/Microsoft/Windows/DataCollection";
      value = "AllowTelemetry";
      type = "REG_DWORD";
      data = "0";
      withMkdir = true;
    })
  ];

  withoutDefender = [
    (batch.registry.add {
      key = "HKLM/SOFTWARE/Policies/Microsoft/Windows Defender";
      value = "DisableAntiSpyware";
      type = "REG_DWORD";
      data = "1";
      withMkdir = true;
    })
    (batch.registry.add {
      key = "HKLM/SOFTWARE/Policies/Microsoft/Windows Defender";
      value = "DisableRoutinelyTakingAction";
      type = "REG_DWORD";
      data = "1";
    })
    (batch.registry.add {
      key = "HKLM/SOFTWARE/Policies/Microsoft/Windows Defender/Real-Time Protection";
      value = "DisableRealtimeMonitoring";
      type = "REG_DWORD";
      data = "1";
      withMkdir = true;
    })
    (batch.registry.add {
      key = "HKLM/SOFTWARE/Policies/Microsoft/Windows Defender/Real-Time Protection";
      value = "DisableIOAVProtection";
      type = "REG_DWORD";
      data = "1";
      withMkdir = true;
    })

    # Removing Windows Defender GUI / tray from autorun
    (batch.registry.delete {
      key = "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run";
      value = "WindowsDefender";
    })

    # disable SmartScreen
    (batch.registry.add {
      key = "HKEY_LOCAL_MACHINE/SOFTWARE/Policies/Microsoft/Windows/System";
      value = "EnableSmartScreen";
      type = "REG_DWORD";
      data = "0";
    })
    (batch.registry.add {
      key = "HKEY_LOCAL_MACHINE/Software/Policies/Microsoft/MicrosoftEdge/PhishingFilter";
      value = "EnabledV9";
      type = "REG_DWORD";
      data = "0";
    })
  ];

  withoutTaskbarItems =
    { widgets ? true
    , taskView ? true
    , chat ? true
    , search ? true
    , alignLeft ? true
    ,
    }: [
      (batch.maybe widgets (batch.registry.add {
        key = "HKCU/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced";
        value = "TaskbarDa";
        type = "REG_DWORD";
        data = "0";
        withMkdir = true;
      }))

      (batch.maybe taskView (batch.registry.add {
        key = "HKCU/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced";
        value = "ShowTaskViewButton";
        type = "REG_DWORD";
        data = "0";
        withMkdir = true;
      }))

      (batch.maybe chat (batch.registry.add {
        key = "HKCU/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced";
        value = "TaskbarMn";
        type = "REG_DWORD";
        data = "0";
        withMkdir = true;
      }))

      (batch.maybe search (batch.registry.add {
        key = "HKCU/Software/Microsoft/Windows/CurrentVersion/Search";
        value = "SearchboxTaskbarMode";
        type = "REG_DWORD";
        data = "0";
        withMkdir = true;
      }))

      (batch.maybe alignLeft (batch.registry.add {
        key = "HKCU/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced";
        value = "TaskbarAl";
        type = "REG_DWORD";
        data = "0";
        withMkdir = true;
      }))
    ];
}
