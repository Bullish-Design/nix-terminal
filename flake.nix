{
  description = "Terminal-only Home Manager profile";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, ... }: {
    homeManagerModules.terminal = import ./modules/terminal.nix;
  };
}
