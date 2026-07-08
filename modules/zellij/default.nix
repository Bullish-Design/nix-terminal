# nix-terminal.zellij — the multiplexer, ported from .dotfiles/zellij.
# Curried with the nixpkgs-zellij pin (d4079514, zellij 0.44.3). Graphical launchers/desktop
# entry are gated off on the headless tower.
{ nixpkgs-zellij }:
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix-terminal.zellij;
  pkgs-zellij = import nixpkgs-zellij { system = pkgs.system; };
  homeDir = config.home.homeDirectory;
in
{
  options.nix-terminal.zellij = {
    enable = mkEnableOption "zellij multiplexer + launchers + KDL config set";

    package = mkOption {
      type = types.package;
      default = pkgs-zellij.zellij;
      defaultText = literalExpression "nixpkgs-zellij (d4079514).zellij";
      description = "The zellij to install (defaulted from the pin).";
    };

    defaultLayout = mkOption {
      type = types.str;
      default = "nvim";
      description = "default_layout in the main config.";
    };

    theme = mkOption {
      type = types.str;
      default = "kanagawa";
      description = "Theme name.";
    };

    enableDesktopEntry = mkOption {
      type = types.bool;
      default = false;
      description = "Install the zellij-terminal xdg desktop entry (graphical hosts only).";
    };

    enableGraphicalLaunchers = mkOption {
      type = types.bool;
      default = false;
      description = "Install the zellij-terminal launcher (needs kitty + `niri msg`); headless installs only `znv`.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      cfg.package
      (pkgs.writeShellScriptBin "znv" ''
        exec ${cfg.package}/bin/zellij --layout nvim "$@"
      '')
    ] ++ optional cfg.enableGraphicalLaunchers (
      pkgs.writeShellScriptBin "zellij-terminal" ''
        output_count="$(niri msg --json outputs | ${pkgs.jq}/bin/jq 'length')"
        if [ "$output_count" -ge 2 ]; then
          font_size=12
        else
          font_size=14
        fi
        exec ${pkgs.kitty}/bin/kitty --class zellij-terminal --override "font_size=$font_size" \
          ${cfg.package}/bin/zellij \
          --config "${homeDir}/.config/zellij/terminal-config.kdl" \
          --layout terminal
      ''
    );

    xdg.desktopEntries = mkIf cfg.enableDesktopEntry {
      "zellij-terminal" = {
        name = "Zellij Terminal";
        genericName = "Terminal";
        exec = "zellij-terminal";
        categories = [ "System" "TerminalEmulator" ];
        terminal = false;
      };
    };

    # Zellij config managed via raw KDL files.
    xdg.configFile."zellij/config.kdl".text = ''
      pane_frames false
      default_layout "${cfg.defaultLayout}"
      show_startup_tips false
      theme "${cfg.theme}"

      themes {
          kanagawa {
              bg "#2A2A37"
              fg "#DCD7BA"
              red "#C34043"
              green "#76946A"
              blue "#7E9CD8"
              yellow "#DCA561"
              magenta "#957FB8"
              orange "#FFA066"
              cyan "#6A9589"
              black "#1F1F28"
              white "#C8C093"
          }
      }

      // autolock: lock to Zellij when nvim/fzf/etc are running
      plugins {
          autolock location="https://github.com/fresh2dev/zellij-autolock/releases/latest/download/zellij-autolock.wasm" {
              is_enabled true
              triggers "nvim|vim|git|fzf|zoxide|atuin"
              reaction_seconds "0.3"
              print_to_log false
          }
      }

      load_plugins {
          autolock
          // attention: pane activity notifications in tab bar
          "https://github.com/KiryuuLight/zellij-attention/releases/latest/download/zellij-attention.wasm" {
              enabled "true"
              waiting_icon " "
              completed_icon "󰄬 "
          }
      }

      keybinds clear-defaults=false {
          normal {
              // Quake-style dropdown terminal toggle
              bind "Alt `" { ToggleFloatingPanes; }
              // Bookmarks
              bind "Alt b" {
                  LaunchOrFocusPlugin "https://github.com/yaroslavborbat/zellij-bookmarks/releases/latest/download/zellij-bookmarks.wasm" {
                      floating true
                      cwd "${homeDir}/.config/zellij"
                  };
              }
          }
      }
    '';

    # Terminal zellij: standalone terminal session with pane frames.
    xdg.configFile."zellij/terminal-config.kdl".text = ''
      pane_frames true
      show_startup_tips false
      theme "kanagawa"

      themes {
          kanagawa {
              bg "#2A2A37"
              fg "#DCD7BA"
              red "#C34043"
              green "#76946A"
              blue "#7E9CD8"
              yellow "#DCA561"
              magenta "#957FB8"
              orange "#FFA066"
              cyan "#6A9589"
              black "#1F1F28"
              white "#C8C093"
          }
      }

      // autolock: lock to Zellij when nvim/fzf/etc are running
      plugins {
          autolock location="https://github.com/fresh2dev/zellij-autolock/releases/latest/download/zellij-autolock.wasm" {
              is_enabled true
              triggers "nvim|vim|git|fzf|zoxide|atuin"
              reaction_seconds "0.3"
              print_to_log false
          }
      }

      load_plugins {
          autolock
      }

      keybinds clear-defaults=false {
          normal {
              bind "Alt `" { ToggleFloatingPanes; }
          }
      }
    '';

    xdg.configFile."zellij/layouts/terminal.kdl".text = ''
      layout {
          default_tab_template {
              children
          }
          tab {
              pane
          }
      }
    '';

    # Sidebar zellij: separate config, no autolock.
    xdg.configFile."zellij/sidebar-config.kdl".text = ''
      pane_frames true
      default_layout "sidebar"
      show_startup_tips false
      theme "kanagawa-dragon"

      themes {
          kanagawa-dragon {
              bg "#282727"
              fg "#c5c9c5"
              red "#c4746e"
              green "#87a987"
              blue "#8ba4b0"
              yellow "#c4b28a"
              magenta "#a292a3"
              orange "#b6927b"
              cyan "#8ea4a2"
              black "#181616"
              white "#c5c9c5"
          }
      }

      // No autolock — sidebar is controlled externally via sidebar-ctl
      // Default keybinds preserved: Alt+h/j/k/l for pane nav, Alt+n for new pane

      keybinds clear-defaults=false {
          normal {
              bind "Alt `" { ToggleFloatingPanes; }
          }
      }
    '';

    xdg.configFile."zellij/layouts/sidebar.kdl".source = ./layouts/sidebar.kdl;

    xdg.configFile."zellij/layouts/nvim.kdl".text = ''
      layout {
          pane size=1 borderless=true {
              plugin location="https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm" {
                  // Kanagawa palette
                  color_bg      "#1F1F28"
                  color_surface "#2A2A37"
                  color_overlay "#363646"
                  color_subtle  "#727169"
                  color_fg      "#DCD7BA"
                  color_red     "#C34043"
                  color_green   "#76946A"
                  color_blue    "#7E9CD8"
                  color_yellow  "#DCA561"
                  color_violet  "#957FB8"
                  color_cyan    "#6A9589"
                  color_orange  "#FFA066"

                  format_left   "{mode}#[bg=$bg,fg=$subtle,bold]  {session}  {tabs}"
                  format_right  "{datetime}"
                  format_space  "#[bg=$bg]"

                  hide_frame_for_single_pane "true"

                  mode_normal        "#[bg=$green,fg=$bg,bold] NOR #[bg=$bg,fg=$green]"
                  mode_locked        "#[bg=$red,fg=$bg,bold] LCK #[bg=$bg,fg=$red]"
                  mode_resize        "#[bg=$yellow,fg=$bg,bold] RES #[bg=$bg,fg=$yellow]"
                  mode_pane          "#[bg=$blue,fg=$bg,bold] PAN #[bg=$bg,fg=$blue]"
                  mode_tab           "#[bg=$yellow,fg=$bg,bold] TAB #[bg=$bg,fg=$yellow]"
                  mode_scroll        "#[bg=$cyan,fg=$bg,bold] SCR #[bg=$bg,fg=$cyan]"
                  mode_enter_search  "#[bg=$violet,fg=$bg,bold]  /  #[bg=$bg,fg=$violet]"
                  mode_search        "#[bg=$violet,fg=$bg,bold]  ?  #[bg=$bg,fg=$violet]"
                  mode_rename_tab    "#[bg=$yellow,fg=$bg,bold] RNT #[bg=$bg,fg=$yellow]"
                  mode_rename_pane   "#[bg=$blue,fg=$bg,bold] RNP #[bg=$bg,fg=$blue]"
                  mode_session       "#[bg=$blue,fg=$bg,bold] SES #[bg=$bg,fg=$blue]"
                  mode_move          "#[bg=$orange,fg=$bg,bold] MOV #[bg=$bg,fg=$orange]"
                  mode_prompt        "#[bg=$violet,fg=$bg,bold]  >  #[bg=$bg,fg=$violet]"
                  mode_tmux          "#[bg=$violet,fg=$bg,bold] TMX #[bg=$bg,fg=$violet]"

                  tab_normal            "#[bg=$surface,fg=$subtle] {name}{floating_indicator} #[bg=$bg,fg=$surface]"
                  tab_normal_fullscreen "#[bg=$surface,fg=$subtle] {name}{fullscreen_indicator} #[bg=$bg,fg=$surface]"
                  tab_normal_sync       "#[bg=$surface,fg=$subtle] {name}{sync_indicator} #[bg=$bg,fg=$surface]"
                  tab_active            "#[bg=$blue,fg=$bg,bold] {name}{floating_indicator} #[bg=$bg,fg=$blue]"
                  tab_active_fullscreen "#[bg=$blue,fg=$bg,bold] {name}{fullscreen_indicator} #[bg=$bg,fg=$blue]"
                  tab_active_sync       "#[bg=$blue,fg=$bg,bold] {name}{sync_indicator} #[bg=$bg,fg=$blue]"

                  tab_separator            "#[bg=$bg,fg=$surface]│"
                  tab_sync_indicator       " "
                  tab_fullscreen_indicator " 󰊓"
                  tab_floating_indicator   " 󰹙"

                  datetime        "#[bg=$bg,fg=$subtle,bold] {format} "
                  datetime_format "%H:%M"
              }
          }
          pane command="nv" focus=true
      }
    '';
  };
}
