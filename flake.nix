{
  description = "Terminal-only Home Manager profile - Pulls in Neovim config from another repo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixvim = {
      url = "github:Bullish-Design/nixvim/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devman = {
      url = "github:Bullish-Design/devman/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixvim, devman, ... }: {
    homeManagerModules.terminal = import ./modules/terminal.nix {
      inherit nixvim devman;
    };
  };
}
