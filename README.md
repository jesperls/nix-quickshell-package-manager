# nix-quickshell-package-manager

## Demo

https://github.com/user-attachments/assets/817ddad8-b799-4622-8f47-8b27a54eed4a

A Quickshell app + flake that acts as a GUI wrapper around a single managed `packages.nix` file.

- Stores your chosen `packages.nix` path in `~/.config/quickshell-package-manager/config.json`
- Edits that file in the same style as your Home Manager package file:
  - `home.packages = with pkgs; [ ... ];`
- Fetches package suggestions from `search.nixos.org`

## Run directly

```bash
nix run .
```

## Add to your flake inputs

```nix
  quickshell-package-manager = {
    url = "github:jesperls/nix-quickshell-package-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  ```

Then import the Home Manager module:

```nix
imports = [
  inputs.quickshell-package-manager.homeManagerModules.default
];

programs.quickshellPackageManager = {
  enable = true;
  packagesFile = "~/nixos-config/modules/home-manager/packages.nix";
  channel = "nixos-unstable"; # or "nixos-25.11"
  rebuildAlias = "nh os switch ~/nixos-config"; # optional
  theme = {
    accent = "#7aa2f7";
    accent2 = "#89dceb";
    background = "#171c24";
    surface = "#121720";
    surfaceAlt = "#0f141c";
    text = "#e6edf5";
    muted = "#aeb8c6";
    border = "#2f3743";
    scrollbar = "#4a5563";
    button = "#7aa2f7";
    buttonDisabled = "#2c3138";
    rounding = 10;
  };
};
```

This installs `qs-pkg-manager`.

## Usage

1. Start `qs-pkg-manager`
2. Set the path to the `packages.nix` file you want to manage
3. Search packages and click **Add**, or remove from current list

## Notes

- Search currently queries the same backend used by `search.nixos.org`.
- If your configured path does not exist, it is created with a minimal package-file template.
- If `rebuildAlias` is set, the UI shows a **Rebuild** button that runs that command.

## Theming

All colors are configurable via `programs.quickshellPackageManager.theme`. Any unset color (`null`) uses the built-in default from `shell.qml`.

| Option           | Env variable           | Default     |
|------------------|------------------------|-------------|
| `accent`         | `QPM_ACCENT`           | `#7aa2f7`   |
| `accent2`        | `QPM_ACCENT2`          | `#89dceb`   |
| `background`     | `QPM_BG`               | `#171c24`   |
| `surface`        | `QPM_SURFACE`          | `#121720`   |
| `surfaceAlt`     | `QPM_SURFACE_ALT`      | `#0f141c`   |
| `text`           | `QPM_TEXT`             | `#e6edf5`   |
| `muted`          | `QPM_MUTED`            | `#aeb8c6`   |
| `border`         | `QPM_BORDER`           | `#2f3743`   |
| `scrollbar`      | `QPM_SCROLLBAR`        | `#4a5563`   |
| `button`         | `QPM_BUTTON`           | `QPM_ACCENT`|
| `buttonDisabled` | `QPM_BUTTON_DISABLED`  | `#2c3138`   |
| `rounding`       | `QPM_ROUNDING`         | `10`        |
