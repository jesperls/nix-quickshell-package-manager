import QtQuick
import "./"

Rectangle {
    id: root

    property var managedPackages: []
    property string filterText: ""
    signal removeRequested(string packageId)

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

        Rectangle {
            width: parent.width
            height: 32
            radius: 8
            color: "#0f141c"
            border.color: "#28303b"
            border.width: 1

            TextInput {
                anchors.fill: parent
                anchors.margins: 8
                color: "#e6edf5"
                text: root.filterText
                onTextChanged: root.filterText = text
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
                        model: (
                            root.filterText.trim().length === 0
                            ? root.managedPackages
                            : root.managedPackages.filter(pkg => pkg.toLowerCase().indexOf(root.filterText.trim().toLowerCase()) !== -1)
                        ).slice().sort((a, b) => a.localeCompare(b))

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
                                    width: parent.width - 78
                                    text: modelData
                                    color: "#e3e9f2"
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 13
                                }

                                ActionButton {
                                    width: 64
                                    height: 22
                                    label: "Remove"
                                    onClicked: root.removeRequested(modelData)
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
                y: 2 + (parent.height - 4 - height) * packagesFlick.visibleArea.yPosition
                height: Math.max(24, (parent.height - 4) * packagesFlick.visibleArea.heightRatio)
                visible: packagesFlick.contentHeight > packagesFlick.height + 1
            }
        }
    }
}
