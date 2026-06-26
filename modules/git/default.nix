# nix-terminal.git — git + delta, ported from .dotfiles/git, de-hardcoded to andrew.
{ config, lib, ... }:

with lib;

let
  cfg = config.nix-terminal.git;
in
{
  options.nix-terminal.git = {
    enable = mkEnableOption "git + delta (ambient version control)";

    userName = mkOption {
      type = types.str;
      default = "andrew";
      description = "git user.name (de-hardcoded from .dotfiles' \"Bullish Design\").";
    };

    userEmail = mkOption {
      type = types.str;
      default = "090l060@gmail.com";
      description = "git user.email (de-hardcoded from .dotfiles' CHANGEME).";
    };

    defaultBranch = mkOption {
      type = types.str;
      default = "main";
      description = "init.defaultBranch.";
    };

    pullRebase = mkOption {
      type = types.bool;
      default = false; # .dotfiles value
      description = "pull.rebase.";
    };

    enableDelta = mkOption {
      type = types.bool;
      default = true;
      description = "delta pager + git integration.";
    };
  };

  config = mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        user.name = cfg.userName;
        user.email = cfg.userEmail;

        init.defaultBranch = cfg.defaultBranch;
        push.autoSetupRemote = true;
        pull = { rebase = cfg.pullRebase; };
        merge = { conflictStyle = "zdiff3"; };

        credential.helper = "!gh auth git-credential";
      };
    };

    programs.delta = mkIf cfg.enableDelta {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        side-by-side = true;
      };
    };
  };
}
