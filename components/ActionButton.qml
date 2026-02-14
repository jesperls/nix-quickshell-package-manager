import QtQuick

Rectangle {
    id: actionBtn

    property alias label: labelText.text
    property bool disabled: false
    property int radiusSize: 8
    property string activeColor: "#333b45"
    property string disabledColor: "#2c3138"
    property string borderColor: "#4a5563"
    property string textColor: "#e7ecf3"
    property string disabledTextColor: "#858d98"
    signal clicked

    radius: radiusSize
    color: disabled ? disabledColor : activeColor
    border.width: 1
    border.color: actionBtn.borderColor

    Text {
        id: labelText
        anchors.centerIn: parent
        color: actionBtn.disabled ? actionBtn.disabledTextColor : actionBtn.textColor
        font.pixelSize: 13
    }

    MouseArea {
        anchors.fill: parent
        enabled: !actionBtn.disabled
        onClicked: actionBtn.clicked()
    }
}
