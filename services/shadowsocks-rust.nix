# Based on https://github.com/NixOS/nixpkgs/blob/nixos-23.05/nixos/modules/services/networking/shadowsocks.nix

{ lib, pkgs, ... }:

with lib;
{
  # Local addresses to which the server binds.
  localAddress ? "0.0.0.0"
, # Port which the server uses.
  # If `client = true`, port of the remote server to connect to.
  port ? 8388
, # Password for connecting clients
  password ? null
, # Password file with a password for connecting clients
  passwordFile ? null
, # Relay protocols (one of "tcp_only" "tcp_and_udp" "udp_only")
  mode ? "tcp_and_udp"
, # use TCP fast-open
  fastOpen ? true
, # Encryption method
  encryptionMethod ? "chacha20-ietf-poly1305"
, # SIP003 plugin for shadowsocks
  plugin ? null
, # Options to pass to the plugin if one was specified (e.g. "server;host=example.com")
  pluginOpts ? ""
, # Whether to set up a Shadowsocks client instead of a server
  client ? false
, # Address of the remote Shadowsocks server
  server ? null
, # File containing address of the remote Shadowsocks server
  serverFile ? null
, # Local port for the client to bind
  localPort ? 8388
, # Additional configuration for shadowsocks that is not covered by the
  # provided options. The provided attrset will be serialized to JSON config as-is
  extraConfig ? { }
, # Name of the systemd service
  serviceName ? "shadowsocks-rust"
, # Shadowsocks-rust package
  package ? pkgs.shadowsocks-rust
}:
assert assertOneOf "mode" mode [ "tcp_only" "tcp_and_udp" "udp_only" ];
assert assertMsg (password == null || passwordFile == null) "Cannot use both password and passwordFile for shadowsocks-rust";
assert assertMsg (server == null || serverFile == null) "Cannot use both server and serverFile for shadowsocks-rust";

let
  opts = {
    server = localAddress;
    server_port = port;
    method = encryptionMethod;
    mode = mode;
    user = "nobody";
    fast_open = fastOpen;
  } // optionalAttrs (plugin != null) {
    plugin = plugin;
    plugin_opts = pluginOpts;
  } // optionalAttrs (password != null) {
    password = password;
  } // optionalAttrs (client == true) {
    server = server;
    local_address = localAddress;
    local_port = localPort;
  } // extraConfig;

  configFile = pkgs.writeText "shadowsocks.json" (builtins.toJSON opts);
in
{
  systemd.services.${serviceName} = {
    description = "${serviceName} Daemon";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ package ] ++ optional (plugin != null) plugin ++ optional (passwordFile != null) pkgs.jq;
    serviceConfig.PrivateTmp = true;
    script = ''
      cp ${configFile} /tmp/shadowsocks.json
      ${optionalString (passwordFile != null) ''
        cat /tmp/shadowsocks.json | jq --arg password "$(cat "${passwordFile}")" '. + { password: $password }' > /tmp/shadowsocks.json
      ''}
      ${optionalString (serverFile != null) ''
        cat /tmp/shadowsocks.json | jq --arg server "$(cat "${serverFile}")" '. + { server: $server }' > /tmp/shadowsocks.json
      ''}
      exec ${if client == true then "sslocal" else "ssserver"} -c /tmp/shadowsocks.json
    '';
  };
}
