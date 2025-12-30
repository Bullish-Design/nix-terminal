{ nvim-config }:
{ pkgs, ... }:
{
  imports = [
    nvim-config.homeManagerModules.default
  ];

  # Minimal terminal “profile” extras
  programs.git.enable = true;

  home.packages = with pkgs; [
    tree
    jq
  ];
}

