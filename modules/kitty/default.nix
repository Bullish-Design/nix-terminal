# nix-terminal.kitty — full kitty for graphical hosts; terminfo-only on headless.
# Ported from .dotfiles/kitty + the new terminfoOnly path.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix-terminal.kitty;
in
{
  options.nix-terminal.kitty = {
    enable = mkEnableOption "kitty terminal support";

    terminfoOnly = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Headless path: install only kitty.terminfo (no GUI kitty, no config), so
        `kitten ssh` / remote sessions resolve xterm-kitty on the tower. Graphical
        hosts leave this false for the full kitty.
      '';
    };

    themeFile = mkOption {
      type = types.str;
      default = "LiquidCarbon";
      description = "kitty theme (graphical only).";
    };

    fontFamily = mkOption {
      type = types.str;
      default = "IosevkaNerdFontMono";
      description = "Font (graphical only).";
    };

    fontSize = mkOption {
      type = types.int;
      default = 9;
      description = "Font size (graphical only).";
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra programs.kitty.settings.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # Headless: just the terminfo entry.
    (mkIf cfg.terminfoOnly {
      home.packages = [ pkgs.kitty.terminfo ];
    })

    # Graphical: the full kitty, ported from .dotfiles/kitty.
    (mkIf (!cfg.terminfoOnly) {
      programs.kitty = {
        enable = true;
        themeFile = cfg.themeFile;
        settings = {
          font_family = cfg.fontFamily;
          scrollback_lines = 10000;
          enable_audio_bell = false;
          update_check_interval = 0;
          font_size = cfg.fontSize;
          cursor_shape = "Underline";
          cursor_underline_thickness = 1;
          window_padding_width = 0;
          url_style = "curly";
          confirm_os_window_close = "0";
          hide_window_decorations = "yes";
          remember_window_size = "yes";
          disable_ligatures = "never";
          shell = "${pkgs.zsh}/bin/zsh";
          initial_window_width = 1200;
          initial_window_height = 1200;
        } // cfg.extraSettings;
        keybindings = {
          "super+v" = "paste_from_clipboard";
          "super+c" = "copy_to_clipboard";
          "ctrl+shift+c" = "copy_to_clipboard";
          "ctrl+shift+v" = "paste_from_clipboard";
        };
      };
    })
  ]);
}
