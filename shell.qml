import Quickshell
import Quickshell.Wayland
import QtQuick
import "components"

ShellRoot {
    id: root

    readonly property string helperScript: Quickshell.env("QPM_HELPER_SCRIPT") || (Quickshell.env("PWD") + "/assets/qpm.sh")
    readonly property string rebuildAlias: Quickshell.env("QPM_REBUILD_ALIAS") || ""

    property string statusText: ""
    property string configuredPath: ""
    property string configuredChannel: "nixos-unstable"
    property string packageFilterText: ""
    property bool rebuildInProgress: false
    property bool rebuildAvailable: root.rebuildAlias.trim().length > 0
    property var managedPackages: []
    property var searchResults: []

    function parseJsonOrEmpty(text, fallback) {
        try {
            return JSON.parse(text);
        } catch (error) {
            statusText = "Failed to parse command output";
            return fallback;
        }
    }

    function runCommand(proc, args, done) {
        proc.output = "";
        proc.onDone = done;
        proc.command = [root.helperScript].concat(args);
        proc.running = true;
    }

    function applyStatePayload(payload) {
        if (payload.error) {
            statusText = payload.error;
            return;
        }

        configuredPath = payload.config && payload.config.packagesFile ? payload.config.packagesFile : "";
        configuredChannel = payload.config && payload.config.channel ? payload.config.channel : "nixos-unstable";
        rebuildAvailable = payload.rebuildEnabled === true || root.rebuildAlias.trim().length > 0;
        managedPackages = payload.packages || [];
        statusText = "Ready";
    }

    function loadState() {
        runCommand(stateProcess, ["state"], output => {
            applyStatePayload(parseJsonOrEmpty(output, { config: {}, packages: [] }));
        });
    }

    function savePath(path) {
        runCommand(setPathProcess, ["set-path", path], output => {
            applyStatePayload(parseJsonOrEmpty(output, { config: {}, packages: [] }));
        });
    }

    function saveChannel(channel) {
        runCommand(setChannelProcess, ["set-channel", channel], output => {
            applyStatePayload(parseJsonOrEmpty(output, { config: {}, packages: [] }));
        });
    }

    function addPackage(pkg) {
        runCommand(addProcess, ["add", pkg], output => {
            let payload = parseJsonOrEmpty(output, []);
            if (payload.error) {
                statusText = payload.error;
                return;
            }
            managedPackages = payload;
            statusText = "Added " + pkg;
        });
    }

    function removePackage(pkg) {
        runCommand(removeProcess, ["remove", pkg], output => {
            let payload = parseJsonOrEmpty(output, []);
            if (payload.error) {
                statusText = payload.error;
                return;
            }
            managedPackages = payload;
            statusText = "Removed " + pkg;
        });
    }

    function searchPackages(query) {
        if (!query || query.trim().length === 0) {
            searchResults = [];
            statusText = "Enter a search query";
            return;
        }

        runCommand(searchProcess, ["search", query.trim(), "40"], output => {
            let payload = parseJsonOrEmpty(output, []);
            if (payload.error) {
                statusText = payload.error;
                searchResults = [];
                return;
            }
            searchResults = payload;
            statusText = "Found " + payload.length + " result(s)";
        });
    }

    function runRebuild() {
        runCommand(rebuildProcess, ["rebuild"], output => {
            let payload = parseJsonOrEmpty(output, {});
            if (payload.error) {
                rebuildInProgress = false;
                statusText = payload.error;
                return;
            }

            refreshRebuildStatus();
        });
    }

    function openRebuildLog() {
        runCommand(openRebuildLogProcess, ["open-rebuild-log"], output => {
            let payload = parseJsonOrEmpty(output, {});
            if (payload.error) {
                statusText = payload.error;
                return;
            }

            statusText = "Opened rebuild log";
        });
    }

    function refreshRebuildStatus() {
        runCommand(rebuildStatusProcess, ["rebuild-status"], output => {
            let payload = parseJsonOrEmpty(output, {});
            if (payload.error) {
                return;
            }

            let status = payload.status || "idle";
            rebuildInProgress = status === "running";

            if (rebuildInProgress) {
                statusText = "Rebuild in progress";
                return;
            }

            if (status === "success" || status === "failed") {
                statusText = payload.message || (status === "success" ? "Rebuild completed" : "Rebuild failed");
            }
        });
    }

    CommandRunner {
        id: stateProcess
    }

    CommandRunner {
        id: setPathProcess
    }

    CommandRunner {
        id: setChannelProcess
    }

    CommandRunner {
        id: searchProcess
    }

    CommandRunner {
        id: addProcess
    }

    CommandRunner {
        id: removeProcess
    }

    CommandRunner {
        id: rebuildProcess
    }

    CommandRunner {
        id: rebuildStatusProcess
    }

    CommandRunner {
        id: openRebuildLogProcess
    }

    Timer {
        id: rebuildStatusPollTimer
        interval: 1500
        repeat: true
        running: root.rebuildAvailable
        onTriggered: root.refreshRebuildStatus()
    }

    Component.onCompleted: {
        loadState();
        refreshRebuildStatus();
    }

    PanelWindow {
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        aboveWindows: true
        focusable: true

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-package-manager"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Shortcut {
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: Qt.quit()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Qt.quit();
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.9, 1480)
            height: Math.min(parent.height * 0.9, 920)
            radius: 12
            color: "#171c24"
            border.color: "#2f3743"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Item {
                    width: parent.width
                    height: 34

                    Text {
                        anchors.left: parent.left
                        anchors.right: headerActionRow.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Quickshell Package Manager"
                        color: "#e6edf5"
                        font.pixelSize: 24
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Row {
                        id: headerActionRow
                        spacing: 8
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        ActionButton {
                            id: viewLogButton
                            visible: root.rebuildAvailable
                            width: 90
                            height: 34
                            label: "View log"
                            onClicked: root.openRebuildLog()
                        }

                        ActionButton {
                            id: rebuildButton
                            visible: root.rebuildAvailable
                            width: 100
                            height: 34
                            label: root.rebuildInProgress ? "In progress" : "Rebuild"
                            disabled: root.rebuildInProgress
                            onClicked: root.runRebuild()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 110
                    radius: 10
                    color: "#121720"
                    border.color: "#2d3541"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "Managed packages.nix path"
                            color: "#b8c2cf"
                            font.pixelSize: 13
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: parent.width - 100
                                height: 34
                                radius: 8
                                color: "#0f141c"
                                border.color: "#28303b"
                                border.width: 1

                                TextInput {
                                    id: packagesPathInput
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    color: "#e6edf5"
                                    text: root.configuredPath
                                    selectByMouse: true
                                    clip: true
                                }
                            }

                            ActionButton {
                                width: 92
                                height: 34
                                label: "Save Path"
                                onClicked: root.savePath(packagesPathInput.text.trim())
                            }
                        }

                        Row {
                            spacing: 8

                            ActionButton {
                                width: 130
                                height: 30
                                label: root.configuredChannel === "nixos-unstable" ? "● unstable" : "unstable"
                                onClicked: root.saveChannel("nixos-unstable")
                            }

                            ActionButton {
                                width: 130
                                height: 30
                                label: root.configuredChannel === "nixos-25.11" ? "● 25.11" : "25.11"
                                onClicked: root.saveChannel("nixos-25.11")
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: parent.height - 220
                    spacing: 12

                    CurrentPackagesPane {
                        width: (parent.width - 12) / 2
                        height: parent.height
                        managedPackages: root.managedPackages
                        filterText: root.packageFilterText
                        onFilterTextChanged: root.packageFilterText = filterText
                        onRemoveRequested: pkg => root.removePackage(pkg)
                    }

                    SearchPane {
                        width: (parent.width - 12) / 2
                        height: parent.height
                        searchResults: root.searchResults
                        managedPackages: root.managedPackages
                        onSearchRequested: query => root.searchPackages(query)
                        onAddRequested: pkg => root.addPackage(pkg)
                    }
                }

                Text {
                    width: parent.width
                    text: root.statusText
                    color: "#aeb8c6"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }
    }
}
