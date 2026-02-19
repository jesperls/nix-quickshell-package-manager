# nix-quickshell-package-manager

## Demo

https://github.com/user-attachments/assets/817ddad8-b799-4622-8f47-8b27a54eed4a

A Quickshell GUI wrapper around a single managed `packages.nix` file. Search packages from `search.nixos.org`, add or remove them, and optionally trigger a system rebuild — all without touching a text editor.

- Stores config in `~/.config/quickshell-package-manager/config.json`
- Edits your `packages.nix` in the standard Home Manager style:
  ```nix
  { pkgs, ... }: { home.packages = with pkgs; [ ... ]; }
  ```
- Fetches package suggestions from `search.nixos.org`
- Optional one-click rebuild button

## Run directly

```bash
nix run github:jesperls/nix-quickshell-package-manager
```

## Home Manager module

Add the flake input:

```nix
# flake.nix
quickshell-package-manager = {
  url = "github:jesperls/nix-quickshell-package-manager";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Import the module and configure:

```nix
imports = [ inputs.quickshell-package-manager.homeManagerModules.default ];

programs.quickshellPackageManager = {
  enable = true;
  packagesFile = "~/nixos-config/modules/home-manager/packages.nix";
  channel = "nixos-unstable"; # or "nixos-25.11"
  rebuildAlias = "nh os switch ~/nixos-config"; # optional, enables Rebuild button
  baseColors = {
    accent = "#7aa2f7";
    accent2 = "#89dceb";
    background = "#171c24";
    surface = "#121720";
    surfaceAlt = "#0f141c";
    text = "#e6edf5";
    muted = "#aeb8c6";
    border = "#2f3743";
    shadow = "#0b1018";
    button = "#7aa2f7";
    buttonDisabled = "#2c3138";
    scrollbar = "#4a5563";
  };
  baseRounding = 10;
};
```

This installs the `qs-pkg-manager` binary.

## Usage

1. Run `qs-pkg-manager`
2. Set the path to your `packages.nix` file (pre-filled if `packagesFile` is set)
3. Search packages and click **Add**, or click **Remove** on installed packages
4. Click **Rebuild** to run your rebuild command (if `rebuildAlias` is configured)

## Notes

- If the configured `packages.nix` path does not exist it is created with a minimal template.

## Theming

All colors are configurable via `baseColors` (shorthand attrset) or individually via `theme.*`. Any unset color falls back to the built-in default.

| `theme` option   | `baseColors` key   | Env variable           | Default      |
|------------------|--------------------|------------------------|--------------|
| `accent`         | `accent`           | `QPM_ACCENT`           | `#7aa2f7`    |
| `accent2`        | `accent2`          | `QPM_ACCENT2`          | `#89dceb`    |
| `background`     | `background`       | `QPM_BG`               | `#171c24`    |
| `surface`        | `surface`          | `QPM_SURFACE`          | `#121720`    |
| `surfaceAlt`     | `surfaceAlt`       | `QPM_SURFACE_ALT`      | `#0f141c`    |
| `text`           | `text`             | `QPM_TEXT`             | `#e6edf5`    |
| `muted`          | `muted`            | `QPM_MUTED`            | `#aeb8c6`    |
| `border`         | `border`           | `QPM_BORDER`           | `#2f3743`    |
| `shadow`         | `shadow`           | `QPM_SHADOW`           | `#0b1018`    |
| `scrollbar`      | `scrollbar`        | `QPM_SCROLLBAR`        | `#4a5563`    |
| `button`         | `button`           | `QPM_BUTTON`           | `QPM_ACCENT` |
| `buttonDisabled` | `buttonDisabled`   | `QPM_BUTTON_DISABLED`  | `#2c3138`    |
| `rounding`       | —                  | `QPM_ROUNDING`         | `10`         |
