{
  declare = defs: {
    age.secrets = builtins.listToAttrs (
      map
        (def:
          let obj = if builtins.isString def then { name = def; } else def;
          in {
            name = obj.name;
            value = builtins.removeAttrs
              (obj // {
                file = ../secrets + "/${obj.name}.age";
              }) [ "name" ];
          }
        )
        defs
    );
  };
}
