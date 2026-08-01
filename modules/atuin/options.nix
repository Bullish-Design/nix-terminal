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

    agentHooks = mkOption {
      type = types.listOf (types.enum [ "claude-code" "codex" "pi" ]);
      default = [ "claude-code" "codex" "pi" ];
      description = ''
        AI coding agents whose Bash tool invocations Atuin captures as
        history entries (author-tagged). Runs `atuin hook install` for each
        agent at Home Manager activation — idempotent, and merges into
        existing agent configs rather than clobbering them.
      '';
    };
  };
}
