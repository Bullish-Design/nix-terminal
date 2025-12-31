{ lib, ... }:

with lib;

{
  options.programs.nix-terminal.atuin = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable atuin shell history";
    };

    syncAddress = mkOption {
      type = types.str;
      default = "https://api.atuin.sh";
      description = "Atuin sync server address";
    };

    autoSync = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically sync history";
    };

    searchMode = mkOption {
      type = types.enum [ "prefix" "fulltext" "fuzzy" "skim" ];
      default = "fuzzy";
      description = "Search mode for history";
    };

    style = mkOption {
      type = types.enum [ "auto" "full" "compact" ];
      default = "auto";
      description = "Interface style";
    };
  };
}
