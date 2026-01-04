{ config, lib, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    mouse = true;
    shell = "${pkgs.zsh}/bin/zsh";
    prefix = "C-s";
    keyMode = "vi";
    historyLimit = 100000;

    tmuxp.enable = true;

    plugins = with pkgs.tmuxPlugins; [
      better-mouse-mode
      vim-tmux-navigator
      yank
      sensible

      {
        plugin = dracula;
        extraConfig = ''
          set -g @dracula-show-powerline true
          set -g @dracula-show-flags true
          set -g @dracula-show-left-icon session
          set -g @dracula-plugins "cpu-usage gpu-usage ram-usage"
          set -g @dracula-left-icon-padding 2
          set -g @dracula-border-contrast true
          set -g status-position top
        '';
      }
    ];

    extraConfig = ''
      # Pane navigation
      bind-key h select-pane -L
      bind-key C-j select-pane -D
      bind-key C-k select-pane -U
      bind-key C-l select-pane -R

      set -gq allow-passthrough on

      # Start windows and panes at 1
      set -g base-index 1
      set -g pane-base-index 1
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on

      # Alt-arrow keys for pane switching
      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # Shift arrow/vim for window switching
      bind -n S-Left previous-window
      bind -n S-Right next-window
      bind -n S-h previous-window
      bind -n S-l next-window

      # Shift Alt vim keys for resizing
      bind -n M-K resize-pane -U 15
      bind -n M-J resize-pane -D 15
      bind -n M-H resize-pane -L 10
      bind -n M-L resize-pane -R 10

      # Alt vim keys for percentage resize
      bind -n M-k resizep -y 80%
      bind -n M-j resizep -y 20%
      bind -n C-Down resizep -y 90%
      bind -n C-Up resizep -y 10%
    '';
  };

  # Deploy tmuxp workspace templates
  xdg.configFile."tmuxp/code_project_template.yaml".text = ''
    session_name: Code Project
    windows:
      - window_name: dev
        layout: main-vertical
        options:
          main-pane-width: 33%
        panes:
          - shell_command:
              - cd ~/Documents/Notes/Projects
              - nvim notes.md ToDo.md
          - shell_command:
              - tmux resizep -y 90%
              - nvim
            focus: true
          - 
  '';

  home.sessionVariables.TMUXP_CONFIGDIR = "${config.xdg.configHome}/tmuxp";
}
