# Zellij-only development workflow: Framework → SSH → dev server

## Goal

Use Zellij as the one workspace tool on both machines:

```text
Framework machine                              Development server
-----------------                              ------------------
terminal → local Zellij → SSH connection → server Zellij → project work
                                            ├─ Neovim
                                            ├─ persistent Yazi
                                            ├─ shell, tests, logs
                                            └─ popup overlays
```

The Framework machine is the client: it provides the terminal, local keyboard
shortcuts, clipboard integration, and SSH connection. The dev server holds the
repositories, language tooling, editor processes, builds, and long-running
commands.

The server-side Zellij session is the important persistent session. It survives
an SSH disconnect, so reconnecting returns to the same project, Neovim, Yazi,
and running jobs.

## What Zellij is for

Zellij is a terminal multiplexer and workspace manager. A session can split a
terminal into panes, organize them into tabs, save repeatable layouts, and show
temporary floating panes over the current layout.

For this workflow it replaces tmux completely:

- **Panes** keep an editor, shell, tests, and logs together.
- **Tabs** separate projects or working modes.
- **Sessions** preserve server work across lost Wi-Fi, laptop sleep, and closed
  local terminals.
- **Floating panes and plugins** provide popup overlay windows for short-lived
  work such as a command launcher, picker, scratch shell, or focused logs.
- **Layouts** create a known arrangement instead of rebuilding panes manually.

Zellij does not replace SSH. SSH transports the terminal connection; the
server-side Zellij session owns the durable workspace at the other end.

## Normal connection flow

Start local Zellij when you also want local panes and tabs. Open an SSH pane and
attach to the server session:

```sh
# On the Framework machine
zellij

# In a local Zellij pane (or directly in a normal terminal)
ssh dev-server -t 'zellij attach --create dev'
```

`--create` means “attach if `dev` exists; otherwise create it.” You are then
viewing the server's durable session.

You can also skip local Zellij entirely:

```sh
# On the Framework machine
ssh dev-server -t 'zellij attach --create dev'
```

That is still Zellij-only: one Zellij session on the server and no tmux. Keep
the server session as the source of truth; use a local session only when you
also need local-only panes, another SSH target, or local documentation.

Set up a concise SSH alias on the Framework machine:

```sshconfig
# ~/.ssh/config
Host dev-server
  HostName server.example.net
  User andrew
  RequestTTY force
```

Then `ssh dev-server -t 'zellij attach --create dev'` is the full entry point.
The `-t` allocates the terminal required by an interactive Zellij session.

## One project, one server session, one Neovim

Use one named Zellij session per active project. This maps directly to the goal
of one Neovim instance per project and makes reconnection predictable:

```sh
# From the Framework machine
ssh dev-server -t 'zellij attach --create api'
ssh dev-server -t 'zellij attach --create website'

# Or after SSHing normally, on the server
zellij attach --create api
```

Inside the `api` session, start Neovim once at the repository root:

```sh
cd ~/src/api
nv .                 # use nvim . if that is the installed command
```

Leave that pane running. Use Yazi, a Neovim file picker, or `:edit` to move
between files in the repository. A different repository gets a different
session and Neovim process.

## Recommended project layout

Keep a narrow, persistent Yazi pane on the left, use the center/right for
Neovim, and reserve a bottom pane for commands that should remain visible:

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

| Pane | Purpose | Persistence |
| --- | --- | --- |
| Left | `yazi ~/src` or the project-parent directory | Keep it running for the session. |
| Main | `nv .` at the project root | One instance per project session. |
| Bottom right | Git, tests, dev server, and logs | Reuse or split as needed. |

Open Yazi at the directory containing all repositories so it is a navigation
hub:

```sh
yazi ~/src
```

When Yazi enters another repository, use it to choose where to work, then
switch to—or create—the Zellij session for that repository. This preserves the
one-project/one-Neovim rule.

## Collapsing the left Yazi pane

Keep the Yazi pane narrow by default. When you need more editor space, focus
the pane and use Zellij's pane-management mode to hide or close it; restore or
recreate it when navigation is needed. Default keybindings can vary by version
and configuration, so use the session's keybind help to identify the current
binding and assign a dedicated shortcut once the workflow is settled.

Two useful approaches:

1. **Simple:** hide or close the left pane, then open another left split running
   `yazi ~/src` when needed. Closing ends that Yazi process.
2. **Stateful:** place Yazi in its own Zellij tab or a separate `navigator`
   session. Switching away hides it without killing it, preserving its directory
   and selection.

Start with the simple option. Use the second when retaining Yazi's exact state
matters more than keeping it physically visible on the left at all times.

## Popup overlay windows

Zellij floating panes are terminal panes drawn over the current layout. Use
them for tasks that should not permanently consume editor space:

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

Good popup roles include:

- a temporary shell for one-off Git or Nix commands;
- a focused test or log window;
- Zellij's built-in session and layout management interface;
- plugin-provided overlays, such as a command launcher or file/session picker.

Begin with floating terminal panes rather than relying on a third-party plugin.
Add plugins only when a concrete popup workflow is missing. That keeps the
remote environment small and the core workspace usable through any SSH client.

## Repeatable server layout

After validating the interactive workflow, create a Zellij layout on the
server that starts the base panes automatically:

```text
left:   yazi ~/src
main:   cd ~/src/<project> && nv .
bottom: cd ~/src/<project> && $SHELL
```

Use a separate layout, or project-specific layout arguments, when repositories
have different startup commands. The layout belongs on the server because the
repositories and commands are there. Keep it in dotfiles or Nix configuration
so it is rebuilt consistently with the server environment.

Before formalizing it, manually assemble the layout and confirm:

1. `nv` opens at the expected root and remains in the main pane.
2. Yazi can reach every repository under `~/src`.
3. Tests or a dev server do not disrupt Neovim.
4. Detaching and reconnecting restores the same processes and panes.

## Disconnecting and returning

Do not stop the server session when you are merely leaving. Detach from it, or
allow SSH to end; the server processes continue. Return with the same command:

```sh
ssh dev-server -t 'zellij attach dev'
```

List sessions after connecting to the server:

```sh
zellij list-sessions
```

When a project is actually finished, intentionally exit or kill that Zellij
session. This stops its editor, Yazi, shells, and foreground commands.

## Practical defaults

- Install and configure the same Zellij version/configuration on both machines
  where practical. Server keybindings matter most during remote development.
- Ensure the server has Zellij, Yazi, Neovim/`nv`, Git, and required project
  toolchains through Home Manager/Nix configuration.
- Use a modern local terminal emulator for good Zellij rendering.
- Enable SSH keepalives if idle network connections are often dropped. They
  improve interactivity but do not replace server-side Zellij persistence.
- Treat Zellij as the server process-persistence layer: long-running jobs remain
  visible and manageable after reconnecting.

## Decision summary

Run **Zellij on the server for every project workspace**. Run **Zellij locally
only when you want a local multiplexer around the SSH connection**. You are not
learning two tools: both layers, when used, are Zellij; SSH is only the bridge.
