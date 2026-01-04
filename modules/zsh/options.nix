{ config, lib, ... }:

with lib;

{
  options.programs.nix-terminal.zsh = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable zsh configuration";
    };

    theme = mkOption {
      type = types.enum [ "powerlevel10k" "starship" "minimal" ];
      default = "starship";
      description = "Theme to use for zsh prompt";
    };

    enableAutosuggestions = mkOption {
      type = types.bool;
      default = true;
      description = "Enable zsh autosuggestions";
    };

    enableSyntaxHighlighting = mkOption {
      type = types.bool;
      default = true;
      description = "Enable zsh syntax highlighting";
    };

    enableCompletion = mkOption {
      type = types.bool;
      default = true;
      description = "Enable zsh completion";
    };

    aliases = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Shell aliases (override to customize)";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra zsh configuration";
    };

    historySize = mkOption {
      type = types.int;
      default = 10000;
      description = "Number of commands to keep in history";
    };

    historyPath = mkOption {
      type = types.str;
      default = "${config.xdg.dataHome}/zsh/history";
      description = "Path to zsh history file";
    };
  };
}
