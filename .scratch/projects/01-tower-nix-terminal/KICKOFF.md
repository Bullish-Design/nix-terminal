# KICKOFF — nix-terminal: swap nixvim→nix-nvim, add zellij, reach .dotfiles parity

You are extending **nix-terminal** (existing HM terminal-env flake) for the
**Tower Dotfiles** project. This is a CONTEXT packet — implement when this slice
is scheduled.

- Master plan (source of truth): `~/.dotfiles/.scratch/projects/37-tower-dotfiles/PLAN.md`
- Maps to **Phase 1** (shared base parity + canonical nvim).
- Decision log: `~/.claude/projects/-home-andrew--dotfiles/memory/tower-dotfiles-project.md`

## Role

nix-terminal = the Home Manager terminal environment (shell · atuin · tmux ·
zellij · → nvim). Consumed by `nix-meta` `profiles.developer` (both machines).
Two changes this project: (1) **replace the `nixvim` flake input with `nix-nvim`**
(new repo, extracted from `.dotfiles/nvim`); (2) **reach parity** with
`~/.dotfiles/{shell,tmux,zellij,git,scripts,kitty}`, adding a **zellij** module
(today only tmux exists; the project standardizes on zellij).

## Current shape (read first)

- `flake.nix` inputs: `nixvim`, `devman`, `nixbuild`, `repoman`. Outputs
  `homeManagerModules.{terminal,nixbuild,repoman,tmux,development,scripts}`.
- `AGENTS.md` documents the module pattern: options under `programs.nix-terminal.*`,
  each module = `options.nix` / `config.nix` / `default.nix`, guarded by
  `mkIf cfg.enable`.
- `modules/`: `atuin/`, `zsh/`, `tmux/`, `development/`, `scripts/`, `terminal.nix`.

## Work items (target paths in this repo)

1. **Swap nvim source.** In `flake.nix` replace the `nixvim` input with
   `nix-nvim` (`github:Bullish-Design/nix-nvim`, exposes
   `homeManagerModules.neovim` / `.default`); update the consumer in
   `modules/terminal.nix` (it currently `inherit nixvim`). Retire the nixvim
   input entirely.
2. **Add `modules/zellij/`** (`options.nix`/`config.nix`/`default.nix` per the
   AGENTS pattern, export in `flake.nix`) at parity with `~/.dotfiles/zellij`.
3. **Parity passes** mapping `.dotfiles` → modules:
   - `~/.dotfiles/shell/*`   → `modules/zsh/` (+ `modules/atuin/`)
   - `~/.dotfiles/tmux/*`    → `modules/tmux/`
   - `~/.dotfiles/zellij/*`  → `modules/zellij/` (new)
   - `~/.dotfiles/git/*`     → git config (new module or `terminal.nix`)
   - `~/.dotfiles/scripts/*` → `scripts/` (packaged via `modules/scripts/`)
   - `~/.dotfiles/kitty/*`   → kitty stays **laptop-side**; ship `kitty.terminfo`
     for the headless tower (pairs with a `nixos-core`/system concern — note it).

**Done when:** `homeManagerModules.terminal` pulls nvim from `nix-nvim`, exposes a
`zellij` module, and a built HM profile matches `~/.dotfiles` terminal-env
behavior.

## Source material (port FROM)

`~/.dotfiles/{shell,tmux,zellij,git,scripts,kitty}` — enumerate each subdir when
porting; map to the module targets above.

## Dependencies / integration

- **Consumes** `nix-nvim` (new) + `nixbuild` + `repoman` + `devman`.
- **Consumed by** `nix-meta` `profiles.developer`.
- **Retire** the `nixvim` input/repo after cutover.

## Open / research items (PLAN §5/§10)

- Carry `.dotfiles` nixpkgs pins (zellij, neovim 0.12, …) so they don't regress —
  coordinate with `nix-meta` (where pins are centralized) and `nix-nvim` (which
  may already pin neovim).
- zellij lacks the kitty graphics protocol → inline images out of scope
  (text-in-zellij; images out-of-band).

## Rules

- Match the existing `programs.nix-terminal.*` namespace + module pattern.
- Do not add AI-authorship trailers anywhere.
- Packet/implementation only touches nix-terminal; `~/.dotfiles` is the read-only
  extraction source.
