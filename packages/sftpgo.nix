# based on https://github.com/NixOS/nixpkgs/blob/63c4175cb0fb03cab301d7ba058e4937bec464e2/pkgs/servers/sftpgo/default.nix
# modified to support bundled usage of static files

{ lib
, buildGoModule
, fetchFromGitHub
, installShellFiles
, nixosTests
, tags ? []
}:

buildGoModule rec {
  pname = "sftpgo";
  version = "2.5.6";

  src = fetchFromGitHub {
    owner = "drakkan";
    repo = "sftpgo";
    rev = "refs/tags/v${version}";
    hash = "sha256-ea4DbPwi2tcRgmbNsZKKUOVkp6vjRbr679yAP7znNUc=";
  };

  vendorHash = "sha256-8TBDaDBLy+82BwsaLncDknVIrauF0eop9e2ZhwcLmIs=";

  inherit tags;
  ldflags = [
    "-s"
    "-w"
    "-X github.com/drakkan/sftpgo/v2/internal/version.commit=${src.rev}"
    "-X github.com/drakkan/sftpgo/v2/internal/version.date=1970-01-01T00:00:00Z"
  ];

  nativeBuildInputs = [ installShellFiles ];

  doCheck = false;

  subPackages = [ "." ];

  preBuild = if builtins.any (x: x == "bundle") tags then ''
    cp -rf openapi internal/bundle/openapi
    cp -rf static internal/bundle/static
    cp -rf templates internal/bundle/templates
  '' else null;

  postInstall = ''
    $out/bin/sftpgo gen man
    installManPage man/*.1

    installShellCompletion --cmd sftpgo \
      --bash <($out/bin/sftpgo gen completion bash) \
      --zsh <($out/bin/sftpgo gen completion zsh) \
      --fish <($out/bin/sftpgo gen completion fish)

    shareDirectory="$out/share/sftpgo"
    mkdir -p "$shareDirectory"
    cp -r ./{openapi,static,templates} "$shareDirectory"
  '';

  passthru.tests = nixosTests.sftpgo;
}