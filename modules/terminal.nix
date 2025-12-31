{ nixvim, devman }:
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.nix-terminal;
in
{
  imports = [
    ./zsh
    ./atuin
    nixvim.homeManagerModules.default
  ];

  options.programs.nix-terminal = {
    enable = mkEnableOption "nix-terminal configuration";

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to install";
    };
  };

  config = mkIf cfg.enable {
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
  };
}

