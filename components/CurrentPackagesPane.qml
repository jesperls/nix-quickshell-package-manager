import QtQuick
import "./"

Rectangle {
    id: root

    required property var managedPackages
    property string filterText: ""
    required property int rounding
    required property string surfaceColor
    required property string surfaceAltColor
    required property string itemColor
    required property string textColor
    required property string mutedColor
    required property string borderColor
    required property string fieldBorderColor
    required property string itemBorderColor
    required property string scrollbarColor
    required property string buttonColor
    required property string buttonDisabledColor
    required property string buttonTextColor
    required property string buttonDisabledTextColor
    signal removeRequested(string packageId)

    radius: rounding
    color: surfaceColor
    border.color: borderColor
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Text {
            text: "Current packages"
            color: textColor
            font.pixelSize: 18
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: 32
            radius: Math.max(6, rounding - 2)
            color: surfaceAltColor
            border.color: fieldBorderColor
            border.width: 1

            TextInput {
                anchors.fill: parent
                anchors.margins: 8
                color: textColor
                onTextChanged: root.filterText = text
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
                            radius: Math.max(5, rounding - 4)
                            color: itemColor
                            border.color: itemBorderColor
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                Text {
                                    width: parent.width - 78
                                    text: modelData
                                    color: textColor
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 13
                                }

                                ActionButton {
                                    width: 64
                                    height: 22
                                    label: "Remove"
                                    radiusSize: Math.max(4, rounding - 5)
                                    activeColor: buttonColor
                                    disabledColor: buttonDisabledColor
                                    borderColor: itemBorderColor
                                    textColor: buttonTextColor
                                    disabledTextColor: buttonDisabledTextColor
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
                color: scrollbarColor
                anchors.right: parent.right
                anchors.rightMargin: 2
                y: 2 + (parent.height - 4 - height) * packagesFlick.visibleArea.yPosition
                height: Math.max(24, (parent.height - 4) * packagesFlick.visibleArea.heightRatio)
                visible: packagesFlick.contentHeight > packagesFlick.height + 1
            }
        }
    }
}
