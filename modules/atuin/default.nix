{ atuin }:
{
  imports = [
    (import ./options.nix { inherit atuin; })
    ./config.nix
  ];
}
