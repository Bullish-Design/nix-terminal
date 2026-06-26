# nix-terminal.shell — the zsh ambient env, ported from .dotfiles/shell/{zsh,zoxide}.nix.
# Gates on its OWN enable only (decoupled from the umbrella).
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix-terminal.shell;

  builtinAliases = {
    nv = "nvim";
    vim = "nvim";
    v = "nvim";
    c = "clear";
    clera = "clear";
    celar = "clear";
    e = "exit";
    cd = "z";
    ls = "${pkgs.eza}/bin/eza --icons=always";
    sl = "ls";
    open = "${pkgs.xdg-utils}/bin/xdg-open";
    icat = "${pkgs.kitty}/bin/kitty +kitten icat";
  };
in
{
  config = mkIf cfg.enable {
    home.packages = with pkgs; [ eza bat ripgrep tldr ];

    programs.zsh = {
      enable = true;
      enableCompletion = cfg.enableCompletion;

      autosuggestion = {
        enable = cfg.enableAutosuggestions;
        highlight = "fg=248,italic,underline";
      };

      syntaxHighlighting = {
        enable = cfg.enableSyntaxHighlighting;
        styles = {
          comment = "fg=white,bold,underline";
        };
      };

      historySubstringSearch.enable = true;

      history = {
        append = true;
        save = cfg.historySize;
        size = cfg.historySize;
        path = cfg.historyPath;
      };

      oh-my-zsh = {
        enable = true;
        custom = "${config.home.homeDirectory}/.oh-my-zsh/custom"; # sets ZSH_CUSTOM early
        theme = if cfg.theme == "devprompt" then "devprompt" else "";
        plugins = [ "git" "virtualenv" ];
      };

      profileExtra = lib.optionalString (config.home.sessionPath != [ ]) ''
        export PATH="$PATH''${PATH:+:}${
          lib.concatStringsSep ":" config.home.sessionPath
        }"
      '';

      shellAliases = builtinAliases // cfg.aliases;

      initContent = ''
        export PATH="$HOME/.local/bin:$PATH"
        export DISABLE_AUTO_TITLE="true"
        [[ -f "$HOME/.secrets.env" ]] && source "$HOME/.secrets.env"

        setopt INTERACTIVE_COMMENTS

        # Make sure add-zsh-hook is available
        autoload -Uz add-zsh-hook

        # Right-align text on the current prompt line using absolute cursor positioning
        _prompt_right_align() {
          local text="$1"
          local col=$((COLUMNS - ''${#text}))
          printf '\e[%dG\e[90m%s\e[0m' "$col" "$text"
        }

        # Wrapper to avoid nested-brace issue in prompt expansion
        _prompt_start_time() {
          [[ -n "$_cmd_start_time" ]] && _prompt_right_align "$_cmd_start_time"
        }

        # Capture command start time for prompt display
        _cmd_preexec() {
          _cmd_start_time=$(date +%H:%M:%S)
          _cmd_ran=1
        }
        add-zsh-hook preexec _cmd_preexec

        # Print finish timestamp after command output
        _cmd_precmd() {
          if [[ -n "$_cmd_ran" ]]; then
            local end_time=$(date +%H:%M:%S)
            local col=$((COLUMNS - ''${#end_time}))
            printf '\n\e[%dG\e[90m%s\e[0m\n' "$col" "$end_time"
            unset _cmd_ran
          fi
        }
        add-zsh-hook precmd _cmd_precmd

        # Set terminal title for zellij pane frame display
        _set_term_title() {
          print -Pn "\e]2;%n@%m:%~\a"
        }
        add-zsh-hook precmd _set_term_title

        _atuin_comment_history() {
          emulate -L zsh

          # strip trailing newline (the ''${ escapes Nix interpolation)
          local line=''${1%%$'\n'}

          [[ $line == \#* ]] || return 0    # ignore non-comment lines

          print -sr -- "$line"              # keep it in normal history

          {
            local id=$(ATUIN_LOG=error atuin history start -- "$line")   # open row
            ATUIN_LOG=error atuin history end --exit 0 --duration=0 -- "$id"   # close row
          } &!                            # fire-and-forget, like upstream Atuin
        }

        add-zsh-hook zshaddhistory _atuin_comment_history

        ${cfg.extraConfig}
      '';
    };

    # devprompt oh-my-zsh theme (ported file).
    home.file.".oh-my-zsh/custom/themes/devprompt.zsh-theme" =
      lib.mkIf (cfg.theme == "devprompt") { source = ./devprompt.zsh-theme; };

    # Starship prompt (only when theme = starship).
    programs.starship = lib.mkIf (cfg.theme == "starship") {
      enable = true;
      settings = cfg.starshipSettings;
    };

    programs.fzf = lib.mkIf cfg.enableFzf {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      defaultOptions = [ "--height 40%" "--layout=reverse" "--border" "--inline-info" ];
      changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    };

    programs.zoxide = lib.mkIf cfg.enableZoxide {
      enable = true;
      enableZshIntegration = true;
    };

    programs.direnv = lib.mkIf cfg.enableDirenv {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
