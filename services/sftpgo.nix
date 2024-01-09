{ lib, abs, pkgs, ... }@inputs:

let
  sqlite = import (abs "lib/sqlite.nix") inputs;

  defaultFilesystem = {
    provider = 0;
    osconfig = { };
    s3config = { };
    gcsconfig = { };
    azblobconfig = { };
    cryptconfig = { };
    sftpconfig = { };
    httpconfig = { };
  };

  insertFolder = name: folder: sqlite.insert {
    into = "folders";
    value = {
      name = name;
      description = folder.description or "";
      path = folder.path;
      used_quota_size = "0";
      used_quota_files = "0";
      last_quota_update = "0";
      filesystem = defaultFilesystem;
    };
  };

  insertUser = username: user: sqlite.insert {
    into = "users";
    orReplace = true;
    value = {
      username = username;
      status = "1";
      expiration_date = "0";
      description = user.description or "";
      password = user.password or "";
      public_keys = builtins.toJSON (user.publicKeys or [ ]);
      home_dir = user.home or "/tmp/${username}";
      uid = "0";
      gid = "0";
      max_sessions = "0";
      quota_size = "0";
      quota_files = "0";
      last_login = "0";
      permissions."/" = [ "*" ];
      used_quota_size = "0";
      used_quota_files = "0";
      last_quota_update = "0";
      upload_bandwidth = "0";
      download_bandwidth = "0";
      filters = {
        hooks = {
          external_auth_disabled = false;
          pre_login_disabled = false;
          check_password_disabled = false;
        };
        totp_config = {
          secret = { };
        };
      };
      filesystem = defaultFilesystem;
      additional_info = "";
      created_at = "0";
      updated_at = "0";
      email = "";
      upload_data_transfer = "0";
      download_data_transfer = "0";
      total_data_transfer = "0";
      used_upload_data_transfer = "0";
      used_download_data_transfer = "0";
      deleted_at = "0";
      first_download = "0";
      first_upload = "0";
      role_id = null;
      last_password_change = "0";
    };
  };

  insertUserFolder = userFolder: sqlite.insert {
    into = "users_folders_mapping";
    orReplace = true;
    value = {
      user_id = sqlite.sql (
        sqlite.select {
          from = "users";
          columns = [ "id" ];
          where.username = userFolder.username;
        }
      );
      folder_id = sqlite.sql (
        sqlite.select {
          from = "folders";
          columns = [ "id" ];
          where.name = userFolder.folder;
        }
      );
      virtual_path = userFolder.path or "/${userFolder.folder}";
      quota_size = -1;
      quota_files = -1;
    };
  };

  insertAdmin = username: admin: sqlite.insert {
    into = "admins";
    value = {
      username = username;
      description = admin.description or "";
      password = admin.password;
      email = admin.email or "";
      status = "1";
      permissions = "[\"*\"]";
      filters = {
        totp_config = { secret = { }; };
        preferences = { };
      };
      additional_info = "";
      last_login = "0";
      created_at = "0";
      updated_at = "0";
      role_id = null;
    };
  };
in
{
  setup =
    {
      # paths to private keys for sftp server
      # all required with default config, but can be omitted if you change the config to not require them
      # { ecdsa?: string, ed25519?: string, rsa?: string }
      keys ? { }
      # https://github.com/drakkan/sftpgo/blob/main/docs/full-configuration.md
    , config ? null
      # username => { 
      #  home?: string, # defaults to /tmp/username
      #  description?: string, 
      #  password?: string,  # argon2 hashed
      #  publicKeys?: string[] 
      #  permisisons?: Record<string, string>, e.g, 
      # }
    , users ? { }
      # name => { description?: string, path: string }
    , folders ? { }
      # username => { 
      #  password: string, # argon2 hashed
      #  description?: string, 
      #  email?: string, 
      # }
    , admins ? {
        # argon2 hash of password "admin"
        admin.password = "$2a$10$7QZqmQNWwfbgIwc5Jskkgea7s8dffkbwPUW30MEShpDpZWxMVrFaa";
      }
      # array of { 
      #  username: string,
      #  folder: string, # name of folder
      #  path?: string # virtual path, e.g. /Folder (defaults to /${folder})
      # }
    , usersFolders ? null
    , package ? pkgs.sftpgo
    , sqlitePackage ? pkgs.sqlite
    , serviceName ? "sftpgo"
    }:
    let
      configFile = if config != null then pkgs.writeText "sftpgo.json" (builtins.toJSON config) else null;

      sqliteStatements = [ ] ++
        lib.optionals (users != null) (lib.attrsets.mapAttrsToList insertUser users) ++
        lib.optionals (folders != null) (lib.attrsets.mapAttrsToList insertFolder folders) ++
        lib.optionals (admins != null) (lib.attrsets.mapAttrsToList insertAdmin admins) ++
        lib.optionals (usersFolders != null) (builtins.map insertUserFolder usersFolders);
      sqliteScript = pkgs.writeText "sftpgo-init.sql" (sqlite.script sqliteStatements);
    in
    {
      systemd.services.${serviceName} = {
        description = "${serviceName} Daemon";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [ package sqlitePackage ];
        serviceConfig.PrivateTmp = true;
        script = ''
          sftpgo initprovider
          sqlite3 sftpgo.db < ${sqliteScript}

          ${lib.optionalString (keys ? ecdsa) "cp ${keys.ecdsa} id_ecdsa"}
          ${lib.optionalString (keys ? ed25519) "cp ${keys.ed25519} id_ed25519"}
          ${lib.optionalString (keys ? rsa) "cp ${keys.rsa} id_rsa"}
          ${lib.optionalString (configFile != null) "cp ${configFile} sftpgo.json"}

          sftpgo serve
        '';
      };
    };
}
