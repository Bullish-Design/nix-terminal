# AGENTS.md

## Repository Overview

**nix-terminal** provides modular Home Manager modules for terminal environment configuration. It's the foundation of a terminal-centric NixOS workflow, integrating zsh, atuin, tmux, and neovim.

## Architecture

```
flake.nix
    ├── homeManagerModules.terminal  → modules/terminal.nix
    ├── homeManagerModules.nixbuild  → modules/nixbuild.nix
    ├── homeManagerModules.tmux      → modules/tmux/
    ├── homeManagerModules.development → modules/development/
    └── homeManagerModules.scripts   → modules/scripts/
```

### Module Structure

Each module follows a pattern:
- `default.nix` - Imports options and config
- `options.nix` - Declares module options under `programs.nix-terminal.*`
- `config.nix` - Implements configuration when enabled

### Key Dependencies

| Input | Purpose |
|-------|---------|
| `nixvim` | Neovim configuration |
| `devman` | Development environment tools |
| `nixbuild` | NixOS rebuild testing |

## Making Changes

### Adding a New Module

1. Create `modules/<name>/default.nix` (or single file for simple modules)
2. Export in `flake.nix` under `homeManagerModules`
3. Import in `terminal.nix` if it should be part of the main terminal module
4. Document in README.md

### Module Option Pattern

```nix
# options.nix
options.programs.nix-terminal.<module> = {
  enable = mkOption {
    type = types.bool;
    default = true;
    description = "Enable <module>";
  };
  # Additional options...
};

# config.nix
config = mkIf (config.programs.nix-terminal.enable && cfg.enable) {
  # Configuration here
};
```

### Adding Shell Scripts

1. Create script in `scripts/shell/<name>.sh`
2. Scripts are automatically packaged via `modules/scripts/default.nix`
3. Installed as `<name>` (without .sh extension)

Script template:
```bash
#!/usr/bin/env bash
set -euo pipefail
# Implementation
```

## Constraints

- **Home Manager modules only**: No NixOS modules here (use nixos-core)
- **Options under `programs.nix-terminal`**: Maintain namespace consistency
- **No default aliases**: Users must explicitly configure aliases
- **Conditional configuration**: Always guard with `mkIf cfg.enable`

## Testing Changes

```bash
nix flake check

# Test in a consumer flake
nix build .#homeConfigurations.test --dry-run
```

## Integration Points

### Consumed by nix-meta

```nix
imports = [
  nix-terminal.homeManagerModules.terminal
  nix-terminal.homeManagerModules.nixbuild
];
```

### Consumes from nixbuild

The `nixbuild.nix` module wraps the nixbuild package with Home Manager options.

## Common Tasks

### Add zsh alias support for new tool
Update `modules/zsh/config.nix` in the `initExtra` section.

### Add new atuin option
1. Add option in `modules/atuin/options.nix`
2. Use in `modules/atuin/config.nix` under `programs.atuin.settings`

### Add tmux plugin
Update `modules/tmux/default.nix` plugins list with the new plugin from `pkgs.tmuxPlugins`.

### Modify starship prompt
Default settings are in `modules/terminal.nix` under `starshipSettings`. Users can override via `programs.nix-terminal.starshipSettings`.

## File Locations

| What | Where |
|------|-------|
| Main terminal module | `modules/terminal.nix` |
| Zsh config | `modules/zsh/` |
| Atuin config | `modules/atuin/` |
| Tmux config | `modules/tmux/default.nix` |
| Shell scripts | `scripts/shell/*.sh` |
| nixbuild integration | `modules/nixbuild.nix` |
