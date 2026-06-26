{ config, lib, ... }:

with lib;

{
  options.nix-terminal.shell = {
    enable = mkEnableOption "the zsh ambient shell environment (oh-my-zsh devprompt, hooks, fzf, zoxide, direnv)";

    theme = mkOption {
      type = types.enum [ "starship" "devprompt" "minimal" ];
      default = "devprompt"; # .dotfiles parity (oh-my-zsh devprompt theme)
      description = "Prompt theme.";
    };

    enableAutosuggestions = mkOption {
      type = types.bool;
      default = true;
      description = "zsh autosuggestions.";
    };

    enableSyntaxHighlighting = mkOption {
      type = types.bool;
      default = true;
      description = "zsh syntax highlighting.";
    };

    enableCompletion = mkOption {
      type = types.bool;
      default = true;
      description = "zsh completion.";
    };

    aliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra aliases merged on top of the built-in set (nv/vim/v, cd→z, ls→eza, …).";
    };

    historySize = mkOption {
      type = types.int;
      default = 1000000; # .dotfiles parity
      description = "History entries.";
    };

    historyPath = mkOption {
      type = types.str;
      default = "${config.xdg.dataHome}/zsh/history";
      description = "History file path.";
    };

    enableZoxide = mkOption {
      type = types.bool;
      default = true;
      description = "zoxide + zsh integration (cd→z).";
    };

    enableFzf = mkOption {
      type = types.bool;
      default = true;
      description = "fzf + zsh integration (fd-backed).";
    };

    enableDirenv = mkOption {
      type = types.bool;
      default = true;
      description = "direnv + nix-direnv zsh integration.";
    };

    starshipSettings = mkOption {
      type = types.attrs;
      default = {
        add_newline = true;
        format = concatStrings [
          "$username"
          "$hostname"
          "$directory"
          "$git_branch"
          "$git_state"
          "$git_status"
          "$cmd_duration"
          "$line_break"
          "$python"
          "$character"
        ];
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
        directory = {
          truncation_length = 3;
          truncate_to_repo = true;
          style = "bold cyan";
        };
        git_branch = {
          symbol = " ";
          style = "bold purple";
        };
        git_status = {
          conflicted = "🏳";
          ahead = "⇡\${count}";
          behind = "⇣\${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          untracked = "🤷";
          stashed = "📦";
          modified = "📝";
          staged = "[++($count)](green)";
          renamed = "👅";
          deleted = "🗑";
        };
        cmd_duration = {
          min_time = 500;
          format = "underwent [$duration](bold yellow)";
        };
        python = {
          symbol = " ";
          style = "yellow bold";
        };
      };
      description = "Starship config (used only when theme = starship).";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra zsh initContent appended at the end.";
    };
  };
}
