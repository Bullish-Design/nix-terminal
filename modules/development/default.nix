# nix-terminal.development — ambient base CLIs only (gh + direnv hook).
# uv/go + their session vars MOVED to devenv-lib (project toolchains, not ambient).
{ config, lib, pkgs, ... }:

let
  cfg = config.nix-terminal.development;
in
{
  options.nix-terminal.development = {
    enable = lib.mkEnableOption "ambient base CLIs (gh + direnv)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ gh ];

    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
      settings = {
        git_protocol = "ssh";
        editor = "nvim";
        pager = "less -FRSX";
      };
    };

    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
