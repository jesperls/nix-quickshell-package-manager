import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    readonly property string helperScript: Quickshell.env("QPM_HELPER_SCRIPT") || (Quickshell.env("PWD") + "/assets/qpm.sh")
    readonly property string rebuildAlias: Quickshell.env("QPM_REBUILD_ALIAS") || ""

    property string statusText: ""
    property string configuredPath: ""
    property string configuredChannel: "nixos-unstable"
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
                statusText = payload.error;
                return;
            }

            statusText = "Rebuild completed";
        });
    }

    Process {
        id: stateProcess
        property string output: ""
        property var onDone: null
        stdout: SplitParser {
            onRead: data => { stateProcess.output += data; }
        }
        onRunningChanged: {
            if (!running && onDone) {
                const callback = onDone;
                onDone = null;
                callback(output);
            }
        }
    }

    Process {
        id: setPathProcess
        property string output: ""
        property var onDone: null
        stdout: SplitParser {
            onRead: data => { setPathProcess.output += data; }
        }
        onRunningChanged: {
            if (!running && onDone) {
                const callback = onDone;
                onDone = null;
                callback(output);
            }
        }
    }

    Process {
        id: setChannelProcess
        property string output: ""
        property var onDone: null
        stdout: SplitParser {
            onRead: data => { setChannelProcess.output += data; }
        }
        onRunningChanged: {
            if (!running && onDone) {
                const callback = onDone;
                onDone = null;
                callback(output);
            }
        }
    }

    Process {
        id: searchProcess
        property string output: ""
        property var onDone: null
        stdout: SplitParser {
            onRead: data => { searchProcess.output += data; }
        }
        onRunningChanged: {
            if (!running && onDone) {
                const callback = onDone;
                onDone = null;
                callback(output);
            }
        }
    }

    Process {
        id: addProcess
        property string output: ""
        property var onDone: null
        stdout: SplitParser {
            onRead: data => { addProcess.output += data; }
        }
        onRunningChanged: {
            if (!running && onDone) {
                const callback = onDone;
                onDone = null;
                callback(output);
            }
        }
    }

    Process {
        id: removeProcess
        property string output: ""
        property var onDone: null
        stdout: SplitParser {
            onRead: data => { removeProcess.output += data; }
        }
        onRunningChanged: {
            if (!running && onDone) {
                const callback = onDone;
                onDone = null;
                callback(output);
            }
        }
    }

    Process {
        id: rebuildProcess
        property string output: ""
        property var onDone: null
        stdout: SplitParser {
            onRead: data => { rebuildProcess.output += data; }
        }
        onRunningChanged: {
            if (!running && onDone) {
                const callback = onDone;
                onDone = null;
                callback(output);
            }
        }
    }

    Component.onCompleted: loadState()

    component ActionButton: Rectangle {
        id: actionBtn
        property alias label: labelText.text
        property bool disabled: false
        signal clicked

        radius: 8
        color: disabled ? "#2c3138" : "#333b45"
        border.width: 1
        border.color: "#4a5563"

        Text {
            id: labelText
            anchors.centerIn: parent
            color: actionBtn.disabled ? "#858d98" : "#e7ecf3"
            font.pixelSize: 13
        }

        MouseArea {
            anchors.fill: parent
            enabled: !actionBtn.disabled
            onClicked: actionBtn.clicked()
        }
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

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        width: parent.width - (rebuildButton.visible ? rebuildButton.width + 8 : 0)
                        text: "Quickshell Package Manager"
                        color: "#e6edf5"
                        font.pixelSize: 24
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    ActionButton {
                        id: rebuildButton
                        visible: root.rebuildAlias.trim().length > 0
                        width: 100
                        height: 34
                        label: "Rebuild"
                        onClicked: root.runRebuild()
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

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: parent.height
                        radius: 10
                        color: "#121720"
                        border.color: "#2d3541"
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                text: "Current packages"
                                color: "#e3e9f2"
                                font.pixelSize: 18
                                font.bold: true
                            }

                            Row {
                                width: parent.width
                                spacing: 8

                                Rectangle {
                                    width: parent.width - 90
                                    height: 32
                                    radius: 8
                                    color: "#0f141c"
                                    border.color: "#28303b"
                                    border.width: 1

                                    TextInput {
                                        id: manualAddInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        color: "#e6edf5"
                                        onAccepted: {
                                            let pkg = text.trim();
                                            if (pkg.length > 0) {
                                                root.addPackage(pkg);
                                                text = "";
                                            }
                                        }
                                    }
                                }

                                ActionButton {
                                    width: 82
                                    height: 32
                                    label: "Add"
                                    onClicked: {
                                        let pkg = manualAddInput.text.trim();
                                        if (pkg.length > 0) {
                                            root.addPackage(pkg);
                                            manualAddInput.text = "";
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: parent.height - 90
                                radius: 8
                                color: "#0f141c"
                                border.color: "#28303b"
                                border.width: 1
                                clip: true

                                Flickable {
                                    id: packagesFlick
                                    anchors.fill: parent
                                    contentWidth: width
                                    contentHeight: packagesColumn.height
                                    clip: true

                                    Column {
                                        id: packagesColumn
                                        width: packagesFlick.width
                                        spacing: 4
                                        padding: 6

                                        Repeater {
                                            model: root.managedPackages

                                            Rectangle {
                                                width: packagesColumn.width - 12
                                                height: 34
                                                radius: 6
                                                color: "#1a2130"
                                                border.color: "#303b4b"
                                                border.width: 1

                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: 6
                                                    spacing: 6

                                                    Text {
                                                        width: parent.width - 66
                                                        text: modelData
                                                        color: "#e3e9f2"
                                                        elide: Text.ElideRight
                                                        verticalAlignment: Text.AlignVCenter
                                                        font.pixelSize: 13
                                                    }

                                                    ActionButton {
                                                        width: 52
                                                        height: 22
                                                        label: "Remove"
                                                        onClicked: root.removePackage(modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: parent.height
                        radius: 10
                        color: "#121720"
                        border.color: "#2d3541"
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                text: "Search NixOS packages"
                                color: "#e3e9f2"
                                font.pixelSize: 18
                                font.bold: true
                            }

                            Row {
                                width: parent.width
                                spacing: 8

                                Rectangle {
                                    width: parent.width - 90
                                    height: 32
                                    radius: 8
                                    color: "#0f141c"
                                    border.color: "#28303b"
                                    border.width: 1

                                    TextInput {
                                        id: searchInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        color: "#e6edf5"
                                        onAccepted: root.searchPackages(text)
                                    }
                                }

                                ActionButton {
                                    width: 82
                                    height: 32
                                    label: "Search"
                                    onClicked: root.searchPackages(searchInput.text)
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: parent.height - 90
                                radius: 8
                                color: "#0f141c"
                                border.color: "#28303b"
                                border.width: 1
                                clip: true

                                Flickable {
                                    id: resultsFlick
                                    anchors.fill: parent
                                    contentWidth: width
                                    contentHeight: resultsColumn.height
                                    clip: true

                                    Column {
                                        id: resultsColumn
                                        width: resultsFlick.width
                                        spacing: 6
                                        padding: 6

                                        Repeater {
                                            model: root.searchResults

                                            Rectangle {
                                                property bool alreadyAdded: root.managedPackages.indexOf(modelData.identifier) !== -1
                                                width: resultsColumn.width - 12
                                                height: 66
                                                radius: 6
                                                color: "#1a2130"
                                                border.color: "#303b4b"
                                                border.width: 1

                                                Column {
                                                    anchors.fill: parent
                                                    anchors.margins: 6
                                                    spacing: 4

                                                    Row {
                                                        width: parent.width
                                                        spacing: 6

                                                        Text {
                                                            width: parent.width - 68
                                                            text: modelData.identifier + (modelData.version ? ("  " + modelData.version) : "")
                                                            color: "#e3e9f2"
                                                            font.pixelSize: 13
                                                            font.bold: true
                                                            elide: Text.ElideRight
                                                        }

                                                        ActionButton {
                                                            property bool alreadyAdded: root.managedPackages.indexOf(modelData.identifier) !== -1
                                                            width: 56
                                                            height: 22
                                                            label: alreadyAdded ? "Added" : "Add"
                                                            disabled: alreadyAdded
                                                            onClicked: {
                                                                if (!alreadyAdded) {
                                                                    root.addPackage(modelData.identifier);
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        text: modelData.description || "No description"
                                                        color: "#b2bcc9"
                                                        font.pixelSize: 12
                                                        wrapMode: Text.WordWrap
                                                        maximumLineCount: 2
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
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
