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
    if lib.hasPrefix "~" cfg.packagesFile then
      "${config.home.homeDirectory}${lib.removePrefix "~" cfg.packagesFile}"
    else
      cfg.packagesFile;

  baseColors = if cfg.baseColors != null then cfg.baseColors else cfg.theme;
  baseRounding = if cfg.baseColors != null then cfg.baseRounding else cfg.theme.rounding;

  themeEnv = lib.filterAttrs (_: v: v != null) {
    QPM_ACCENT = baseColors.accent or null;
    QPM_ACCENT2 = baseColors.accent2 or null;
    QPM_BG = baseColors.background or null;
    QPM_SURFACE = baseColors.surface or null;
    QPM_SURFACE_ALT = baseColors.surfaceAlt or null;
    QPM_TEXT = baseColors.text or null;
    QPM_MUTED = baseColors.muted or null;
    QPM_BORDER = baseColors.border or null;
    QPM_SHADOW = baseColors.shadow or null;
    QPM_SCROLLBAR = baseColors.scrollbar or cfg.theme.scrollbar or null;
    QPM_BUTTON = baseColors.button or cfg.theme.button or null;
    QPM_BUTTON_DISABLED = baseColors.buttonDisabled or cfg.theme.buttonDisabled or null;
    QPM_ROUNDING = toString baseRounding;
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

    baseColors = mkOption {
      type = types.nullOr (types.attrsOf types.str);
      default = null;
      description = "Base theme colors attrset (accent, accent2, background, surface, surfaceAlt, text, muted, border, shadow). Shorthand alternative to setting theme.* individually.";
    };

    baseRounding = mkOption {
      type = types.int;
      default = 10;
      description = "Corner rounding when using baseColors. Ignored if baseColors is null.";
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
