# Neovim portability: vault paths and remote clipboard support

## Overview

The shared Neovim configuration is packaged by `nix-nvim`, consumed by
`nix-terminal`, and then locked by each NixOS/Home Manager consumer. This
separates the editor's immutable Lua runtime from machine-local state such as
`vim.pack` plugins, Neovim state, and desktop integrations.

Two host-dependent assumptions in the shared runtime caused trouble on the
headless server:

1. The Obsidian integration assumed that `~/Documents/Notes` already existed.
   `obsidian.nvim` rejects workspace paths that are absent, so an empty or new
   host failed during Neovim startup with “At least one workspace is required”.
2. The runtime unconditionally sets `clipboard=unnamedplus`. On a headless SSH
   host there is no X11/Wayland clipboard provider (`wl-copy`, `xclip`, or
   `xsel`), which produces the “clipboard: No provider” warning and does not
   copy to the client machine's desktop clipboard.

These are portability issues, not a failure of the server's Neovim binary or
the Obsidian desktop application. The configured component is the
`obsidian.nvim` Neovim plugin; the Obsidian desktop app is not installed or
declared by the server configuration.

## Current architecture and state

```text
nix-nvim
  ├─ packages the Lua runtime and Neovim wrapper
  ├─ defines nix-nvim.neovim.* options
  └─ reads LOCI_OBSIDIAN_VAULT in productivity/obsidian.lua
       ↓
nix-terminal
  ├─ imports nix-nvim.homeManagerModules.neovim
  └─ enables the wrapper as `nv`
       ↓
nix-meta / framework host configuration
  ├─ locks a nix-terminal revision
  └─ applies host-specific Home Manager settings
```

The shared module now defines:

```nix
nix-nvim.neovim.obsidian.vaultPath
```

Its default is `${config.home.homeDirectory}/Notes`. The wrapper exports that
value as `LOCI_OBSIDIAN_VAULT`, and the Lua startup code creates the directory
when it does not already exist. A fresh server can therefore start Neovim and
gets `~/Notes` without a manual bootstrap step.

## Desired host behavior

| Host/session | Vault path | Clipboard behavior |
| --- | --- | --- |
| Server over SSH | `~/Notes` | Copy to the local client using OSC 52 when supported; do not require a server desktop provider. |
| Framework desktop | `~/Documents/Notes` | Use the local Wayland clipboard provider (`wl-clipboard`). |
| Framework over SSH | `~/Documents/Notes` | Use OSC 52 to reach the client terminal's clipboard, not the framework desktop session. |

The framework host should explicitly override the shared default in its own
Home Manager/NixOS host module:

```nix
nix-nvim.neovim.obsidian.vaultPath = "/home/andrew/Documents/Notes";
```

Use the configured user's home directory if the framework module already has a
username variable; do not hard-code a different account name in a shared
profile.

## Clipboard mechanics over SSH

Remote Neovim cannot directly access the local machine's graphical clipboard.
SSH forwards terminal input/output, not Wayland or X11 clipboard ownership.

OSC 52 is the appropriate transport for terminal sessions:

```text
remote Neovim yank
  → OSC 52 escape sequence
  → SSH terminal stream
  → local terminal emulator
  → local system clipboard
```

Neovim 0.12 includes an OSC 52 provider. It can auto-detect compatible
terminals only when no other clipboard tool is selected and `clipboard` is
unset; it can also be selected explicitly with:

```lua
vim.g.clipboard = "osc52"
```

Copy is broadly supported. Clipboard reads/paste may be disabled by terminal
security policy, so ordinary terminal paste remains the reliable fallback.
When Neovim runs inside tmux, tmux must also be configured to pass clipboard
updates through (for example, `set -g set-clipboard on`).

## Recommendation

1. Keep the new `obsidian.vaultPath` option and directory bootstrap. It makes
   the notes integration usable on a fresh host while preserving an explicit
   per-host override mechanism.
2. Add the framework override in the actual framework host configuration so it
   continues to use `~/Documents/Notes` after adopting the shared default.
3. Replace the unconditional `clipboard=unnamedplus` assignment with provider
   selection based on the active session:

   - Prefer `wl-copy`/`wl-paste` when both a Wayland session and the provider
     are available.
   - Use `vim.g.clipboard = "osc52"` for SSH/TUI sessions with no graphical
     provider.
   - Leave `clipboard` unset if neither provider is viable, preventing a
     warning and preserving normal unnamed-register behavior.

   The provider must be selected before `clipboard` is used. A delayed
   unconditional `unnamedplus` setting defeats Neovim's OSC 52 auto-detection.
4. Do not install `wl-clipboard` on the headless server merely to silence the
   warning. Without a Wayland display/socket it cannot reach the SSH client's
   clipboard and would be the wrong abstraction boundary.
5. Treat the three repository locks as one release chain when publishing a
   shared runtime change:

   ```text
   nix-nvim commit/push
     → nix-terminal: nix flake update nix-nvim; commit/push
     → consumer: nix flake update nix-terminal; commit/push
     → nixos-rebuild switch / Home Manager switch
   ```

## Validation checklist

### Fresh/headless server

```sh
rm -rf ~/Notes  # only in a disposable test account
nv --headless '+q'
test -d ~/Notes
```

The command must exit without the Obsidian workspace error. In a normal SSH
terminal, run `:checkhealth provider` and confirm that no unavailable graphical
clipboard provider is forced.

### Framework desktop

```sh
test -d ~/Documents/Notes
nv --headless '+lua print(vim.uv.os_getenv("LOCI_OBSIDIAN_VAULT"))' '+q'
```

The printed path must be `/home/andrew/Documents/Notes`. In a Wayland session,
`wl-copy` and `wl-paste` must be on `PATH`, and a normal yank should reach the
desktop clipboard.

### SSH from framework (or another OSC 52-capable client)

1. SSH to the server and launch `nv` in a terminal that permits OSC 52.
2. Yank a short unique string in Neovim.
3. Paste with the local terminal/desktop shortcut outside Neovim.
4. If running through tmux, repeat with tmux clipboard forwarding enabled.

The pasted value must be the remote yank. If the terminal blocks OSC 52 reads,
verify copy only and use the terminal paste shortcut for inbound clipboard
content.

## Open items

- Locate the framework host's authoritative Nix configuration and add its
  `obsidian.vaultPath` override there.
- Implement and test the conditional clipboard-provider policy in `nix-nvim`.
- Cascade the newly published `nix-nvim` changes through `nix-terminal` and
  the active consumer lock before expecting the server's installed `nv` wrapper
  to change.
