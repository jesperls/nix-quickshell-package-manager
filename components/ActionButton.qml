import QtQuick

Rectangle {
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
