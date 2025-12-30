{
  description = "Terminal-only Home Manager profile - Pulls in Neovim config from another repo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixvim = {
      url = "github:Bullish-Design/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixvim, ... }: {
    homeManagerModules.terminal = import ./modules/terminal.nix {
      inherit nixvim;
    };
  };
}
