{ config, lib, pkgs, ... }:

let
  scriptsPackage = pkgs.stdenv.mkDerivation {
    pname = "nix-terminal-scripts";
    version = "1.0.0";
    src = ../../scripts/shell;
    dontBuild = true;

    installPhase = ''
      set -euo pipefail
      mkdir -p $out/bin

      for script in $src/*.sh; do
        if [ -f "$script" ]; then
          name="$(basename "$script" .sh)"
          install -m 755 "$script" "$out/bin/$name"
        fi
      done
    '';
  };

  cfg = config.programs.nix-terminal;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ scriptsPackage ];
  };
}
