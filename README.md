# nix-terminal

A modular NixOS flake providing comprehensive terminal environment configuration with zsh, atuin, and neovim integration. This serves as the cornerstone of a terminal-only interface style within a modular collection of NixOS flakes.

## Overview

`nix-terminal` is designed to be the foundation of a terminal-centric workflow on NixOS systems. It provides a cohesive, well-configured shell environment with modern tools and sensible defaults, while remaining highly customizable.

### Philosophy

This flake is part of a modular approach to NixOS configuration:

- **nix-terminal**: Core terminal environment (this repository)
- **nixvim**: Neovim configuration (pulled as dependency)
- **devman**: Development environment management (pulled as dependency)

By separating concerns into distinct flakes, you can:
- Mix and match components based on your needs
- Version control each piece independently
- Share configurations across machines with different requirements
- Maintain a clean, focused codebase for each component

## Features

### Shell Configuration (zsh)

- **Modern prompt themes**: Choose between Starship, Powerlevel10k, or minimal
- **Intelligent autosuggestions**: Fish-like autosuggestions from history
- **Syntax highlighting**: Real-time syntax validation and highlighting
- **Enhanced completion**: Smart tab completion with fuzzy matching
- **Better navigation**: Auto-cd, directory stack, and improved globbing
- **Sensible defaults**: Optimized history, completion styling, and keybindings
- **Modern utilities**:
  - `eza` for colorful, icon-rich directory listings
  - `bat` for syntax-highlighted file viewing
  - `ripgrep` for fast searching
  - `fd` for intuitive file finding
  - `fzf` for fuzzy finding everywhere

### History Management (atuin)

- **Smart shell history**: SQLite-backed history with full-text search
- **Fuzzy search**: Find commands instantly with fuzzy matching
- **Context awareness**: Filter history by directory, exit status, and more
- **Optional sync**: Synchronize history across machines (disabled by default)
- **Statistics**: Analyze your shell usage patterns
- **Privacy-focused**: Full control over what gets tracked

### Additional Tools

- **direnv**: Automatic environment loading per directory
- **fzf**: Fuzzy finder integration for files, history, and more
- **Git integration**: Pre-configured with sensible defaults
- **Developer tools**: Via the integrated devman package

## Installation

### As a Home Manager Module

1. Add `nix-terminal` to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";

    nix-terminal = {
      url = "github:Bullish-Design/nix-terminal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

2. Import the module in your Home Manager configuration:

```nix
{ inputs, ... }:
{
  imports = [
    inputs.nix-terminal.homeManagerModules.terminal
  ];

  programs.nix-terminal.enable = true;
}
```

### Standalone Usage

You can also use this flake directly without integrating it into your system:

```bash
# Try it out temporarily
nix shell github:Bullish-Design/nix-terminal

# Install to your profile
nix profile install github:Bullish-Design/nix-terminal
```

## Configuration

The module provides extensive customization options:

### Basic Configuration

```nix
programs.nix-terminal = {
  enable = true;

  # Zsh configuration
  zsh = {
    enable = true;
    theme = "starship";  # or "powerlevel10k", "minimal"
    enableAutosuggestions = true;
    enableSyntaxHighlighting = true;
    enableCompletion = true;

    # Add custom aliases
    aliases = {
      vim = "nvim";
      k = "kubectl";
      tf = "terraform";
    };

    # Add extra configuration
    extraConfig = ''
      # Your custom zsh config here
      export EDITOR=nvim
    '';
  };

  # Atuin configuration
  atuin = {
    enable = true;
    searchMode = "fuzzy";  # or "prefix", "fulltext", "skim"
    style = "auto";        # or "full", "compact"
    autoSync = false;      # Enable to sync across machines
    syncAddress = "https://api.atuin.sh";
  };

  # Add extra packages
  extraPackages = with pkgs; [
    nodejs
    python3
    docker-compose
  ];
};
```

### Default Aliases

The following aliases are configured by default:

```bash
# Directory navigation
ll    # ls -lah (with eza: detailed list with icons)
la    # ls -A  (all files)
l     # ls -CF (columnar format)
..    # cd ..
...   # cd ../..

# Git shortcuts
gst   # git status
gd    # git diff
gc    # git commit
gp    # git push
gl    # git log --oneline --graph --decorate

# Utilities
grep  # grep --color=auto
cat   # bat --style=auto (when bat is available)
ls    # eza --icons (when eza is available)
```

### Theme Options

#### Starship (Default)

A minimal, fast, and highly customizable prompt written in Rust.

- Shows current directory (truncated intelligently)
- Git branch and status indicators
- Command duration for long-running commands
- Language version indicators (Python, Node, etc.)
- Success/error status

#### Powerlevel10k

Feature-rich prompt with extensive customization options (configuration required separately).

#### Minimal

A clean, simple prompt for those who prefer minimalism.

### Atuin Search Modes

- **fuzzy** (default): Flexible fuzzy matching
- **prefix**: Match from the beginning of commands
- **fulltext**: Search anywhere in the command
- **skim**: Advanced fuzzy matching algorithm

## Key Bindings

### Atuin

- `Ctrl+R`: Open atuin search (replaces default history search)
- `Ctrl+N`: Next result
- `Ctrl+P`: Previous result
- `Esc`: Cancel search
- Arrow keys work as expected (up arrow disabled to encourage Ctrl+R usage)

### FZF

- `Ctrl+T`: Search files in current directory
- `Ctrl+R`: Search command history (when atuin is disabled)
- `Alt+C`: Change directory (fuzzy search)

### Zsh

- `Tab`: Trigger completion menu
- `Ctrl+Space`: Accept autosuggestion
- `Ctrl+E`: Move to end of line
- `Ctrl+A`: Move to beginning of line

## Integration with Other Flakes

### Nixvim

This flake automatically integrates with the `nixvim` flake for a complete terminal-based development environment.

### Devman

Developer environment management tools are included via the `devman` flake, providing project-specific development environments.

### Custom Integrations

You can extend this module with your own flakes:

```nix
{ inputs, ... }:
{
  imports = [
    inputs.nix-terminal.homeManagerModules.terminal
    inputs.your-custom-flake.homeManagerModules.yourModule
  ];

  programs.nix-terminal = {
    enable = true;
    extraPackages = [
      inputs.your-custom-flake.packages.${pkgs.system}.yourTool
    ];
  };
}
```

## Advanced Usage

### Environment-Specific Configuration

Use `direnv` integration for per-directory configuration:

```bash
# In your project directory
echo "use nix" > .envrc
direnv allow
```

Create a `shell.nix` or `flake.nix` in your project for automatic environment loading.

### History Management

Atuin stores history in an SQLite database at `~/.local/share/atuin/history.db`.

Useful atuin commands:

```bash
atuin stats          # View your shell usage statistics
atuin search <term>  # Search history from CLI
atuin sync           # Manually sync history (if enabled)
atuin import auto    # Import from existing shell history
```

### Customizing the Prompt

For Starship, you can override the default configuration:

```nix
programs.starship.settings = {
  # Your custom starship config
  # See: https://starship.rs/config/
};
```

## Architecture

```
nix-terminal/
├── flake.nix              # Flake definition with inputs
├── modules/
│   └── terminal.nix       # Main Home Manager module
└── README.md              # This file
```

The module is structured to:
- Provide sensible defaults
- Allow extensive customization
- Maintain clean separation of concerns
- Integrate seamlessly with other flakes

## Dependencies

### Flake Inputs

- **nixpkgs**: NixOS package collection
- **nixvim**: Neovim configuration flake
- **devman**: Development environment management

### Runtime Dependencies

All runtime dependencies are managed declaratively through Nix and include:
- zsh
- starship (optional, based on theme)
- atuin
- fzf
- direnv
- eza, bat, ripgrep, fd
- And more (see `modules/terminal.nix`)

## Troubleshooting

### Zsh not set as default shell

After installation, set zsh as your default shell:

```bash
chsh -s $(which zsh)
```

Or in your NixOS configuration:

```nix
users.users.youruser.shell = pkgs.zsh;
```

### Atuin history not working

Ensure atuin is enabled and the database is initialized:

```bash
atuin init
```

This should happen automatically, but you can run it manually if needed.

### Icons not displaying

Install a Nerd Font for proper icon support:

```nix
fonts.fonts = with pkgs; [
  (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
];
```

## Contributing

This flake is part of the Bullish-Design modular NixOS collection. Contributions are welcome!

### Areas for contribution:
- Additional prompt themes
- More sensible defaults
- Integration with other tools
- Documentation improvements
- Bug fixes and optimizations

## License

This project follows the same license as its dependencies. See individual components for specific licensing.

## Related Projects

- [nixvim](https://github.com/Bullish-Design/nixvim) - Neovim configuration
- [devman](https://github.com/Bullish-Design/devman) - Development environment management
- [Home Manager](https://github.com/nix-community/home-manager) - User environment management
- [atuin](https://github.com/atuinsh/atuin) - Magical shell history
- [starship](https://starship.rs/) - Cross-shell prompt

## Credits

Built with love for the terminal-centric workflow. Powered by NixOS, zsh, atuin, and the amazing Nix community.
