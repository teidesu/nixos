{ pkgs, batch }:

{
  withLongPaths = [
    (batch.registry.add {
      key = "HKLM/SYSTEM/CurrentControlSet/Control/FileSystem";
      value = "LongPathsEnabled";
      type = "REG_DWORD";
      data = "1";
    })
  ];

  withKmsActivation =
    { kmsServer
    , productKey ? null
    }: (if productKey == null then [ ] else [
      "cscript C:\\Windows\\System32\\slmgr.vbs /ipk ${productKey}"
    ]) ++ [
      "cscript C:\\Windows\\System32\\slmgr.vbs /skms ${kmsServer}"
      "cscript C:\\Windows\\System32\\slmgr.vbs /ato"
    ];

  withHostname = hostname:
    (batch.runPs "Rename-Computer -NewName ${batch.escape hostname}");

  withoutSleep = [
    "powercfg /hibernate off"
    "powercfg /x -hibernate-timeout-ac 0"
    "powercfg /x -hibernate-timeout-dc 0"
    "powercfg /x -disk-timeout-ac 0"
    "powercfg /x -disk-timeout-dc 0"
    "powercfg /x -monitor-timeout-ac 0"
    "powercfg /x -monitor-timeout-dc 0"
    "powercfg /x -standby-timeout-ac 0"
    "powercfg /x -standby-timeout-dc 0"
  ];
}
