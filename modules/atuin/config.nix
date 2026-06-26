# nix-terminal.atuin — ported from .dotfiles/shell/atuin.nix.
# Gates on its OWN enable only (decoupled from the umbrella).
{ config, lib, ... }:

with lib;

let
  cfg = config.nix-terminal.atuin;
in
{
  config = mkIf cfg.enable {
    programs.atuin = {
      enable = true;
      package = cfg.package;
      enableZshIntegration = config.programs.zsh.enable;
      daemon.enable = cfg.enableDaemon;
      flags = [ "--disable-up-arrow" ];

      settings = {
        auto_sync = cfg.autoSync;
        sync_frequency = "1m";
        sync_address = cfg.syncAddress;
        workspaces = true;
        filter_mode = cfg.filterMode;
        search_mode = cfg.searchMode;
        style = cfg.style;
      };
    };
  };
}
