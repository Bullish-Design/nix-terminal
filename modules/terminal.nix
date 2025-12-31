{ nixvim, devman }:
{ pkgs, ... }:
{
  imports = [
    nixvim.homeManagerModules.default
  ];

  # Minimal terminal “profile” extras
  programs.git.enable = true;

  home.packages =
    (with pkgs; [
      tree
      jq
    ])
    ++ [
      devman.packages.${pkgs.system}.devman-tools
    ];
}

