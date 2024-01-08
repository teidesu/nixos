{ ... }@inputs:

let
  xml = import ./xml.nix;
in
rec {
  mkConfig = config:
    let
      configs = if builtins.isList config then config else [ config ];
      data = map
        (cfg: {
          service-group =
            [{ name = cfg.name; }] ++
            map (service: { inherit service; }) cfg.services ++
            [ cfg.extra or { } ];
        })
        configs;
    in
    ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      ${xml.generateXMLInner { obj = data; }}
    '';

  setup = services:
    let
      servicesList = if builtins.isList services then services else [ services ];
    in
    {
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
        publish = {
          enable = true;
          userServices = true;
        };

        extraServiceFiles = (builtins.listToAttrs (map
          (service: {
            name = service.name;
            value = mkConfig service;
          })
          servicesList));
      };
    };
}
