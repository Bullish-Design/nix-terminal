# AGENTS.md

## Repository Overview

**nix-terminal** is the ambient terminal Home-Manager environment for the tower
dotfiles stack: shell (zsh), multiplexer (zellij), git/delta, kitty, atuin,
packaged scripts, ambient dev CLIs, and the HM-side wiring for nixbuild + repoman
(incl. the `fleet` seam). It **consumes nix-nvim** as the editor (replacing the
retired `nixvim`) and is the sole content of nix-meta's `terminal` tier.

## Architecture

```
flake.nix  (inputs: nixpkgs · home-manager · nixpkgs-zellij 265473c9 · atuin
            v18.16.0 · nix-nvim · nixbuild · repoman · devman)
    homeManagerModules = {
      terminal     → modules/terminal.nix   (umbrella; imports nix-nvim, sets `nv`)
      shell        → modules/shell/         (zsh + oh-my-zsh devprompt + hooks)
      zellij       → modules/zellij/        (KDL set + znv; graphical bits gated)
      git          → modules/git/           (git + delta, identity = andrew)
      kitty        → modules/kitty/         (full kitty OR terminfoOnly headless)
      atuin        → modules/atuin/         (pinned v18.16.0 + daemon)
      scripts      → modules/scripts/       (scripts/shell/*.sh)
      development  → modules/development/   (ambient: gh + direnv only)
      nixbuild     → modules/nixbuild.nix
      repoman      → modules/repoman.nix    (+ the fleet seam)
      default      → aggregate (imports every sibling)
    }
```

### Namespace

Repo-root convention **`nix-terminal.<module>.*`** (e.g. `nix-terminal.zellij.enable`)
— NOT `programs.nix-terminal.*` (the old scaffold convention, now removed). Each
module gates on its **own** `cfg.enable` (decoupled from the umbrella — nix-meta
enables them individually via the tier). Modules: `options.nix` declares,
`config.nix` implements behind `mkIf cfg.enable` (single-file modules inline both).

### Pins owned here (do NOT re-pin in nix-meta; only follows-unify)

| Pin | Form |
|---|---|
| zellij | `nixpkgs-zellij` 265473c9 (a second nixpkgs node; NOT followed) |
| atuin | `atuin` v18.16.0 tag (its nixpkgs follows; the tag is the pin) |
| kitty / kitty.terminfo | rides nixpkgs |

`nixpkgs-zellij` is the only sanctioned extra nixpkgs node from this repo.

## Consumes / consumed by

- **Consumes** `nix-nvim.homeManagerModules.neovim` (path: input in dev). The
  `terminal` umbrella sets `nix-nvim.neovim.enable` + `command = "nv"`.
- **Consumed by** nix-meta's terminal tier: imports `{terminal, shell, zellij,
  git, atuin, scripts, development, nixbuild, repoman}` + `kitty` (`terminfoOnly`
  on headless). `fleetSync` capability flips `nix-terminal.repoman.fleet.enable`.
- **nixvim** is fully removed (superseded by nix-nvim).

## devenv-lib boundary

Ambient stays here (zsh/zellij/atuin/git/gh/direnv-hook/scripts/nixbuild/repoman).
**`uv`/`go` + project toolchains moved OUT** of `development` to devenv-lib —
`development` is now `gh` + direnv only.

## The repoman fleet seam

`nix-terminal.repoman.fleet.{enable,manifest,projectsDir}` is HM wiring ONLY
(materializes `repos.toml`, session vars, `rfleet`/`fleet-sync` aliases, the
projects dir). The multi-repo clone/fetch + `flake-update` CLI ships in the
repoman package (the 07-tower-repo-set-sync work); this module does not implement
fleet logic. Independent of the base `repoman.enable` (a separate mkIf block).

## Status

Built + validated (Wave 2): `nix flake check` green; modules resolve in an HM
eval; the composed activation builds (shell/zellij/git/kitty/atuin/scripts/
development + nv via nix-nvim + the fleet seam); nixvim gone; atuin pinned to
18.16.0; git identity de-hardcoded to andrew. NOTE: the `nixbuild` and base
`repoman` *packages* currently fail to build against current nixpkgs (upstream
flake/packaging drift — `devenv.lib.mkFlake` removed; repoman's `jinja2` runtime
dep undeclared); their nix-terminal *modules* are correctly wired and resolve.
