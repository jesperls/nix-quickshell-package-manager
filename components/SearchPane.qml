import QtQuick
import "./"

Rectangle {
    id: root

    property var searchResults: []
    property var managedPackages: []
    signal searchRequested(string query)
    signal addRequested(string packageId)

    radius: 10
    color: "#121720"
    border.color: "#2d3541"
    border.width: 1

    Timer {
        id: searchDebounceTimer
        interval: 450
        repeat: false
        onTriggered: root.searchRequested(searchInput.text)
    }

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
                    onTextChanged: searchDebounceTimer.restart()
                    onActiveFocusChanged: {
                        if (!activeFocus) {
                            searchDebounceTimer.stop();
                            root.searchRequested(text);
                        }
                    }
                    onAccepted: root.searchRequested(text)
                }
            }

            ActionButton {
                width: 82
                height: 32
                label: "Search"
                onClicked: root.searchRequested(searchInput.text)
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
                                                root.addRequested(modelData.identifier);
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

            Rectangle {
                width: 6
                radius: 3
                color: "#4a5563"
                anchors.right: parent.right
                anchors.rightMargin: 2
                y: 2 + (parent.height - 4 - height) * resultsFlick.visibleArea.yPosition
                height: Math.max(24, (parent.height - 4) * resultsFlick.visibleArea.heightRatio)
                visible: resultsFlick.contentHeight > resultsFlick.height + 1
            }
        }
    }
}
