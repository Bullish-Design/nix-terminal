{ nixvim, devman }:
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.nix-terminal;
in
{
  options.programs.nix-terminal = {
    enable = mkEnableOption "nix-terminal configuration";

    zsh = {
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

    atuin = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable atuin shell history";
      };

      syncAddress = mkOption {
        type = types.str;
        default = "https://api.atuin.sh";
        description = "Atuin sync server address";
      };

      autoSync = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically sync history";
      };

      searchMode = mkOption {
        type = types.enum [ "prefix" "fulltext" "fuzzy" "skim" ];
        default = "fuzzy";
        description = "Search mode for history";
      };

      style = mkOption {
        type = types.enum [ "auto" "full" "compact" ];
        default = "auto";
        description = "Interface style";
      };
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to install";
    };
  };

  config = mkMerge [
    # Always import nixvim
    {
      imports = [
        nixvim.homeManagerModules.default
      ];
    }

    # Core terminal configuration
    (mkIf cfg.enable {
      # Git configuration
      programs.git = {
        enable = true;
        extraConfig = {
          init.defaultBranch = "main";
          pull.rebase = true;
        };
      };

      # Core terminal packages
      home.packages = (with pkgs; [
        tree
        jq
        ripgrep
        fd
        bat
        eza
        fzf
        htop
        curl
        wget
      ]) ++ [
        devman.packages.${pkgs.system}.devman-tools
      ] ++ cfg.extraPackages;

      # Zsh configuration
      programs.zsh = mkIf cfg.zsh.enable {
        enable = true;
        enableCompletion = cfg.zsh.enableCompletion;
        autosuggestion.enable = cfg.zsh.enableAutosuggestions;
        syntaxHighlighting.enable = cfg.zsh.enableSyntaxHighlighting;

        shellAliases = cfg.zsh.aliases;

        history = {
          size = 10000;
          path = "${config.xdg.dataHome}/zsh/history";
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

          ${cfg.zsh.extraConfig}
        '';
      };

      # Starship prompt
      programs.starship = mkIf (cfg.zsh.enable && cfg.zsh.theme == "starship") {
        enable = true;
        settings = {
          add_newline = true;
          format = lib.concatStrings [
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
      };

      # Atuin configuration
      programs.atuin = mkIf cfg.atuin.enable {
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

      # FZF configuration for better fuzzy finding
      programs.fzf = {
        enable = true;
        enableZshIntegration = cfg.zsh.enable;
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
        enableZshIntegration = cfg.zsh.enable;
        nix-direnv.enable = true;
      };
    })
  ];
}

