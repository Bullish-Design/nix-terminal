{
  description = "Terminal-only Home Manager profile - Pulls in Neovim config from another repo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nvim-config = {
      url = "github:<YOU>/nvim-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nvim-config, ... }: {
    homeManagerModules.terminal = import ./modules/terminal.nix {
      inherit nvim-config;
    };
  };
}
