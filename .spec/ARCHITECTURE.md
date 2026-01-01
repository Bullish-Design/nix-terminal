# ARCHITECTURE.md

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Tailscale Network                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │  Laptop A    │    │  Laptop B    │    │  Desktop     │      │
│  │  (client)    │    │  (client)    │    │  (client)    │      │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘      │
│         │                   │                   │               │
│         │ HTTP :8000 (API)  │                   │               │
│         │ HTTP :5000 (Cache)│                   │               │
│         └───────────────────┴───────────────────┘               │
│                             │                                    │
│                   ┌─────────▼─────────┐                         │
│                   │  WSL2 Build Server│                         │
│                   │  - FastAPI        │                         │
│                   │  - Harmonia Cache │                         │
│                   │  - Build Service  │                         │
│                   └───────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
```

## Layered Configuration System

### Configuration Hierarchy

The system uses a three-layer configuration approach that balances standardization with flexibility:

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Base Defaults (atuin-bootstrap)                   │
│ - Service defaults (Syncthing, Tailscale)                  │
│ - Common folder structures                                 │
│ - Universal aliases and scripts                            │
│ - Build server integration                                 │
└─────────────────────────────────────────────────────────────┘
                           ↓ Merged with
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Per-Machine Overrides (host configs)              │
│ - Machine-specific paths                                   │
│ - Custom folder selections                                 │
│ - Device-specific settings                                 │
│ - Template selection (desktop, laptop, server)             │
└─────────────────────────────────────────────────────────────┘
                           ↓ Combined with
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Secrets (gitignored)                              │
│ - API keys                                                  │
│ - Device IDs                                                │
│ - Authentication tokens                                     │
│ - Sync keys                                                 │
└─────────────────────────────────────────────────────────────┘
```

### Implementation Pattern

**Base Module (atuin-bootstrap/modules/services.nix):**
```nix
{ config, lib, ... }:
let cfg = config.services.bootstrap-services;
in {
  options.services.bootstrap-services = {
    syncthing = {
      enable = lib.mkEnableOption "syncthing";

      defaultFolders = lib.mkOption {
        type = lib.types.attrs;
        default = {
          documents = {
            path = "\${config.home.homeDirectory}/Documents";
            devices = [ "laptop" "desktop" ];
          };
          dotfiles = {
            path = "\${config.home.homeDirectory}/.config";
            devices = [ "laptop" "desktop" "server" ];
          };
        };
      };

      folders = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "Additional or override folders";
      };
    };

    tailscale = {
      enable = lib.mkEnableOption "tailscale" // { default = true; };
      authKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Auth key from secrets";
      };
    };
  };

  config = lib.mkIf cfg.syncthing.enable {
    services.syncthing = {
      enable = true;
      user = config.home.username;
      dataDir = "\${config.home.homeDirectory}/.syncthing";

      settings.folders = cfg.defaultFolders // cfg.folders;
    };
  };
}
```

**Per-Machine Override (hosts/laptop/home.nix):**
```nix
{ ... }:
let secrets = import ../../secrets/laptop.nix;
in {
  services.bootstrap-services = {
    syncthing = {
      enable = true;
      folders = {
        # Add laptop-specific folder
        photos = {
          path = "/mnt/external/photos";
          devices = [ "desktop" ];
        };
        # Override default path
        documents.path = "/custom/docs";
      };
    };

    tailscale.authKey = secrets.tailscale.authKey;
  };
}
```

**Secrets File (secrets/laptop.nix - gitignored):**
```nix
{
  syncthing = {
    deviceId = "LAPTOP-7X3Y...";
    devices = {
      desktop = "DESKTOP-2A9B...";
      server = "SERVER-4F1K...";
    };
  };

  tailscale.authKey = "tskey-auth-...";

  buildServer.publicKey = "build-server:AbCdEf...";
}
```

### Template System

**Common machine profiles:**

```nix
# atuin-bootstrap/templates/laptop.nix
{
  syncthingFolders = [ "documents" "code" "dotfiles" ];
  services = [ "tailscale" "syncthing" ];
  lowPowerMode = true;
}

# atuin-bootstrap/templates/desktop.nix
{
  syncthingFolders = [ "documents" "photos" "music" "videos" ];
  services = [ "tailscale" "syncthing" ];
  performanceMode = true;
}

# atuin-bootstrap/templates/server.nix
{
  syncthingFolders = [ "dotfiles" "backups" ];
  services = [ "tailscale" ];
  headless = true;
}
```

**Usage:**
```nix
# hosts/my-laptop/home.nix
{ inputs, ... }:
{
  imports = [
    inputs.atuin-bootstrap.templates.laptop
    inputs.atuin-bootstrap.homeManagerModules.default
  ];

  # Template provides defaults, override as needed
  services.bootstrap-services.syncthing.folders.photos = {
    path = "/mnt/sd-card/photos";
    devices = [ "desktop" ];
  };
}
```

### Benefits

**For new machines:**
- Import base module → working defaults immediately
- Apply template → appropriate service configuration
- Add secrets → full functionality

**For maintenance:**
- Update base module → all machines get improvements
- Update host config → only affects that machine
- Secrets stay local, never committed

**For flexibility:**
- Easy per-machine customization without forking
- Clear separation of concerns
- Templates provide starting points, not constraints

## Atuin: The Synchronization Backbone

### Architecture Role

Atuin is not merely a history tool - it's the layer that transforms independent machines into a
unified computing environment. Every other component benefits from Atuin's synchronization:

**Build server commands:**
- `bt` (trigger build) synced across all machines
- History shows when builds were triggered, from where
- Quick recall of status checks, log queries

**Configuration commands:**
- `rebuild`, `system-update` immediately available everywhere
- No need to remember syntax - it's in history
- Context preserved (which directory, what failed/succeeded)

**Knowledge transfer:**
- Discover command on laptop → instantly available on desktop
- Complex Nix commands saved and searchable
- Learning persists across machines

### Data Flow

```
Machine A: User runs command
    ↓
Local shell: Command executed
    ↓
Atuin: Command recorded with context
    ↓
Atuin sync server: Command uploaded
    ↓
Machine B: Atuin syncs in background
    ↓
Machine B: Ctrl+R → Command appears in search
    ↓
User: Seamless experience across machines
```

### Integration Points

**With build server:**
```bash
# On laptop
bt  # Trigger build

# On desktop (moments later)
Ctrl+R → "bt" appears in history
bs  # Check status of build triggered from laptop
```

**With NixOS configuration:**
```bash
# Discover on desktop
nix build .#myPackage --option substituters http://build-server:5000

# Use on laptop (history synced)
Ctrl+R → "nix build" → exact command available
```

**With daily workflows:**
```bash
# Complex git command on machine A
git log --graph --pretty=format:'%h %s' --abbrev-commit

# Immediate availability on machine B via Atuin search
Ctrl+R → "git log" → same complex command
```

### Configuration

**Atuin settings (atuin-bootstrap/modules/home.nix):**
```nix
programs.atuin = {
  enable = true;
  enableZshIntegration = true;
  enableBashIntegration = true;

  settings = {
    auto_sync = true;
    sync_address = cfg.atuin.syncServer;
    sync_frequency = "5m";

    # Enhanced search
    search_mode = "fuzzy";
    filter_mode_shell_up_key_binding = "directory";

    # UI preferences
    style = "compact";
    inline_height = 20;

    # What to track
    history_filter = [
      "^secret"
      "^password"
    ];
  };
};
```

## Component Architecture

### 1. WSL2 Build Server

**Host:** Windows 11 + WSL2 + NixOS-WSL

**Services:**
```nix
systemd.services = {
  build-server    # FastAPI on :8000
  harmonia        # Binary cache on :5000
  nix-terminal-build  # Build orchestration (oneshot)
  tailscale       # Network layer
}
```

**Data Flow:**
```
API Request → build-server.py → systemctl start nix-terminal-build
                                      ↓
                              build-nix-terminal.sh
                                      ↓
                        git clone/pull → nix build → /nix/store
                                      ↓
                              status.json updated
                                      ↓
                              Harmonia serves from /nix/store
```

**Storage:**
- `/nix/store` - Built packages
- `/var/lib/harmonia/cache-key` - Signing key (600 permissions)
- `/var/lib/build-server/status.json` - Build state
- `/var/log/nix-terminal-build.log` - Build logs
- `/home/builder/builds/nix-terminal` - Git repository

### 2. Build Server API

**Framework:** FastAPI (Python)

**Endpoints:**
```python
POST /build/trigger
  → Triggers systemd service
  → Returns: {"status": "triggered|already_running", "message": "..."}

GET /build/status
  → Reads status.json
  → Checks systemctl is-active
  → Returns: BuildStatus model (is_running, last_commit, last_status, etc.)

GET /build/logs?lines=N
  → Tail build logs
  → Returns: {"logs": ["line1", "line2", ...]}

GET /health
  → Service health check
  → Returns: {"status": "healthy", "cache_running": bool}
```

**Models (Pydantic):**
```python
class BuildStatus(BaseModel):
    is_running: bool
    last_start: datetime | None
    last_finish: datetime | None
    last_status: str | None  # "success" | "failed"
    last_commit: str | None
```

### 3. Binary Cache (Harmonia)

**Protocol:** HTTP substituter protocol (Nix-native)

**Endpoints:**
```
GET /nix-cache-info
  → Returns cache metadata + public key

GET /<store-path>.narinfo
  → Returns package metadata

GET /nar/<hash>.nar.xz
  → Returns compressed package archive
```

**Signing:**
- All packages signed with server's private key
- Clients verify with public key
- Prevents MITM attacks

### 4. Atuin Bootstrap Flake

**Structure:**
```
inputs:
  nixpkgs

outputs:
  homeManagerModules.default  # Main module
  homeManagerModules.services # Service configurations (Syncthing, Tailscale)
  nixosModules.default        # System module
  packages.{system}.*         # Script packages
  overlays.default            # Package overlay
  templates.*                 # Machine type templates (laptop, desktop, server)
```

**Module Configuration:**
```nix
programs.bootstrap = {
  enable = true;

  buildServer = {
    enable = true;
    address = "build-server";  # Tailscale hostname
    publicKey = "...";
  };

  atuin = {
    enable = true;
    syncServer = "https://api.atuin.sh";  # Or self-hosted
  };
};

services.bootstrap-services = {
  syncthing = {
    enable = true;
    # defaultFolders are provided by base module
    folders = {
      # Machine-specific additions/overrides
      photos.path = "/mnt/external/photos";
      documents.path = "/custom/docs";  # Override default
    };
  };

  tailscale = {
    enable = true;
    authKey = secrets.tailscale.authKey;
  };
};
```

**Generated Package Set:**
```nix
pkgs.bootstrap-scripts = {
  build-trigger          # Wraps curl POST to :8000/build/trigger
  build-status           # Wraps curl GET to :8000/build/status | jq
  build-logs             # Wraps curl GET to :8000/build/logs | jq -r
  system-update          # Orchestrates: update → rebuild → gc
  bootstrap-new-machine  # Auto-setup for new hosts
}
```

**Atuin Integration:**
All aliases and scripts are immediately synced via Atuin:
- Run `bt` on laptop → appears in desktop's history within seconds
- Complex commands saved once, available everywhere
- Context-aware search across all machines
- Command history shows when/where builds triggered, which succeeded/failed


### 5. Nix-Terminal Flake

**Purpose:** Core terminal environment

**Exports:**
```nix
homeManagerModules = {
  terminal         # Zsh, Atuin, Neovim, tools
  build-client     # Build server integration (legacy)
  atuin-bootstrap  # Superseded by separate flake
  default          # All modules combined
}
```

**Dependencies:**
```nix
inputs = {
  nixpkgs
  home-manager
  nixvim    # Neovim config
  devman    # Dev environments
}
```

## Complete Workflow: Atuin in Action

### Scenario: Trigger Build from Laptop, Check from Desktop

**On Laptop:**
```bash
user@laptop:~$ bt
✓ Build triggered successfully

user@laptop:~$ bs
{
  "is_running": true,
  "last_start": "2025-01-15T14:30:00Z",
  "last_status": null,
  "last_commit": null
}
⏳ Build in progress...
```

**Meanwhile (seconds later) on Desktop:**
```bash
user@desktop:~$ <Ctrl+R>
# Atuin search shows:
#   bt              (laptop, 14:30:05, exit 0)
#   bs              (laptop, 14:30:12, exit 0)

user@desktop:~$ bs  # Selected from history
{
  "is_running": true,
  "last_start": "2025-01-15T14:30:00Z",
  ...
}
⏳ Build in progress...
```

**Key Points:**
1. Command run on laptop immediately synced via Atuin
2. Desktop can search and reuse exact command
3. Both machines checking same build server
4. Seamless cross-machine workflow

### Scenario: New Machine Setup with History Intact

**Bootstrap new laptop:**
```bash
# Fresh NixOS install
user@new-laptop:~$ nix run github:Bullish-Design/atuin-bootstrap#bootstrap-new-machine
==> Bootstrapping new machine
==> Creating secrets.nix...
==> Creating flake.nix...
✓ Bootstrap complete

user@new-laptop:~$ home-manager switch --flake .#default
# Downloads from build server cache (fast)
# Configures Atuin with sync

user@new-laptop:~$ <Ctrl+R>
# Immediately shows ENTIRE command history from all machines:
#   bt              (old-laptop, 2 days ago)
#   nix build .#    (desktop, yesterday)
#   system-update   (server, last week)
```

**Immediate Benefits:**
- All previous commands available instantly
- No learning curve - existing muscle memory works
- Context from other machines preserved
- Build server commands already in history

### Scenario: Service Configuration Across Machines

**Define base config (atuin-bootstrap):**
```nix
# Applied to all machines
services.bootstrap-services.syncthing = {
  enable = true;
  defaultFolders = {
    documents = { path = "~/Documents"; devices = ["laptop" "desktop"]; };
  };
};
```

**Override on specific machine:**
```nix
# hosts/desktop/home.nix
services.bootstrap-services.syncthing.folders = {
  photos = { path = "/mnt/photos"; devices = ["laptop"]; };
  documents.path = "/custom/docs";  # Override
};
```

**Result:**
- Laptop: Syncs Documents (default path)
- Desktop: Syncs Documents (/custom/docs) + Photos (/mnt/photos)
- Both configured from same base flake
- Secrets kept in gitignored files
- Atuin ensures any syncthing CLI commands work identically

## Data Flows

### Build Trigger Flow

```
Client: curl -X POST http://build-server:8000/build/trigger
  ↓
build-server.py: Validates request
  ↓
systemctl: sudo systemctl start nix-terminal-build
  ↓
build-nix-terminal.sh:
  1. Clone/update git repo (dev branch)
  2. nix flake update
  3. nix build (creates home-manager test config)
  4. Update status.json
  ↓
/nix/store: Populated with built packages
  ↓
Harmonia: Auto-serves new packages
```

### Package Installation Flow

```
Client: nix build .#somePackage
  ↓
Nix: Check local store
  ↓
Nix: Check substituters (build-server listed in nix.settings)
  ↓
Client → build-server:5000/nix-cache-info
  ↓
Client → build-server:5000/<hash>.narinfo
  ↓
Client: Verify signature with public key
  ↓
Client → build-server:5000/nar/<hash>.nar.xz
  ↓
Client: Decompress to /nix/store
```

### Bootstrap New Machine Flow

```
bootstrap-new-machine:
  1. Detect Tailscale availability
  2. Fetch public key: curl build-server:5000/nix-cache-info
  3. Generate secrets.nix with server address + key
  4. Generate flake.nix with inputs
  5. Generate home.nix with bootstrap config
  ↓
User: home-manager switch --flake .#
  ↓
Home Manager:
  1. Fetch flakes (atuin-bootstrap, nix-terminal)
  2. Evaluate configuration
  3. Check substituters (build-server first)
  4. Download pre-built packages from cache
  5. Install scripts, configure shell, setup Atuin
```

## Security Model

### Network Security
- **Tailscale:** Zero-trust overlay network
- **Firewall:** Only Tailscale interface (tailscale0) trusted
- **No public exposure:** All services localhost or Tailscale-only

### Package Security
- **Signing:** Ed25519 signatures on all cached packages
- **Verification:** Clients validate before installing
- **Trust model:** Explicit trusted-public-keys in nix.settings

### Access Control
- **Build trigger:** No authentication (Tailscale network trust)
- **Cache access:** Public read (signature-verified)
- **Build server:** sudo configured for builder user (systemctl only)

## Scalability Considerations

### Storage
- WSL2 virtual disk grows dynamically
- Automatic garbage collection weekly
- Store optimization enabled

### Network
- LAN bandwidth within Tailscale
- Cache compression (.nar.xz)
- Harmonia efficient serving

### Concurrency
- Build service is oneshot (no parallel builds)
- Cache serving: Harmonia handles multiple clients
- API: FastAPI async for concurrent requests

## Extension Points

### Adding New Scripts
```nix
# atuin-bootstrap/packages/default.nix
{
  my-script = mkScript "my-script" "my-script.sh";
}
```

### Custom Build Targets
```bash
# Modify build-nix-terminal.sh
nix build .#packages.x86_64-linux.customPackage
```

### Additional Caches
```nix
# Client nix.settings
substituters = [
  "http://build-server:5000"
  "http://other-cache:5000"
]
```

### Monitoring Integration
```python
# build-server.py
@app.get("/metrics")
async def prometheus_metrics():
    # Export Prometheus metrics
```

## Technology Stack

**Build Server:**
- NixOS (nixos-wsl)
- Python 3.11+ (FastAPI, Uvicorn, Pydantic)
- UV (Python dependency management)
- Harmonia (binary cache server)
- Git

**Networking:**
- Tailscale (mesh VPN)
- HTTP (API + Cache)

**Clients:**
- Nix (package manager)
- Home Manager (dotfile management)
- Atuin (shell history)
- Bash/Zsh

**Development:**
- Nix Flakes (reproducible builds)
- Pydantic (data validation)
- systemd (service orchestration)
