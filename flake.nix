{
  description = "Ambient terminal Home-Manager environment (shell, zellij, git, kitty, atuin, scripts, dev CLIs, nixbuild/repoman wiring); consumes nix-nvim as the editor";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── pins OWNED here (nix-terminal-PLAN §5) — deliberately NOT following nixpkgs ──
    nixpkgs-zellij.url = "github:NixOS/nixpkgs/d407951447dcd00442e97087bf374aad70c04cea";
    atuin = {
      url = "github:atuinsh/atuin/v18.16.0"; # the v18.16.0 tag IS the pin
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── the editor (CONSUMED — replaces nixvim) ─────────────────────────
    # Absolute path: in dev (relative path: fails pure eval); github:…?ref=<tag>
    # at publish via repoman fleet flake-update.
    nix-nvim = {
      url = "path:/home/andrew/Documents/Projects/nix-nvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      # nix-nvim's nixpkgs-neovim pin (0.12) is NOT followed — stays at d2339023.
    };

    # ── reused tooling (HM wiring) ──────────────────────────────────────
    nixbuild = { url = "github:Bullish-Design/nixbuild"; inputs.nixpkgs.follows = "nixpkgs"; };
    repoman = { url = "github:Bullish-Design/repoman"; inputs.nixpkgs.follows = "nixpkgs"; };
    devman = { url = "github:Bullish-Design/devman/main"; inputs.nixpkgs.follows = "nixpkgs"; };

    # nixvim — DELETED entirely (superseded by nix-nvim).
  };

  outputs = { self, ... }@inputs:
    let
      # Each module is constructed once (currying in the inputs it needs), so the
      # `default` aggregate can re-import the same set and nix-terminal's owned
      # pins (nix-nvim, zellij, atuin) are baked in regardless of the consumer.
      mods = {
        terminal = import ./modules/terminal.nix { inherit (inputs) nix-nvim devman; };
        shell = import ./modules/shell;
        zellij = import ./modules/zellij { inherit (inputs) nixpkgs-zellij; };
        git = import ./modules/git;
        kitty = import ./modules/kitty;
        atuin = import ./modules/atuin { inherit (inputs) atuin; };
        scripts = import ./modules/scripts;
        development = import ./modules/development;
        nixbuild = import ./modules/nixbuild.nix { inherit (inputs) nixbuild; };
        repoman = import ./modules/repoman.nix { inherit (inputs) repoman; };
      };
    in
    {
      homeManagerModules = mods // {
        # Aggregate: imports every sibling (each still behind its own enable).
        # nix-meta imports the individual names, not this.
        default = { imports = builtins.attrValues mods; };
      };
    };
}
