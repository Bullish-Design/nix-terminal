{
  description = "Terminal-only Home Manager profile - Pulls in Neovim config from another repo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    nixbuild = {
      url = "github:Bullish-Design/nixbuild";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:Bullish-Design/nixvim/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devman = {
      url = "github:Bullish-Design/devman/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    repoman = {
      url = "github:Bullish-Design/repoman";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixvim, devman, nixbuild, repoman, ... }: {
    # homeManagerModules.terminal = import ./modules/terminal.nix {
    #   inherit nixvim devman nixbuild;
    # };
    homeManagerModules = {
      terminal = import ./modules/terminal.nix {
        inherit nixvim devman;
      };
      
      nixbuild = import ./modules/nixbuild.nix { 
        inherit nixbuild; 
      };

      repoman = import ./modules/repoman.nix { inherit repoman; };
      
      tmux = import ./modules/tmux;
      
      development = import ./modules/development;
      
      scripts = import ./modules/scripts;
    };
  };
}
