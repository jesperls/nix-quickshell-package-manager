import Quickshell
import Quickshell.Wayland
import QtQuick
import "components"

ShellRoot {
    id: root

    readonly property string helperScript: Quickshell.env("QPM_HELPER_SCRIPT") || (Quickshell.env("PWD") + "/assets/qpm.sh")
    readonly property string rebuildAlias: Quickshell.env("QPM_REBUILD_ALIAS") || ""
    readonly property string bgColor: Quickshell.env("QPM_BG") || "#171c24"
    readonly property string surfaceColor: Quickshell.env("QPM_SURFACE") || "#121720"
    readonly property string surfaceAltColor: Quickshell.env("QPM_SURFACE_ALT") || "#0f141c"
    readonly property string accentColor: Quickshell.env("QPM_ACCENT") || "#7aa2f7"
    readonly property string accent2Color: Quickshell.env("QPM_ACCENT2") || "#89dceb"
    readonly property string textColor: Quickshell.env("QPM_TEXT") || "#e6edf5"
    readonly property string mutedColor: Quickshell.env("QPM_MUTED") || "#aeb8c6"
    readonly property string borderColor: Quickshell.env("QPM_BORDER") || "#2f3743"
    readonly property string shadowColor: Quickshell.env("QPM_SHADOW") || "#0b1018"
    readonly property string scrollbarColor: Quickshell.env("QPM_SCROLLBAR") || "#4a5563"
    readonly property string buttonColor: Quickshell.env("QPM_BUTTON") || accentColor
    readonly property string buttonDisabledColor: Quickshell.env("QPM_BUTTON_DISABLED") || "#2c3138"
    readonly property int rounding: parseInt(Quickshell.env("QPM_ROUNDING") || "10")

    property string statusText: ""
    property string configuredPath: ""
    property string configuredChannel: "nixos-unstable"
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
        proc.command = ["bash", root.helperScript].concat(args);
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
        runCommand(cmdProcess, ["state"], output => {
            applyStatePayload(parseJsonOrEmpty(output, { config: {}, packages: [] }));
        });
    }

    function savePath(path) {
        runCommand(cmdProcess, ["set-path", path], output => {
            applyStatePayload(parseJsonOrEmpty(output, { config: {}, packages: [] }));
        });
    }

    function saveChannel(channel) {
        runCommand(cmdProcess, ["set-channel", channel], output => {
            applyStatePayload(parseJsonOrEmpty(output, { config: {}, packages: [] }));
        });
    }

    function addPackage(pkg) {
        runCommand(cmdProcess, ["add", pkg], output => {
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
        runCommand(cmdProcess, ["remove", pkg], output => {
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

        runCommand(cmdProcess, ["search", query.trim(), "40"], output => {
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
        runCommand(cmdProcess, ["rebuild"], output => {
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
        id: cmdProcess
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
        running: root.rebuildInProgress
        onTriggered: root.refreshRebuildStatus()
    }

    Component.onCompleted: {
        loadState();
        refreshRebuildStatus();
    }

    FloatingWindow {
        id: mainWindow

        title: "Quickshell Package Manager"
        color: "transparent"
        implicitWidth: Math.min((screen ? screen.width : 1640) * 0.9, 1480)
        implicitHeight: Math.min((screen ? screen.height : 1020) * 0.9, 920)
        minimumSize.width: 960
        minimumSize.height: 620

        Shortcut {
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: Qt.quit()
        }

        Rectangle {
            anchors.fill: parent
            radius: root.rounding
            color: root.bgColor
            border.color: root.borderColor
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
                        color: root.textColor
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
                            radiusSize: Math.max(6, root.rounding - 2)
                            activeColor: root.buttonColor
                            disabledColor: root.buttonDisabledColor
                            borderColor: root.borderColor
                            textColor: root.textColor
                            disabledTextColor: root.mutedColor
                            onClicked: root.openRebuildLog()
                        }

                        ActionButton {
                            id: rebuildButton
                            visible: root.rebuildAvailable
                            width: 100
                            height: 34
                            label: root.rebuildInProgress ? "In progress" : "Rebuild"
                            disabled: root.rebuildInProgress
                            radiusSize: Math.max(6, root.rounding - 2)
                            activeColor: root.buttonColor
                            disabledColor: root.buttonDisabledColor
                            borderColor: root.borderColor
                            textColor: root.textColor
                            disabledTextColor: root.mutedColor
                            onClicked: root.runRebuild()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 110
                    radius: Math.max(8, root.rounding)
                    color: root.surfaceColor
                    border.color: root.borderColor
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "Managed packages.nix path"
                            color: root.mutedColor
                            font.pixelSize: 13
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: parent.width - 100
                                height: 34
                                radius: Math.max(6, root.rounding - 2)
                                color: root.surfaceAltColor
                                border.color: root.borderColor
                                border.width: 1

                                TextInput {
                                    id: packagesPathInput
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    color: root.textColor
                                    text: root.configuredPath
                                    selectByMouse: true
                                    clip: true
                                }
                            }

                            ActionButton {
                                width: 92
                                height: 34
                                label: "Save Path"
                                radiusSize: Math.max(6, root.rounding - 2)
                                activeColor: root.buttonColor
                                disabledColor: root.buttonDisabledColor
                                borderColor: root.borderColor
                                textColor: root.textColor
                                disabledTextColor: root.mutedColor
                                onClicked: root.savePath(packagesPathInput.text.trim())
                            }
                        }

                        Row {
                            spacing: 8

                            ActionButton {
                                width: 130
                                height: 30
                                label: root.configuredChannel === "nixos-unstable" ? "● unstable" : "unstable"
                                radiusSize: Math.max(6, root.rounding - 2)
                                activeColor: root.configuredChannel === "nixos-unstable" ? root.accentColor : root.buttonColor
                                disabledColor: root.buttonDisabledColor
                                borderColor: root.borderColor
                                textColor: root.textColor
                                disabledTextColor: root.mutedColor
                                onClicked: root.saveChannel("nixos-unstable")
                            }

                            ActionButton {
                                width: 130
                                height: 30
                                label: root.configuredChannel === "nixos-25.11" ? "● 25.11" : "25.11"
                                radiusSize: Math.max(6, root.rounding - 2)
                                activeColor: root.configuredChannel === "nixos-25.11" ? root.accent2Color : root.buttonColor
                                disabledColor: root.buttonDisabledColor
                                borderColor: root.borderColor
                                textColor: root.textColor
                                disabledTextColor: root.mutedColor
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
                        rounding: root.rounding
                        surfaceColor: root.surfaceColor
                        surfaceAltColor: root.surfaceAltColor
                        itemColor: root.bgColor
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        borderColor: root.borderColor
                        fieldBorderColor: root.borderColor
                        itemBorderColor: root.borderColor
                        scrollbarColor: root.scrollbarColor
                        buttonColor: root.buttonColor
                        buttonDisabledColor: root.buttonDisabledColor
                        buttonTextColor: root.textColor
                        buttonDisabledTextColor: root.mutedColor
                        onRemoveRequested: pkg => root.removePackage(pkg)
                    }

                    SearchPane {
                        width: (parent.width - 12) / 2
                        height: parent.height
                        searchResults: root.searchResults
                        managedPackages: root.managedPackages
                        rounding: root.rounding
                        surfaceColor: root.surfaceColor
                        surfaceAltColor: root.surfaceAltColor
                        itemColor: root.bgColor
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        borderColor: root.borderColor
                        fieldBorderColor: root.borderColor
                        itemBorderColor: root.borderColor
                        scrollbarColor: root.scrollbarColor
                        buttonColor: root.buttonColor
                        buttonDisabledColor: root.buttonDisabledColor
                        buttonTextColor: root.textColor
                        buttonDisabledTextColor: root.mutedColor
                        linkColor: root.accentColor
                        onSearchRequested: query => root.searchPackages(query)
                        onAddRequested: pkg => root.addPackage(pkg)
                    }
                }

                Text {
                    width: parent.width
                    text: root.statusText
                    color: root.mutedColor
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }
    }
}
