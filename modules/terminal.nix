{ nix-nvim, devman }:
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.nix-terminal;
in
{
  imports = [
    ./zsh
    ./atuin
    ./scripts
    nix-nvim.homeManagerModules.neovim
  ];

  options.programs.nix-terminal = {
    enable = mkEnableOption "nix-terminal configuration";

    corePackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
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
      ];
      description = "Core terminal packages (override to customize)";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to install";
    };

    # devman bundles the claude-code and codex-cli CLIs alongside its own
    # orchestrator (tmuxp + Claude Code + Neovim workspace launcher). Some hosts
    # install those agents separately (e.g. a dedicated agent profile) — let them
    # keep the devman orchestrator without shipping duplicate agent binaries.
    devman = {
      enable = mkEnableOption "the devman workspace orchestrator (tmuxp + Claude Code + Neovim)";

      withClaudeCode = mkOption {
        type = types.bool;
        default = true;
        description = "Bundle the claude-code CLI into the devman env (sadjow/claude-code-nix)";
      };

      withCodexCli = mkOption {
        type = types.bool;
        default = true;
        description = "Bundle the codex-cli into the devman env (sadjow/codex-cli-nix)";
      };
    };

    enableGit = mkOption {
      type = types.bool;
      default = true;
      description = "Enable git with default configuration";
    };

    gitDefaultBranch = mkOption {
      type = types.str;
      default = "main";
      description = "Default branch name for new git repositories";
    };

    gitPullRebase = mkOption {
      type = types.bool;
      default = true;
      description = "Use rebase when pulling";
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
      description = "Starship prompt configuration";
    };
  };

  config = mkIf cfg.enable {
    # Git configuration
    programs.git = mkIf cfg.enableGit {
      enable = true;
      extraConfig = {
        init.defaultBranch = cfg.gitDefaultBranch;
        pull.rebase = cfg.gitPullRebase;
      };
    };

    # Core terminal packages
    home.packages = cfg.corePackages
      ++ lib.optional cfg.devman.enable (
        devman.lib.mkDevmanEnv {
          system = pkgs.stdenv.hostPlatform.system;
          withClaudeCode = cfg.devman.withClaudeCode;
          withCodexCli = cfg.devman.withCodexCli;
        }
      )
      ++ cfg.extraPackages;

    # Neovim: the loci-rich config packaged by nix-nvim (supersedes the old
    # nixvim input). Its `enable` defaults off, so activate it with the terminal
    # module; `nv` is the fleet-standard launcher bin name.
    nix-nvim.neovim = {
      enable = true;
      command = "nv";
    };
  };
}
