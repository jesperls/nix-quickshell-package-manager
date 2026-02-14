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

  managerPkg = cfg.package.override {
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
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ managerPkg ];
  };
}
