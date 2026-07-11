{ config, lib, ... }:

with lib;

let
  cfg = config.programs.nix-terminal;
in
{
  config = mkIf (cfg.enable && cfg.atuin.enable) {
    # Atuin owns Ctrl-R for history search. fzf (enabled in the zsh module) binds
    # Ctrl-R too by default; cede it so there's no double-binding — and no HM
    # "both configure Ctrl-R" warning. fzf keeps Ctrl-T (files) and Alt-C (cd).
    programs.fzf.historyWidget.command = mkIf cfg.zsh.enable "";

    # Atuin configuration
    programs.atuin = {
      enable = true;
      enableZshIntegration = cfg.zsh.enable;
      flags = [ "--disable-up-arrow" ];

      settings = {
        auto_sync = cfg.atuin.autoSync;
        sync_address = cfg.atuin.syncAddress;
        search_mode = cfg.atuin.searchMode;
        style = cfg.atuin.style;
        inline_height = 20;
        show_preview = true;
        filter_mode = "global";
        workspaces = true;
        ctrl_n_shortcuts = true;
      };
    };
  };
}
