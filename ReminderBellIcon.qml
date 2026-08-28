import QtQuick
import QtQuick.Effects

Item {
  id: root

  property color color: "white"
  property real iconSize: Style.bar.iconCanvas

  implicitWidth: iconSize
  implicitHeight: iconSize

  Image {
    id: sourceImage
    anchors.fill: parent
    source: Qt.resolvedUrl("assets/bell.svg")
    fillMode: Image.PreserveAspectFit
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    anchors.fill: sourceImage
    source: sourceImage
    colorization: 1.0
    colorizationColor: root.color
  }
}
