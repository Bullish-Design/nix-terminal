{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.nix-terminal.zsh;
in
{
  config = mkIf (config.programs.nix-terminal.enable && cfg.enable) {
    # Zsh configuration
    programs.zsh = {
      enable = true;
      enableCompletion = cfg.enableCompletion;
      autosuggestion.enable = cfg.enableAutosuggestions;
      syntaxHighlighting.enable = cfg.enableSyntaxHighlighting;

      shellAliases = cfg.aliases;

      history = {
        size = cfg.historySize;
        path = cfg.historyPath;
        ignoreDups = true;
        ignoreSpace = true;
        expireDuplicatesFirst = true;
        share = true;
      };

      initExtra = ''
        # Better directory navigation
        setopt AUTO_CD
        setopt AUTO_PUSHD
        setopt PUSHD_IGNORE_DUPS
        setopt PUSHD_SILENT

        # Improved completion
        setopt COMPLETE_IN_WORD
        setopt ALWAYS_TO_END
        setopt PATH_DIRS
        setopt AUTO_MENU
        setopt AUTO_LIST
        setopt AUTO_PARAM_SLASH
        setopt EXTENDED_GLOB

        # Better history
        setopt APPEND_HISTORY
        setopt EXTENDED_HISTORY
        setopt HIST_IGNORE_ALL_DUPS
        setopt HIST_FIND_NO_DUPS
        setopt HIST_REDUCE_BLANKS
        setopt HIST_VERIFY

        # Completion styling
        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
        zstyle ':completion:*' menu select
        zstyle ':completion:*' special-dirs true
        zstyle ':completion:*' verbose true

        # Better ls with eza if available
        if command -v eza &> /dev/null; then
          alias ls='eza --icons'
          alias ll='eza -l --icons'
          alias la='eza -la --icons'
          alias lt='eza --tree --icons'
        fi

        # Better cat with bat if available
        if command -v bat &> /dev/null; then
          alias cat='bat --style=auto'
        fi

        # Guide aliases
        alias nimr='nix run'
        alias copier-new='copier copy'
        alias copier-update='copier update'
        alias uv-venv='uv venv'
        alias devboot='nix develop'

        ${cfg.extraConfig}
      '';
    };

    # Starship prompt
    programs.starship = mkIf (cfg.theme == "starship") {
      enable = true;
      settings = config.programs.nix-terminal.starshipSettings;
    };

    # Deploy custom theme if specified
    home.file.".oh-my-zsh/custom/themes/devprompt.zsh-theme" = lib.mkIf (cfg.theme == "devprompt") {
      text = ''
        # devprompt.zsh-theme
        local current_dir='%{$fg[cyan]%}%3~%{$reset_color%}'

        ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[yellow]%}‹"
        ZSH_THEME_GIT_PROMPT_SUFFIX="› %{$reset_color%}"
        ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}●%{$fg[yellow]%}"
        ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[yellow]%}"

        ZSH_THEME_VIRTUAL_ENV_PROMPT_PREFIX="%{$fg[green]%}‹"
        ZSH_THEME_VIRTUAL_ENV_PROMPT_SUFFIX="› %{$reset_color%}"
        ZSH_THEME_VIRTUALENV_PREFIX="$ZSH_THEME_VIRTUAL_ENV_PROMPT_PREFIX"
        ZSH_THEME_VIRTUALENV_SUFFIX="$ZSH_THEME_VIRTUAL_ENV_PROMPT_SUFFIX"

        PROMPT='╭─''${current_dir} $(git_prompt_info)$(virtualenv_prompt_info)
        ╰─%B➜%b '

        RPROMPT='%(?..%{$fg[red]%}✘ %?%{$reset_color%})'
      '';
    };

    # FZF configuration for better fuzzy finding
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
        "--inline-info"
      ];
      changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    };

    # Direnv for automatic environment loading
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
