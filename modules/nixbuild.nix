# modules/nixbuild.nix
{ nixbuild }:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.nixbuild;
  nixbuildPkg = nixbuild.packages.${pkgs.system}.default;
in
{
  options.programs.nixbuild = {
    enable = lib.mkEnableOption "nixos-rebuild-tester";

    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.nixbuild-logs";
      description = "Directory where rebuild logs and artifacts are stored";
    };

    defaultAction = lib.mkOption {
      type = lib.types.enum [ "test" "build" "dry-build" "dry-activate" ];
      default = "test";
      description = "Default rebuild action";
    };

    keepLast = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = 10;
      description = "Number of builds to keep (null = keep all)";
    };

    enableRecording = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable terminal recording";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      nixbuildPkg
    ];

    home.sessionVariables = {
      NIXBUILD_OUTPUT_DIR = cfg.outputDir;
      NIXBUILD_DEFAULT_ACTION = cfg.defaultAction;
      NIXBUILD_KEEP_LAST = toString cfg.keepLast;
    };

    # Ensure output directory exists
    home.activation.nixbuildSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD mkdir -p "${cfg.outputDir}"
    '';

    # Optional: Add shell aliases for convenience
    programs.bash.shellAliases = lib.mkIf config.programs.bash.enable {
      nbtest = "nixos-rebuild-test run --output-dir ${cfg.outputDir} --keep-last ${toString cfg.keepLast}";
      nblist = "nixos-rebuild-test list-builds --output-dir ${cfg.outputDir}";
    };

    programs.zsh.shellAliases = lib.mkIf config.programs.zsh.enable {
      nbtest = "nixos-rebuild-test run --output-dir ${cfg.outputDir} --keep-last ${toString cfg.keepLast}";
      nblist = "nixos-rebuild-test list-builds --output-dir ${cfg.outputDir}";
    };
  };
}
