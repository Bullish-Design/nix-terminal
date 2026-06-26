# Curried with the atuin flake input so `package` defaults to the v18.16.0 pin.
{ atuin }:
{ lib, pkgs, ... }:

with lib;

let
  # The .dotfiles pin: atuin flake's package overridden to v18.16.0 (the tag is
  # the pin; its nixpkgs follows ours).
  pinnedAtuin = atuin.packages.${pkgs.system}.default.overrideAttrs (_: {
    version = "18.16.0";
  });
in
{
  options.nix-terminal.atuin = {
    enable = mkEnableOption "atuin shell history (daemon)";

    package = mkOption {
      type = types.package;
      default = pinnedAtuin;
      defaultText = literalExpression "atuin (v18.16.0 pin)";
      description = "atuin package (defaulted to the v18.16.0 pin).";
    };

    enableDaemon = mkOption {
      type = types.bool;
      default = true;
      description = "Run the atuin daemon (.dotfiles parity).";
    };

    syncAddress = mkOption {
      type = types.str;
      default = "https://api.atuin.sh";
      description = "Sync server.";
    };

    autoSync = mkOption {
      type = types.bool;
      default = true; # .dotfiles parity
      description = "auto_sync.";
    };

    searchMode = mkOption {
      type = types.enum [ "prefix" "fulltext" "fuzzy" "skim" "daemon-fuzzy" ];
      default = "daemon-fuzzy"; # .dotfiles value
      description = "search_mode.";
    };

    filterMode = mkOption {
      type = types.str;
      default = "workspace"; # .dotfiles value
      description = "filter_mode.";
    };

    style = mkOption {
      type = types.enum [ "auto" "full" "compact" ];
      default = "auto";
      description = "Interface style.";
    };
  };
}
