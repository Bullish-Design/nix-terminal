# nix-terminal.terminal — the ambient-env umbrella + the editor wiring.
# Curried with the nix-nvim + devman flake inputs.
{ nix-nvim, devman }:
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix-terminal.terminal;
in
{
  # The editor lives in nix-nvim; the umbrella wires it in (and names it `nv`).
  imports = [ nix-nvim.homeManagerModules.neovim ];

  options.nix-terminal.terminal = {
    enable = mkEnableOption "the ambient terminal env umbrella (core CLIs + the nv editor)";

    corePackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [ tree jq ripgrep fd bat eza fzf htop curl wget ];
      description = "Core CLI set.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages to install.";
    };
  };

  config = mkIf cfg.enable {
    # The editor: the nix-nvim `nv` wrapper (loci + LSPs + treesitter).
    nix-nvim.neovim.enable = true;
    nix-nvim.neovim.command = "nv";

    home.packages = cfg.corePackages
      ++ [ devman.packages.${pkgs.system}.devman-tools ]
      ++ cfg.extraPackages;
  };
}
