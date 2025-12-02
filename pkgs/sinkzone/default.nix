{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "sinkzone";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "berbyte";
    repo = "sinkzone";
    rev = "v${version}";
    hash = "sha256-CYVaqtTvAGlN6o5gZxGgc+a25x5PlVmQEPYDBF9pehw=";
  };

  vendorHash = "sha256-JZwkL+EFCMP8m5wRVmARrAhfHy2/uAC74/f9PGYR4eg=";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  meta = with lib; {
    description = "DNS-based productivity tool with allowlist-only model";
    homepage = "https://github.com/berbyte/sinkzone";
    license = licenses.mit;
    mainProgram = "sinkzone";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
