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

Zellij (the fleet multiplexer) forwards OSC 52 WRITES to the client terminal
(yanks reach the system clipboard), but does NOT answer or forward OSC 52 READS
(`zellij-server/src/panes/grid.rs`: "TBD: paste from own clipboard - currently
unsupported"). In-nvim paste (`p`) inside zellij therefore times out after ~10s
("Waiting for OSC 52 response"); use terminal paste (kitty Ctrl+Shift+V)
instead.

Kitty's default `clipboard_control` includes `read-clipboard-ask`/
`read-primary-ask`, so plain-kitty windows pop a confirmation dialog on every
OSC 52 read (paste, or — previously — yanky's focus-sync sampling). nix-desktop
ships `programs.nix-desktop.kitty.allowOsc52Read` (default on) to silently
allow reads; it also installs the noctalia launcher clipboard history, which
records every OSC 52 write from remote nvim for cross-app recall.

## Recommendation

1. Keep the new `obsidian.vaultPath` option and directory bootstrap. It makes
   the notes integration usable on a fresh host while preserving an explicit
   per-host override mechanism.
2. Add the framework override in the actual framework host configuration so it
   continues to use `~/Documents/Notes` after adopting the shared default.
3. ~~Replace the unconditional `clipboard=unnamedplus` assignment with provider
   selection based on the active session~~ **DONE 2026-08-11 (nix-nvim
   4ae2842)**. `clipboard` now defaults to `auto`: use the local graphical
   provider when the session has one (Wayland + wl-clipboard, X11 + xclip/xsel,
   pbcopy, clip.exe), otherwise fall back to the built-in OSC 52 provider. A
   display gate (`WAYLAND_DISPLAY`/`DISPLAY`) keeps headless SSH sessions on
   OSC 52 even though the nixpkgs neovim wrapper injects wl-clipboard into
   PATH.

   The other focus-change annoyance is also fixed: yanky's default-on
   `system_clipboard.sync_with_ring` sampled the `+` register on every
   FocusLost/FocusGained, which was the unsolicited read behind kitty's
   per-focus prompt and zellij's per-focus timeout. Disabled in nix-nvim; the
   ring keeps all in-nvim yanks, and cross-app recall lives in the client's
   clipboard history (noctalia/klipper).

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
4. If running through zellij, paste with the terminal shortcut (kitty
   Ctrl+Shift+V); zellij does not answer OSC 52 reads, so in-nvim `p` times
   out.

The pasted value must be the remote yank. If the terminal blocks OSC 52 reads,
verify copy only and use the terminal paste shortcut for inbound clipboard
content.

## Open items

- Locate the framework host's authoritative Nix configuration and add its
  `obsidian.vaultPath` override there (and import nix-desktop, which now ships
  the kitty `allowOsc52Read` knob, once the desktop host is restored).
- ~~Implement and test the conditional clipboard-provider policy in
  `nix-nvim`.~~ DONE 2026-08-11 (4ae2842); validated against the server's nvim
  binary in SSH, Wayland-desktop, X11, and forced-osc52 modes.
- ~~Cascade the newly published `nix-nvim` changes through `nix-terminal` and
  the active consumer lock before expecting the server's installed `nv` wrapper
  to change.~~ DONE: nix-terminal 15bbe46, nix-meta b244b93 (server dry-run
  build eval verified). Next: `nixos-rebuild switch --flake .#server` on the
  box to activate the new `nv` wrapper.
