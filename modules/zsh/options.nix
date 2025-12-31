{ lib, ... }:

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
      default = {
        ll = "ls -lah";
        la = "ls -A";
        l = "ls -CF";
        ".." = "cd ..";
        "..." = "cd ../..";
        grep = "grep --color=auto";
        gst = "git status";
        gd = "git diff";
        gc = "git commit";
        gp = "git push";
        gl = "git log --oneline --graph --decorate";
      };
      description = "Shell aliases";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra zsh configuration";
    };
  };
}
