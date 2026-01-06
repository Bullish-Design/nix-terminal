# modules/repoman.nix
{ repoman }:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.repoman;
  repomanPkg = repoman.packages.${pkgs.system}.default;
  
  configFormat = if cfg.configFormat == "yaml" then "yaml" else "toml";
  configFile = if cfg.configFormat == "yaml" then "repoman.yaml" else "repoman.toml";
in
{
  options.programs.repoman = {
    enable = lib.mkEnableOption "repoman repository manager";

    configFormat = lib.mkOption {
      type = lib.types.enum [ "yaml" "toml" ];
      default = "yaml";
      description = "Configuration file format";
    };

    baseDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/code";
      description = "Base directory for cloning repositories";
    };

    maxConcurrent = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Maximum number of concurrent git operations";
    };

    timeout = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Timeout in seconds for git operations (30-3600)";
    };

    useSsh = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use SSH for git operations instead of HTTPS";
    };

    accounts = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "GitHub account or organization name";
          };

          baseDir = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Override base directory for this account";
          };

          repos = lib.mkOption {
            type = lib.types.listOf (lib.types.either lib.types.str (lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Local directory name";
                };

                remoteName = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Remote repository name if different from local";
                };

                localDir = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Custom local directory path";
                };
              };
            }));
            description = "List of repositories to manage";
          };
        };
      });
      default = [];
      description = "GitHub accounts and their repositories";
    };

    enableShellAliases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable convenient shell aliases for repoman";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ repomanPkg ];

    xdg.configFile."repoman/${configFile}".text = 
      let
        # Convert repos list to proper format
        formatRepos = repos: map (repo:
          if builtins.isString repo
          then repo
          else {
            name = repo.name;
          } // lib.optionalAttrs (repo.remoteName != null) {
            remote_name = repo.remoteName;
          } // lib.optionalAttrs (repo.localDir != null) {
            local_dir = repo.localDir;
          }
        ) repos;

        # Format accounts
        formattedAccounts = map (account: {
          name = account.name;
          repos = formatRepos account.repos;
        } // lib.optionalAttrs (account.baseDir != null) {
          base_dir = account.baseDir;
        }) cfg.accounts;

        configData = {
          global = {
            base_dir = cfg.baseDir;
            max_concurrent = cfg.maxConcurrent;
            timeout = cfg.timeout;
            use_ssh = cfg.useSsh;
          };
          accounts = formattedAccounts;
        };
      in
        if cfg.configFormat == "yaml"
        then lib.generators.toYAML {} configData
        else lib.generators.toINI {} configData;

    # Shell aliases
    programs.bash.shellAliases = lib.mkIf (cfg.enableShellAliases && config.programs.bash.enable) {
      rsync = "repoman sync";
      rlist = "repoman list";
      rstatus = "repoman status";
    };

    programs.zsh.shellAliases = lib.mkIf (cfg.enableShellAliases && config.programs.zsh.enable) {
      rsync = "repoman sync";
      rlist = "repoman list";
      rstatus = "repoman status";
    };

    # Ensure base directory exists
    home.activation.repomanSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD mkdir -p "${cfg.baseDir}"
    '';
  };
}

