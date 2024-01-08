{ pkgs, batch }:

{
  withStaticIp =
    { ip
    , mask
    , gateway
    , dns
    ,
    }:
    let
      script = batch.compile (batch.runPsScript "setup-static" ''
        $adapter = (Get-NetAdapter -InterfaceDescription "*VirtIO*")[0].Name
        netsh interface ip set address name="$adapter" static ${ip} ${mask} ${gateway}
        netsh interface ip set dns name="$adapter" static ${dns}
      '');
    in
    batch.runOnStartup script;

  withRdpServer = [
    (batch.registry.add {
      key = "HKLM/SYSTEM/CurrentControlSet/Control/Terminal Server";
      value = "fDenyTSConnections";
      type = "REG_DWORD";
      data = "0";
      withMkdir = true;
    })

    "netsh advfirewall firewall set rule group=\"Remote Desktop\" new enable=Yes"
  ];

  # https://git.m-labs.hk/M-Labs/wfvm/src/branch/master/wfvm/install-ssh.ps1
  withSshServer =
    { keys
    ,
    }:
    let
      keys_ = map
        (key:
          if builtins.isPath key then
            builtins.readFile key
          else
            key
        )
        keys;
    in
    [
      (batch.runPsScript "install-ssh" ''
        Expand-Archive ''${env:SCRIPT_DRIVE}:\OpenSSH-Win64.zip C:\
        Push-Location C:\OpenSSH-Win64

        & .\install-sshd.ps1
        .\ssh-keygen.exe -A
        & .\FixHostFilePermissions.ps1 -Confirm:$false
        & .\FixUserFilePermissions.ps1 -Confirm:$false

        Pop-Location

        $newPath = 'C:\OpenSSH-Win64;' + [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
        [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::Machine)

        New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH
        Set-Service sshd -StartupType Automatic
        Set-Service ssh-agent -StartupType Automatic
        sc.exe failure sshd reset= 86400 actions= restart/500

        Start-Service sshd
        Start-Service ssh-agent
      '')

      (batch.writeToFile "%programdata%/ssh/administrators_authorized_keys" (
        builtins.concatStringsSep "\n" keys_
      ))
    ];

  withSmbServer =
    { shares
    ,
    }:
    let
      sharesArr = map
        (name: { name = name; value = shares.${name}; })
        (builtins.attrNames shares);
      makeScriptForShare = { name, value }:
        let
          path = if builtins.isString value then value else value.path;
          grants = if builtins.isString value || !(value ? grants) then { } else value.grants;
          grantsStr = builtins.concatStringsSep " " (map
            (user: "/grant:${user},${grants.${user}}")
            (builtins.attrNames grants)
          );
        in
        [
          (batch.ifNotExists "${path}/" [
            (batch.mkdir path)
          ])
          "net share ${name}=${path} ${grantsStr}"
        ];
      sharesNow = builtins.filter ({ name, value }: !(builtins.isAttrs value) || !(value.onBoot or false)) sharesArr;
      sharesOnBoot = builtins.filter ({ name, value }: builtins.isAttrs value && value.onBoot or false) sharesArr;
    in
    [
      (map makeScriptForShare sharesNow)
      (batch.runOnStartup (batch.compile
        (map makeScriptForShare sharesOnBoot))
      )
    ];
}
