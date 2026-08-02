{
  description = "Terminal-only Home Manager profile - Pulls in Neovim config from another repo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    nixbuild = {
      url = "github:Bullish-Design/nixbuild";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-nvim packages the loci-rich Neovim config promoted from ~/.dotfiles/nvim.
    # It supersedes the old Bullish-Design/nixvim input (retired). follows keeps
    # the single-nixpkgs hygiene nix-nvim advertises (its neovim 0.12 pin is the
    # only sanctioned extra node, held internally).
    nix-nvim = {
      url = "github:Bullish-Design/nix-nvim";
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

    # DISABLED 2026-08-01: zelligate input commented out (workspace daemon not
    # in use; nix-meta disabled it the same day). Restore together with the
    # output export + modules/zelligate.nix when Phase C returns.
    # zelligate = {
    #   # Private fleet repo — SSH form (same convention as nix-secrets in nix-meta).
    #   url = "git+ssh://git@github.com/Bullish-Design/zelligate.git?ref=main";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = { self, nix-nvim, devman, nixbuild, repoman, ... }: {
    homeManagerModules = {
      terminal = import ./modules/terminal.nix {
        inherit nix-nvim devman;
      };
      
      nixbuild = import ./modules/nixbuild.nix { 
        inherit nixbuild; 
      };

      repoman = import ./modules/repoman.nix { inherit repoman; };

      # DISABLED 2026-08-01 with the input above (see flake.nix zelligate note).
      # zelligate = import ./modules/zelligate.nix { inherit zelligate; };

      tmux = import ./modules/tmux;
      
      development = import ./modules/development;
      
      scripts = import ./modules/scripts;
    };
  };
}
