# modules/zelligate.nix
#
# nix-terminal enable seam for the zelligate Zellij web workbench, modelled on
# modules/repoman.nix. zelligate already ships its own Home-Manager module
# (`services.zelligate.*`, defined in the zelligate repo), so this wrapper just
# imports it and binds the two options that have no in-repo default:
#
#   * package      → the zelligate flake's packages.default
#   * zellijPackage → the zellij binary placed on the daemon's PATH
#
# There is no owned zellij pin in nix-terminal, so zellij is sourced from
# nixpkgs. nixpkgs-unstable ships zellij 0.44.3, whose `web` subcommand has the
# `--create-token` / `--revoke-token` / `--revoke-all-tokens` / `--list-tokens`
# interface zelligate drives (verified). Both are `mkDefault`, so a consumer can
# override the zellij source (e.g. a future curated pin) without editing here.
#
# A consumer enables the daemon with `services.zelligate.enable = true` and, for
# tailnet-reachable URLs, `services.zelligate.publicHost = "<tower>.<tailnet>.ts.net"`.
{ zelligate }:
{ config, lib, pkgs, ... }:

{
  imports = [ zelligate.homeManagerModules.zelligate ];

  config = {
    services.zelligate.package =
      lib.mkDefault zelligate.packages.${pkgs.stdenv.hostPlatform.system}.default;
    services.zelligate.zellijPackage = lib.mkDefault pkgs.zellij;
  };
}
