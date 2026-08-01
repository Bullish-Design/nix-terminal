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

    # Install AI agent hooks (claude-code, codex, pi) so commands run by
    # coding agents appear in Atuin history, author-tagged. Use atuin's own
    # installer: it merges into the user's existing agent configs (Claude
    # settings, Codex hooks) and writes the pi extension from source embedded
    # in the binary — neither is expressible as static `home.files`.
    home.activation.atuinAgentHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      concatMapStringsSep "\n" (agent: ''
        $DRY_RUN_CMD ${config.programs.atuin.package}/bin/atuin hook install ${agent}
      '') cfg.atuin.agentHooks
    );
  };
}
