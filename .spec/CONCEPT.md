# CONCEPT.md

## Vision

A self-sustaining NixOS ecosystem where a single Windows/WSL2 machine acts as a centralized build
server and binary cache, enabling instant, consistent deployments across all devices with minimal
bandwidth and build time.

## Problem Statement

**Traditional NixOS deployment challenges:**
- Every machine rebuilds identical packages, wasting time and resources
- Fresh installs require downloading/building everything from scratch
- No centralized control over when builds happen
- Inconsistent environments across machines
- Complex setup for new devices

## Solution

A three-tier architecture:

### 1. Build Server (WSL2)
Single always-on machine that:
- Monitors for `nix-terminal` repository changes
- Builds all dependencies on demand via HTTP API
- Serves pre-built packages to other machines via Tailscale
- Eliminates redundant builds across your infrastructure

### 2. Bootstrap Configuration (atuin-bootstrap flake)
Unified configuration flake providing:
- **Atuin integration** - The critical synchronization layer that makes all machines feel like one
- Build server client tools (trigger, status, logs)
- Common aliases and scripts synced via Atuin
- Service defaults (Syncthing, Tailscale) with per-machine customization
- Automatic cache configuration
- Template-based machine profiles
- Zero-config new machine setup

### 3. Terminal Environment (nix-terminal flake)
Core terminal configuration that:
- Provides consistent shell environment (zsh, atuin, neovim)
- Integrates with bootstrap for build server access
- Works identically across all machines

## The Central Role of Atuin

Atuin transforms this from "multiple configured machines" into "one distributed computing environment":

**Command continuity:**
Every command you run is immediately searchable on every other machine. Trigger a build on your
laptop, check its status from your desktop using the exact same command from history.

**Knowledge distribution:**
When you discover a useful command on one machine, it's instantly available everywhere. No more
"what was that command I used last week on my other laptop?"

**Workflow synchronization:**
Aliases defined in atuin-bootstrap are universal. Scripts installed via the flake are identical.
Your muscle memory works everywhere because Atuin ensures consistency.

**Context preservation:**
Atuin tracks not just commands but context - which directory, what the exit status was, when it
ran. This context travels with you across machines.

**Build server integration:**
The build server commands (`bt`, `bs`, `bl`) are synced via Atuin. Run them once anywhere,
they're in your history everywhere. This makes the distributed build system feel native and
immediate rather than remote and separate.

## Key Benefits

**For daily use:**
- **Unified command experience via Atuin** - All commands immediately available on all machines
- One command (`bt`) triggers builds from anywhere, instantly searchable everywhere
- Pre-built packages = instant installations
- Shell history, aliases, and workflows synchronized in real-time
- Consistent environment everywhere
- Context-aware history (search by directory, exit status, etc.)

**For new machines:**
- Run `bootstrap-new-machine`
- Import atuin-bootstrap + nix-terminal
- Instant access to cached builds and shared configuration
- Full command history available immediately
- All aliases and scripts synchronized via Atuin

**For service configuration:**
- Syncthing, Tailscale configured by default
- Per-machine customization without forking base config
- Secrets kept separate from version control
- Template-based profiles for common machine types

**For maintenance:**
- Single source of truth (WSL2 server)
- Controlled build timing
- Centralized cache management
- Automatic garbage collection

## Use Cases

1. **New laptop setup:** Bootstrap script + one rebuild = fully configured system
2. **Testing configurations:** Trigger build remotely, pull from cache on test machine
3. **Multiple machines:** All use same cache, build once, deploy everywhere
4. **Low-bandwidth environments:** Download pre-built binaries instead of building
5. **Consistent development:** Same packages, same versions, everywhere

## Architecture Philosophy

**Atuin as the unifying layer:**
Atuin isn't just a shell history tool - it's the synchronization backbone that makes multiple
machines feel like a single, continuous computing environment. Every command, every alias, every
workflow is instantly available everywhere. When you trigger a build on one machine, that command
is immediately searchable on all others. This creates a seamless experience where knowledge and
muscle memory transfer instantly.

**Layered configuration:**
Three layers of configuration provide flexibility without complexity:

1. **Base defaults** (atuin-bootstrap): Sensible defaults for services like Syncthing, Tailscale
2. **Per-machine overrides** (host configs): Customize paths, folders, device-specific settings
3. **Secrets** (gitignored files): API keys, device IDs, authentication tokens

This approach means new machines work immediately with defaults, but can be customized without
touching the base flake. Machine-specific configurations live in host files, not scattered across
modules.

**Declarative infrastructure:**
Everything defined in Nix flakes - reproducible, version-controlled, shareable.

**Separation of concerns:**
- Build server: one job (build and cache)
- Bootstrap: configuration distribution
- Terminal: user environment

**Network-first design:**
Tailscale provides secure, zero-config networking. No exposed ports, no VPN complexity.

**Progressive enhancement:**
Works without build server (uses official cache), better with it.

## Future Extensions

- GitHub webhook integration for automatic builds on push
- Multi-architecture support (ARM builds)
- Additional bootstrap scripts for different workflows
- Integration with more specialized flakes (development environments, etc.)
- Build server monitoring and alerting
