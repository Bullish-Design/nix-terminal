{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    gh
    uv
    go
  ];

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
      pager = "less -FRSX";
    };
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  home.sessionVariables = {
    UV_NO_MANAGED_PYTHON = "1";
    GOPATH = "${config.home.homeDirectory}/.go";
  };
}
