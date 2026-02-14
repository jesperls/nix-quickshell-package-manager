import QtQuick
import "./"

Rectangle {
    id: root

    property var searchResults: []
    property var managedPackages: []
    property int rounding: 10
    property string surfaceColor: "#121720"
    property string surfaceAltColor: "#0f141c"
    property string itemColor: "#1a2130"
    property string textColor: "#e3e9f2"
    property string mutedColor: "#b2bcc9"
    property string borderColor: "#2d3541"
    property string fieldBorderColor: "#28303b"
    property string itemBorderColor: "#303b4b"
    property string scrollbarColor: "#4a5563"
    property string buttonColor: "#333b45"
    property string buttonDisabledColor: "#2c3138"
    property string buttonTextColor: "#e7ecf3"
    property string buttonDisabledTextColor: "#858d98"
    signal searchRequested(string query)
    signal addRequested(string packageId)

    radius: rounding
    color: surfaceColor
    border.color: borderColor
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
            color: textColor
            font.pixelSize: 18
            font.bold: true
        }

        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                width: parent.width - 90
                height: 32
                radius: Math.max(6, rounding - 2)
                color: surfaceAltColor
                border.color: fieldBorderColor
                border.width: 1

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 8
                    color: textColor
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
                radiusSize: Math.max(6, rounding - 2)
                activeColor: buttonColor
                disabledColor: buttonDisabledColor
                borderColor: fieldBorderColor
                textColor: buttonTextColor
                disabledTextColor: buttonDisabledTextColor
                onClicked: root.searchRequested(searchInput.text)
            }
        }

        Rectangle {
            width: parent.width
            height: parent.height - 90
            radius: Math.max(6, rounding - 2)
            color: surfaceAltColor
            border.color: fieldBorderColor
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
                            radius: Math.max(5, rounding - 4)
                            color: itemColor
                            border.color: itemBorderColor
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
                                        color: textColor
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
                                        radiusSize: Math.max(4, rounding - 5)
                                        activeColor: buttonColor
                                        disabledColor: buttonDisabledColor
                                        borderColor: itemBorderColor
                                        textColor: buttonTextColor
                                        disabledTextColor: buttonDisabledTextColor
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
                                    color: mutedColor
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
                color: scrollbarColor
                anchors.right: parent.right
                anchors.rightMargin: 2
                y: 2 + (parent.height - 4 - height) * resultsFlick.visibleArea.yPosition
                height: Math.max(24, (parent.height - 4) * resultsFlick.visibleArea.heightRatio)
                visible: resultsFlick.contentHeight > resultsFlick.height + 1
            }
        }
    }
}
