{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
,
}:
let
  trimWhitespaces = str: if str == "" then "" else
  builtins.head (builtins.match "^[[:space:]]*(.*[^[:space:]])?[[:space:]]*$" str);
in
rec {
  compile = lines:
    builtins.concatStringsSep "\n"
      (builtins.filter
        (x: x != null)
        (pkgs.lib.lists.flatten lines)
      );

  maybe = condition: then_: if condition then then_ else null;

  escape = str: "\"" + builtins.replaceStrings [ "\"" ] [ "\\\"" ] str + "\"";
  escapeDouble = str: "\"" + builtins.replaceStrings [ "\"" ] [ "\"\"" ] str + "\"";
  escapeCaret = str: builtins.replaceStrings
    [ "%" "^" "&" "<" ">" "|" "'" "`" "," ";" "=" "(" ")" "!" " " "\"" ]
    [ "%%" "^^" "^&" "^<" "^>" "^|" "^'" "^`" "^," "^;" "^=" "^(" "^)" "^!" "^ " "^\"" ]
    str;
  escapeCaretPiped = str: builtins.replaceStrings
    [ "^|" ] [ "^^^|" ]
    (escapeCaret str);
  replacePath = path: builtins.replaceStrings [ "/" ] [ "\\" ] path;
  escapePath = path: escape (replacePath path);

  writeToFile = path: content:
    let
      lines = builtins.filter builtins.isString (builtins.split "\n" content);
    in
    map
      (
        line:
        if (trimWhitespaces line) == "" then "echo. >> ${path}"
        else "echo ${escapeCaret line} >> ${path}"
      )
      lines;

  run = bin: args: "${escapePath bin} ${builtins.concatStringsSep " " (map escape args)}";
  runPs = command: "echo ${escapeCaretPiped command} | powershell -noprofile -noninteractive -";
  runPsScript = name: script:
    let
      outFile = "%temp%/${name}.ps1";
    in
    [
      (writeToFile outFile script)
      "powershell.exe -noprofile -executionpolicy bypass -file ${outFile}"
      (rmFile outFile)
    ];

  runOnStartup = script:
    let
      scriptFile = "c:/startup.bat";
    in
    [
      (ifNotExists scriptFile [
        "echo @echo off > ${scriptFile}"
        "echo rem !! This script was auto-generated with nix, don't edit >> ${scriptFile}"
        (scheduler.scheduleOnStart {
          name = "System setup";
          command = scriptFile;
        })
      ])
      (writeToFile scriptFile script)
    ];

  registry = {
    add =
      { key
      , value ? null
      , type ? "REG_SZ"
      , separator ? null
      , data ? null
      , withMkdir ? false
      ,
      }:
      let
        result = "reg add ${escapePath key} " +
          (if value == null then "/ve" else "/v ${escape value}") +
          (lib.optionalString (value != null) " /t ${escape type}") +
          (lib.optionalString (separator != null) " /s ${escape separator}") +
          (lib.optionalString (data != null) " /d ${escape data}") + " /f";
      in
      if withMkdir then
        registry.mkdirIfNotExists key + "\n" + result
      else
        result;

    delete =
      { key
      , value ? null
      ,
      }: "reg delete ${escapePath key} " +
        (if value == null then "/ve" else "/v ${escape value}") + " /f";

    mkdir = path: "reg add ${escapePath path} /ve /f";
    mkdirIfNotExists = path:
      let
        _path = escapePath path;
      in
      ''
        reg query ${_path} > $null 2>&1 || (
          ${registry.mkdir path}
        )
      '';

    load = target: path: "reg load ${escapePath target} ${escapePath path}";
    unload = path: "reg unload ${escapePath path}";
    withLoad = path: target: then_: ''
      ${registry.load path target}
      ${compile then_}
      ${registry.unload path}
    '';
  };

  scheduler = {
    findAndUnschedule = name: runPs "Get-ScheduledTask -TaskPath '\\' -TaskName ${escape name} | Unregister-ScheduledTask -Confirm:$false";
    scheduleOnStart = { name, command, user ? "SYSTEM" }:
      "schtasks /create /tn ${escape name} /tr ${escape command} /sc onstart /ru ${escape user}";
  };

  rmFile = path: "del /f ${escapePath path}";
  rmrf = path: "rmdir /s /q ${escapePath path}";

  ifExists = path: then_: ''
    if exist ${escapePath path} (
      ${compile then_}
    )
  '';

  ifNotExists = path: then_: ''
    if not exist ${escapePath path} (
      ${compile then_}
    )
  '';
  mkdir = path: "mkdir ${escapePath path}";
}
