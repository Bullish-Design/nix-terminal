# shellij: declarative Zellij workbenches for local and remote development

## Purpose

`shellij` will be a dedicated Nix flake for the Zellij configuration, layouts,
scripts, and conventions that make up the interactive development workspace.
It is intentionally separate from `nix-terminal`:

- `nix-terminal` remains the broad terminal-oriented Home Manager profile.
- `shellij` owns the personal Zellij workbench: session entry points, panes,
  layouts, Yazi navigation, popup overlays, and project-specific startup logic.
- A consumer host configuration imports both modules, so each can evolve and be
  pinned independently.

The name is a combination of “shell” and “Zellij.” Its job is not to replace
SSH, Neovim, Yazi, or Nix; it composes them into a durable and repeatable
terminal workspace.

## Desired outcome

All development runs on the dev server. The Framework machine is the terminal
client and SSH entry point. The persistent workspaces live on the server.

```text
Framework machine                                  Development server
-----------------                                  ------------------
terminal emulator                                  repositories and toolchains
  └─ optional local Zellij                          └─ Zellij session per project
       └─ SSH ────────────────────────────────────────┬─ Neovim
                                                       ├─ persistent Yazi
                                                       ├─ shell / tests / logs
                                                       └─ floating popup panes
```

The server-side Zellij session is the source of truth. It survives a dropped
SSH connection, laptop sleep, or closing the Framework terminal. Reconnecting
returns to the same Neovim process, directory navigator, panes, and jobs.

There is no tmux in this design. If a local multiplexer is useful, it is also
Zellij; SSH is only the bridge between the local terminal and the server.

## What Zellij provides

Zellij is the terminal multiplexer and workspace manager underlying shellij.
It supplies:

- **Panes** for a visible editor, shell, tests, and logs at once.
- **Tabs** for alternate views without creating additional terminal windows.
- **Sessions** that keep server processes alive across disconnection.
- **Layouts** that build the expected workspace without manually splitting
  panes after every login.
- **Floating panes and plugins** for temporary popup overlay windows.

shellij packages and configures those primitives around an opinionated remote
development workflow. It should not hide normal Zellij behavior; a user must
still be able to create, split, resize, close, and navigate ordinary panes.

## Operating model

### Server: the durable workbench

Run one named Zellij session per active project on the development server:

```sh
zellij attach --create api
zellij attach --create website
```

Each project session starts one Neovim instance at that repository's root and
leaves it running. This avoids several editor processes for the same project
while keeping different repositories cleanly isolated.

Within a project, move between files with Neovim, Yazi, or `:edit`; do not
start a fresh Neovim just to reach another file. To work on another repository,
switch to—or create—that repository's shellij/Zellij session.

### Framework machine: the client

The fastest path directly attaches to a server workspace:

```sh
ssh dev-server -t 'zellij attach --create api'
```

The Framework machine can also run a local Zellij session first when it needs
local-only panes or tabs:

```sh
# Framework machine
zellij

# one local pane
ssh dev-server -t 'zellij attach --create api'
```

Both forms use Zellij exclusively. Local Zellij is optional; server Zellij is
the persistent layer that matters for remote development.

Configure a concise SSH alias on the Framework machine:

```sshconfig
# ~/.ssh/config
Host dev-server
  HostName server.example.net
  User andrew
  RequestTTY force
```

`-t` allocates the interactive terminal required by Zellij. The alias's actual
hostname and account remain host-specific configuration, not shellij defaults.

## Default project workspace

A shellij project layout should create three base panes:

```text
┌──────────────┬──────────────────────────────────────────┐
│              │                                          │
│   Yazi       │              Neovim                      │
│   (left)     │          ~/src/api                       │
│              │                                          │
│              ├──────────────────────────────────────────┤
│              │ shell · tests · logs                     │
└──────────────┴──────────────────────────────────────────┘
```

| Pane | Startup command | Responsibility |
| --- | --- | --- |
| Left | `yazi ~/src` | Persistent navigator for all repositories. |
| Main | `cd ~/src/<project> && nv .` | The one Neovim instance for that project. |
| Bottom right | `cd ~/src/<project> && $SHELL` | Git, tests, builds, dev server, and logs. |

`~/src` is an example only. shellij must accept a `projectsRoot` option rather
than hard-code a user name or directory. Likewise, the editor command should
be configurable; the current terminal profile uses `nv`, while a host may use
`nvim`.

Yazi should open at the project parent directory instead of only the active
repository. It then acts as a durable navigation hub. Entering another
repository in Yazi is a cue to attach/create that project's session, preserving
the one-project/one-Neovim model.

## Collapsible and persistent Yazi

The left Yazi pane should stay narrow by default. When more editor space is
needed, shellij should provide a discoverable binding or command to hide it and
another to restore it.

There are two valid levels of persistence:

1. **Reopenable left pane:** hide or close the Yazi pane and recreate it with
   `yazi <projectsRoot>` when needed. This is straightforward, but closing it
   loses Yazi's current selection and process state.
2. **Stateful navigator:** keep Yazi in a dedicated Zellij tab or named
   `navigator` session. Switching away hides it without killing it, preserving
   the current path and selection.

shellij should begin with the first approach because it keeps each project
layout simple. It should offer the second as an opt-in profile once preserving
Yazi state proves valuable. In both cases, the navigation command and root
directory should be centralized in shellij rather than copied between layouts.

## Popup overlays

Zellij floating panes are shellij's modal/popup mechanism. They are terminal
panes drawn over the current layout and should be used for short-lived work that
does not deserve a permanent split:

```text
┌────────────────────────────────────────────────────────┐
│ left Yazi │                 Neovim                       │
│           │      ┌────────────────────────────┐          │
│           │      │ popup: scratch shell       │          │
│           │      │ command / picker / logs    │          │
│           │      └────────────────────────────┘          │
│           │ shell / tests                                 │
└────────────────────────────────────────────────────────┘
```

Initial useful overlays:

- a scratch shell for one-off Git, Nix, or diagnostic commands;
- a focused test or log view that can be dismissed afterward;
- Zellij's own session/layout management UI;
- optional plugin-provided command, file, or session pickers.

Floating terminal panes are the baseline. Third-party plugins should be added
only where they supply a specific missing interaction, so the fundamental
remote workflow remains reliable over plain SSH and does not become dependent
on a plugin ecosystem.

## Repository shape

```text
shellij/
├── flake.nix
├── README.md
├── modules/
│   └── default.nix             # Home Manager options + implementation
├── config/
│   └── config.kdl              # base Zellij keybinds and behavior
├── layouts/
│   ├── project.kdl             # editor + Yazi + shell base layout
│   └── navigator.kdl           # optional stateful navigator layout
├── scripts/
│   ├── shellij-project         # attach/create a project workspace
│   ├── shellij-navigator       # open or focus the Yazi navigator
│   └── shellij-popup           # open defined floating-pane actions
└── docs/
    └── architecture.md
```

The scripts should be installed declaratively, ideally with Nix wrappers that
put required executables on `PATH`. Shellij must not depend on ambient aliases
or manually copied scripts.

## Flake and module contract

shellij should export a reusable Home Manager module:

```nix
{
  outputs = { self, ... }: {
    homeManagerModules.default = import ./modules;
    homeManagerModules.shellij = import ./modules;
  };
}
```

Use a dedicated option namespace to avoid colliding with upstream Home Manager
Zellij options:

```nix
programs.shellij = {
  enable = true;
  role = "server";             # "server", "client", or a future shared role
  projectsRoot = "/home/andrew/src";
  editorCommand = "nv";
  defaultSession = "dev";
  enableNavigator = true;
  navigatorMode = "reopenable"; # or "stateful"
  enablePopups = true;
};
```

The module should use `mkIf cfg.enable` and provide these effects:

- install `zellij`, `yazi`, the configured editor command's package where
  shellij owns it, and shellij helper scripts;
- place the generated or sourced Zellij KDL config under
  `~/.config/zellij/`;
- install layouts under `~/.config/zellij/layouts/`;
- make project root, editor command, role, and optional integrations available
  to scripts without hard-coding host paths;
- avoid enabling unrelated terminal defaults, aliases, or server services.

`role = "server"` should activate persistent project layouts and server entry
commands. `role = "client"` can install only the local Zellij configuration and
an SSH helper command such as `shellij-connect api`; it must not assume the
projects themselves are present locally.

## Integration with the existing modular Nix configuration

The cleanest integration is at the consuming NixOS/Home Manager flake, which
already imports `nix-terminal`. Add shellij as a separate flake input:

```nix
inputs.shellij = {
  url = "git+ssh://git@github.com/Bullish-Design/shellij.git";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Import both modules in the relevant Home Manager configuration:

```nix
imports = [
  inputs.nix-terminal.homeManagerModules.terminal
  inputs.shellij.homeManagerModules.default
];

programs.nix-terminal.enable = true;

programs.shellij = {
  enable = true;
  role = "server";
  projectsRoot = "/home/andrew/src";
  editorCommand = "nv";
};
```

The Framework host imports the same module with client-specific values:

```nix
programs.shellij = {
  enable = true;
  role = "client";
  defaultSession = "dev";
};
```

Host-specific SSH details should remain in the Framework host's SSH
configuration. Server-specific repository roots and development packages should
remain in the server host configuration. The shellij module supplies the shared
behavior and assets; host modules choose the machine-specific values.

### Optional nix-terminal seam

`nix-terminal` does not need to own a shellij dependency. Importing both at the
consumer is preferable because shellij is personal and likely to evolve faster.

If a standard fleet-facing seam later becomes useful, `nix-terminal` can add a
small wrapper analogous to its existing `zelligate` module:

```nix
{ shellij }:
{ ... }:
{
  imports = [ shellij.homeManagerModules.default ];
}
```

That wrapper should only import the module or set `mkDefault` values. The
actual layouts, scripts, options, and behavior remain owned by shellij.

`zelligate` remains separate: it is an existing Zellij web-workbench/service
integration. Shellij is the interactive developer workstation configuration.
Keeping those responsibilities separate avoids turning the personal shell
workspace into a server service dependency.

## Configuration and ownership boundaries

| Concern | Owner |
| --- | --- |
| Base terminal packages, Zsh, Atuin, common Neovim enablement | `nix-terminal` |
| Zellij KDL, layouts, helper scripts, Yazi workflow, overlays | `shellij` |
| Repositories, SSH host names, user paths, server toolchains | consuming host configuration |
| SSH transport and authentication | SSH configuration and secrets management |
| Browser-accessible Zellij service | `zelligate`, when explicitly desired |

This split makes it clear where a change belongs. A popup binding or project
layout is a shellij change; changing the server address is not.

## Session lifecycle

Use a single command as the normal entry point, eventually supplied by shellij:

```sh
# Framework machine
shellij-connect api

# conceptual implementation
ssh dev-server -t 'shellij-project api'
```

On the server, `shellij-project api` resolves the repository and executes the
equivalent of:

```sh
zellij attach --create api
```

The project layout starts Yazi, Neovim, and a shell on first creation. On a
later connection, the already-running session is attached unchanged.

To return after an interruption:

```sh
ssh dev-server -t 'zellij attach api'
```

To inspect sessions on the server:

```sh
zellij list-sessions
```

When work is actually finished, intentionally exit or kill the project session.
That stops its Neovim, Yazi, shells, and foreground jobs. Do not kill it merely
because the SSH connection ended.

## Implementation order

1. Create the shellij flake and export an empty, enabled-by-option Home Manager
   module.
2. Install Zellij and Yazi, source a minimal KDL configuration, and validate it
   on the development server.
3. Add the base project layout: left Yazi, main Neovim, and bottom shell.
4. Add `shellij-project` to attach/create named project sessions.
5. Add the Framework `shellij-connect` helper and SSH alias.
6. Add a documented floating scratch-shell popup, then focused log/test popup
   actions.
7. Add the opt-in stateful navigator only if the reopenable Yazi pane proves
   insufficient.
8. Pin shellij from the consumer flake, rebuild both hosts, and verify a full
   disconnect/reconnect cycle.

## Validation checklist

### Server

1. Rebuild the server Home Manager configuration.
2. Run `shellij-project api` from a server shell.
3. Confirm the project layout opens Yazi, `nv .`, and a bottom shell in the
   expected directories.
4. Start a long-running test or dev server in the bottom pane.
5. Disconnect without exiting Zellij, reconnect, and verify all panes and
   processes remain present.

### Framework machine

1. Rebuild the Framework Home Manager configuration.
2. Run `shellij-connect api` (or the direct SSH attach command).
3. Confirm local terminal key handling, colors, and remote Zellij rendering.
4. If local Zellij is enabled, confirm an SSH pane can attach to the server
   session without affecting local panes.
5. Verify that a remote Neovim yank uses the intended SSH/terminal clipboard
   workflow; server Zellij must not be mistaken for a graphical clipboard
   provider.

### Workflow

1. Use Yazi to navigate under the project root.
2. Hide and restore the navigation pane, checking the selected persistence mode.
3. Open and dismiss each defined popup overlay.
4. Attach to a second project and verify it has a separate Neovim process.
5. Reattach to the first project and verify its original editor state is still
   available.

## Decisions to preserve

- Zellij only; no tmux layer.
- The dev server, not the Framework machine, owns active development processes.
- One server-side Zellij session and Neovim process per project.
- A left-side Yazi navigator is part of the standard workspace.
- Popup overlays are available without permanently shrinking the editor pane.
- Local Zellij is optional; server Zellij is required for persistence.
- Shellij is standalone and reusable, while its Nix integration remains a
  normal Home Manager module import.
