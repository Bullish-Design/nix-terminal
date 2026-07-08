# modules/zelligate.nix — the HM enable seam for zelligate (repoman.nix-style).
#
# All real logic lives in zelligate's own Home-Manager module
# (services.zelligate); this wrapper just exposes the nix-terminal.zelligate.*
# namespace, supplies the package, and injects the owned zellij pin so the web
# terminal is the same curated zellij as the rest of the environment.
#
# The pin is imported directly from nixpkgs-zellij (Step 1's rev), so this does
# NOT require the nix-terminal.zellij module to be enabled on the host — the
# headless tower runs the daemon without the interactive zellij/launchers.
{ zelligate, nixpkgs-zellij }:
{ config, lib, pkgs, ... }:

let
  cfg = config.nix-terminal.zelligate;
  zelligatePkg = zelligate.packages.${pkgs.system}.default;
  pinnedZellij = (import nixpkgs-zellij { system = pkgs.system; }).zellij;
in
{
  imports = [ zelligate.homeManagerModules.zelligate ];

  options.nix-terminal.zelligate = {
    enable = lib.mkEnableOption "zelligate Zellij web workbench (systemd user service)";

    package = lib.mkOption {
      type = lib.types.package;
      default = zelligatePkg;
      defaultText = lib.literalExpression "zelligate.packages.\${system}.default";
      description = "The zelligate package to run and install.";
    };

    zellijPackage = lib.mkOption {
      type = lib.types.package;
      default = pinnedZellij;
      defaultText = lib.literalExpression "nixpkgs-zellij.zellij (the owned pin)";
      description = ''
        The zellij placed on the daemon's PATH. Defaults to nix-terminal's owned
        pin so the web terminal matches the rest of the environment. Override to
        `config.nix-terminal.zellij.package` on a host that enables that module.
      '';
    };

    # Passthrough overrides — null means "use the zelligate module's own default"
    # so defaults live in exactly one place (zelligate/modules/zelligate-hm.nix).
    workspaceDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Override the scanned workspace dir (ZELLIGATE_WORKSPACE_DIR).";
    };
    stateDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Override the runtime/state dir (ZELLIGATE_STATE_DIR).";
    };
    indexPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Override the index/launcher port.";
    };
    portRangeStart = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Override the first per-repo port.";
    };
    portRangeEnd = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Override the last per-repo port.";
    };
    scanInterval = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Override the reconcile scan interval (seconds).";
    };
    publicHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "tower.tailnet-name.ts.net";
      description = "The tower's Tailscale MagicDNS name for repo URLs (ZELLIGATE_PUBLIC_HOST).";
    };
    indexEnabled = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Override whether the index/launcher page is served.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.zelligate = lib.mkMerge [
      {
        enable = true;
        package = cfg.package;
        zellijPackage = cfg.zellijPackage;
      }
      (lib.mkIf (cfg.workspaceDir != null) { workspaceDir = cfg.workspaceDir; })
      (lib.mkIf (cfg.stateDir != null) { stateDir = cfg.stateDir; })
      (lib.mkIf (cfg.indexPort != null) { indexPort = cfg.indexPort; })
      (lib.mkIf (cfg.portRangeStart != null) { portRangeStart = cfg.portRangeStart; })
      (lib.mkIf (cfg.portRangeEnd != null) { portRangeEnd = cfg.portRangeEnd; })
      (lib.mkIf (cfg.scanInterval != null) { scanInterval = cfg.scanInterval; })
      (lib.mkIf (cfg.publicHost != null) { publicHost = cfg.publicHost; })
      (lib.mkIf (cfg.indexEnabled != null) { indexEnabled = cfg.indexEnabled; })
    ];
  };
}
