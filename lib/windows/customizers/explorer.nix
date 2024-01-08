{ pkgs, batch }:

{
  withFileExtensions =
    batch.registry.add {
      key = "HKCU/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced";
      value = "HideFileExt";
      type = "REG_DWORD";
      data = "0";
    };

  withHiddenFiles =
    batch.registry.add {
      key = "HKCU/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced";
      value = "Hidden";
      type = "REG_DWORD";
      data = "1";
    };

  withOldExplorerMenu =
    batch.registry.add {
      key = "HKCU/Software/Classes/CLSID/{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}/InprocServer32";
      value = null;
      data = "";
    };

  withCompactExplorerView =
    batch.registry.add {
      key = "HKCU/Software/Microsoft/Windows/CurrentVersion/Explorer/Advanced";
      value = "UseCompactMode";
      type = "REG_DWORD";
      data = "1";
    };

  # https://www.howtogeek.com/222057/how-to-remove-the-folders-from-this-pc-on-windows-10/
  withoutFoldersInThisPc = ''
    Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" /f
    Reg.exe delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" /f
    Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}" /f
    Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" /f
    Reg.exe delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}" /f
    Reg.exe delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" /f
    Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}" /f
    Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" /f
    Reg.exe delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}" /f
    Reg.exe delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" /f
    Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}" /f
    Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" /f
    Reg.exe delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}" /f
    Reg.exe delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" /f
    Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}" /f
    Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" /f
    Reg.exe delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}" /f
    Reg.exe delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" /f
    Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}" /f
    Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" /f
    Reg.exe delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}" /f
    Reg.exe delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" /f
  '';

  withCustomUserDirectories =
    { downloads ? null
    , desktop ? null
    , documents ? null
    , pictures ? null
    , music ? null
    , videos ? null
    , custom ? { }
    ,
    }:
    let
      custom_ = custom
        // (if downloads == null then { } else { "{374DE290-123F-4565-9164-39C4925E467B}" = downloads; })
        // (if desktop == null then { } else { "Desktop" = desktop; })
        // (if documents == null then { } else { "Personal" = documents; })
        // (if pictures == null then { } else { "My Pictures" = pictures; })
        // (if music == null then { } else { "My Music" = music; })
        // (if videos == null then { } else { "My Video" = videos; })
      ;
    in
    map
      (key:
      let path = custom_.${key}; in [
        (batch.registry.add {
          key = "HKCU/Software/Microsoft/Windows/CurrentVersion/Explorer/User Shell Folders";
          value = key;
          type = "REG_EXPAND_SZ";
          data = batch.replacePath path;
        })

        (batch.runOnStartup (batch.compile
          (batch.ifNotExists "${path}/" [
            (batch.mkdir path)
          ])
        ))
      ])
      (builtins.attrNames custom_);
}
