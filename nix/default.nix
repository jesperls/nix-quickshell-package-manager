{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  bash,
  curl,
  jq,
  gnused,
  coreutils,
  python3,
  initialPackagesFile ? null,
  channel ? "nixos-unstable",
  rebuildAlias ? null,
}:

stdenvNoCC.mkDerivation {
  pname = "quickshell-package-manager";
  version = "0.1.0";
  src = ./..;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase =
    let
      runtimeDeps = [
        bash
        curl
        jq
        gnused
        coreutils
        python3
      ];
      initialPathFlag =
        if initialPackagesFile == null
        then ""
        else ''--set-default QPM_INITIAL_PACKAGES_FILE "${initialPackagesFile}"'';
      rebuildAliasFlag =
        if rebuildAlias == null
        then ""
        else ''--set-default QPM_REBUILD_ALIAS "${rebuildAlias}"'';
    in
    ''
      runHook preInstall

      mkdir -p $out/share/quickshell-package-manager $out/bin

      cp shell.qml $out/share/quickshell-package-manager/
      install -Dm755 assets/qpm.sh $out/share/quickshell-package-manager/qpm.sh
      install -Dm755 assets/packages_file.py $out/share/quickshell-package-manager/packages_file.py

      makeWrapper ${quickshell}/bin/qs $out/bin/qs-pkg-manager \
        --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
        --set-default QPM_CHANNEL "${channel}" \
        ${initialPathFlag} \
        ${rebuildAliasFlag} \
        --set QPM_HELPER_SCRIPT "$out/share/quickshell-package-manager/qpm.sh" \
        --add-flags "-p $out/share/quickshell-package-manager"

      runHook postInstall
    '';

  meta = {
    description = "GUI wrapper for managing a packages.nix file from Quickshell";
    license = lib.licenses.mit;
    mainProgram = "qs-pkg-manager";
  };
}
