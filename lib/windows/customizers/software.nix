{ pkgs, batch }:

with batch;

{
  edge = {
    setUserDataDirectory = path:
      registry.add {
        key = "HKEY_LOCAL_MACHINE/Software/Policies/Microsoft/Edge";
        value = "UserDataDir";
        type = "REG_SZ";
        data = path;
      };
  };

  _7zip = {
    package = {
      name = "7zip.exe";
      path = pkgs.fetchurl {
        url = "https://www.7-zip.org/a/7z2301-x64.exe";
        hash = "sha256-Jstun1YzNoISL6/nnbzf1R6fR8xyF9zNKaxvwztVmM0=";
      };
    };
    install =
      { assoc ? [
          "001"
          "7z"
          "arj"
          "bz2"
          "bzip2"
          "cab"
          "cpio"
          "deb"
          "dmg"
          "gz"
          "gzip"
          "hfs"
          "iso"
          "lha"
          "lzh"
          "lzma"
          "rar"
          "rpm"
          "split"
          "swm"
          "tar"
          "taz"
          "tbz"
          "tbz2"
          "tgz"
          "tpz"
          "wim"
          "xar"
          "z"
          "zip"
        ]
      ,
      }: [
        ''
          %SCRIPT_DRIVE%:\7zip.exe /S /D="C:\Program Files\7-Zip"
          for /d %%A in (${builtins.concatStringsSep "," assoc}) do (
            assoc .%%A=7-Zip.%%A
            ftype 7-Zip.%%A="C:\Program Files\7-Zip\7zFM.exe" "%%1"
          )
        ''

        (map
          (ext: ''
            Reg.exe add "HKCR\.${ext}" /ve /t REG_SZ /d "7-Zip.${ext}" /f
            Reg.exe add "HKCR\7-Zip.${ext}" /ve /t REG_SZ /d "${ext} Archive" /f
            Reg.exe add "HKCR\7-Zip.${ext}\shell" /ve /t REG_SZ /d "" /f
            Reg.exe add "HKCR\7-Zip.${ext}\shell\open" /ve /t REG_SZ /d "" /f
            Reg.exe add "HKCR\7-Zip.${ext}\shell\open\command" /ve /t REG_SZ /d "\"C:\Program Files\7-Zip\7zFM.exe\" \"%%1\"" /f
          '')
          assoc
        )
      ];
  };

  python3_11_5 = {
    package = {
      name = "python-3.11.5-amd64.exe";
      path = pkgs.fetchurl {
        url = "https://www.python.org/ftp/python/3.11.5/python-3.11.5-amd64.exe";
        hash = "sha256-G7RvZbtvcbKVgByP9Za7W2n6TAZFVB2189O6wzqm6t4=";
      };
    };
    install = params:
      let
        paramsString = builtins.concatStringsSep " " (map
          (name: "${name}=\"${params[name]}\"")
          (builtins.attrNames params)
        );
      in
      "%SCRIPT_DRIVE%:\\python-3.11.5-amd64.exe /passive ${paramsString}";
  };

  vcredist = {
    package = {
      name = "vcredist-aio.zip";
      path = pkgs.fetchurl {
        url = "https://dl.comss.org/download/Visual-C-Runtimes-All-in-One-May-2023.zip";
        hash = "sha256-MF1wC45lJhSfMYZMcFKTBElFhK4dK2jScbG/7Js1He8=";
      };
    };
    install = runPsScript "vcredist" ''
      Expand-Archive ''${env:SCRIPT_DRIVE}:\vcredist-aio.zip ''${env:TEMP}\vcredist-aio\
      
      Push-Location ''${env:TEMP}\vcredist-aio\
      .\install_all.bat
      Pop-Location
      
      rm -r ''${env:TEMP}\vcredist-aio\
    '';
  };

  nomachine = {
    package = {
      name = "nomachine.exe";
      path = pkgs.fetchurl {
        url = "https://download.nomachine.com/download/8.8/Windows/nomachine_8.8.1_1_x64.exe";
        hash = "sha256-zb4egeW+XvRP1L2q3paDB6+u8/H/LAe62sKJUgFA4r8=";
      };
    };
    install = ''
      %SCRIPT_DRIVE%:\nomachine.exe /silent
    '';
  };
}
