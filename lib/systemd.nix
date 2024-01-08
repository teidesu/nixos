{ ... }@inputs:

{
  mkOneshot = { name, script, extra ? {} }: {
    systemd.services.${name} = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = script;
      } // (extra.serviceConfig or {});
    } // (builtins.removeAttrs extra [ "serviceConfig" ]);
  };
}
