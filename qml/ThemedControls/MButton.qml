import QtQuick 2.0
import QtQuick.Controls 2.2
import QtQuick.Templates 2.1 as T
import QtQuick.Window 2.3

T.Button {
    id: control

    padding: 8
    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: 36 / Screen.devicePixelRatio
    baselineOffset: contentItem.y + contentItem.baselineOffset

    background: BorderImage {
        id: buttonBackground
        anchors.fill: parent
        source: control.hovered ? "qrc:/Resources/button-active.png" : "qrc:/Resources/button.png"
        smooth: false
        border { left: 4 / Screen.devicePixelRatio; top: 4 / Screen.devicePixelRatio; right: 4 / Screen.devicePixelRatio; bottom: 4 / Screen.devicePixelRatio }
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
    }

    contentItem: Text {
        id: textItem
        text: control.text
        font.pointSize: 11
        opacity: enabled ? 1.0 : 0.3
        color: "#000"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
