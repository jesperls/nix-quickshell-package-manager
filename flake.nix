{
  description = "Quickshell package manager for editing a managed packages.nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      forAllSystems =
        fn: nixpkgs.lib.genAttrs nixpkgs.lib.platforms.linux (system: fn nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        quickshell-package-manager = pkgs.callPackage ./nix {
          quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
            withX11 = false;
            withI3 = false;
          };
        };
        default = quickshell-package-manager;
      });

      homeManagerModules.default = import ./nix/hm-module.nix self;
    };
}
