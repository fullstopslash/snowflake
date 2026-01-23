{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "grafatui";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "fedexist";
    repo = "grafatui";
    rev = "v${version}";
    hash = "sha256-V+8Y8SOSNbQISjOtdtkoMWyqjQB1M2tLIrJ8GgPLfzU=";
  };

  cargoHash = "sha256-g60PCdCBUqEdGbk00zH1yYkaVDD1/djO+wwkYxtFxhQ=";

  nativeBuildInputs = [pkg-config];
  buildInputs = [openssl];

  meta = with lib; {
    description = "A TUI for exploring Grafana Loki or Prometheus datasources";
    homepage = "https://github.com/fedexist/grafatui";
    license = licenses.mit;
    mainProgram = "grafatui";
    platforms = platforms.linux;
  };
}
