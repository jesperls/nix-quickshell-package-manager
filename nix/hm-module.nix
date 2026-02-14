self:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  cfg = config.programs.quickshellPackageManager;

  expandedPackagesFile =
    if lib.hasPrefix "~" cfg.packagesFile
    then "${config.home.homeDirectory}${lib.removePrefix "~" cfg.packagesFile}"
    else cfg.packagesFile;

  themeEnv = lib.filterAttrs (_: v: v != null) {
    QPM_ACCENT = cfg.theme.accent;
    QPM_ACCENT2 = cfg.theme.accent2;
    QPM_BG = cfg.theme.background;
    QPM_SURFACE = cfg.theme.surface;
    QPM_SURFACE_ALT = cfg.theme.surfaceAlt;
    QPM_TEXT = cfg.theme.text;
    QPM_MUTED = cfg.theme.muted;
    QPM_BORDER = cfg.theme.border;
    QPM_SHADOW = cfg.theme.shadow;
    QPM_SCROLLBAR = cfg.theme.scrollbar;
    QPM_BUTTON = cfg.theme.button;
    QPM_BUTTON_DISABLED = cfg.theme.buttonDisabled;
    QPM_ROUNDING = toString cfg.theme.rounding;
  };

  managerPkg = cfg.package.override {
    inherit themeEnv;
    initialPackagesFile = expandedPackagesFile;
    channel = cfg.channel;
    rebuildAlias = cfg.rebuildAlias;
  };
in
{
  options.programs.quickshellPackageManager = with lib; {
    enable = mkEnableOption "Quickshell package manager for a packages.nix file";

    package = mkOption {
      type = types.package;
      default = self.packages.${system}.default;
      description = "The quickshell package manager package to use.";
    };

    packagesFile = mkOption {
      type = types.str;
      default = "~/nixos-config/modules/home-manager/packages.nix";
      description = "Path to the packages.nix file managed by the GUI.";
    };

    channel = mkOption {
      type = types.enum [
        "nixos-unstable"
        "nixos-25.11"
      ];
      default = "nixos-unstable";
      description = "NixOS channel/index used for search suggestions from search.nixos.org.";
    };

    rebuildAlias = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "nh os switch ~/nixos-config";
      description = "Optional rebuild command shown in the UI as a Rebuild button.";
    };

    theme = {
      accent = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Accent color (hex). Falls back to built-in default if null.";
      };
      accent2 = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Secondary accent color (hex). Falls back to built-in default if null.";
      };
      background = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Background color (hex). Falls back to built-in default if null.";
      };
      surface = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Surface color (hex). Falls back to built-in default if null.";
      };
      surfaceAlt = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Alternate surface color (hex). Falls back to built-in default if null.";
      };
      text = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Text color (hex). Falls back to built-in default if null.";
      };
      muted = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Muted text color (hex). Falls back to built-in default if null.";
      };
      border = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Border color (hex). Falls back to built-in default if null.";
      };
      shadow = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Shadow color (hex). Falls back to built-in default if null.";
      };
      scrollbar = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Scrollbar thumb color (hex). Falls back to built-in default if null.";
      };
      button = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Button background color (hex). Falls back to built-in default if null.";
      };
      buttonDisabled = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Disabled button background color (hex). Falls back to built-in default if null.";
      };
      rounding = mkOption {
        type = types.int;
        default = 10;
        description = "Corner rounding in pixels.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ managerPkg ];
  };
}
