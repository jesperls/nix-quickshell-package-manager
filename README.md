# nix-quickshell-package-manager

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
quickshell-package-manager.url = "path:./nix-quickshell-package-manager";
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
