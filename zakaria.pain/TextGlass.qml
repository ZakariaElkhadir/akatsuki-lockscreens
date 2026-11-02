import QtQuick
import QtQuick.Effects

// Liquid glass in the shape of its content (e.g. a Text). The content is
// only used as a mask; a blurred copy of it gives the bevel its curvature.
Item {
  id: glass

  property var backdrop: null
  property var scene: backdrop
  // Room around the content for the bevel blur and the shadow.
  property real pad: Math.ceil(bevel * 2 + 6)
  property real bevel: 8
  property color tint: "white"
  property real tintAlpha: 0.12

  property real refraction: 0.69
  property real chromAberration: 0.05
  property real edgeHighlight: 0.6
  property real specular: 0.6
  property real fresnel: 1.0
  property real brightness: 0.15
  property real shadowOpacity: 0.35
  property real shadowOffsetY: 3

  default property alias content: holder.data

  implicitWidth: holder.childrenRect.width + pad * 2
  implicitHeight: holder.childrenRect.height + pad * 2

  readonly property point origin: {
    glass.x; glass.y; glass.width; glass.height; glass.visible
    if (!backdrop || !backdrop.sourceItem) return Qt.point(0, 0)
    return glass.mapToItem(backdrop.sourceItem, 0, 0)
  }

  Item {
    id: shape
    anchors.fill: parent
    visible: false

    Item {
      id: holder
      x: glass.pad
      y: glass.pad
      width: childrenRect.width
      height: childrenRect.height
    }
  }

  ShaderEffectSource {
    id: maskSrc
    sourceItem: shape
    visible: false
  }

  MultiEffect {
    id: heightField
    anchors.fill: shape
    source: shape
    autoPaddingEnabled: false
    visible: false
    blurEnabled: true
    blur: 1.0
    blurMax: Math.max(2, Math.round(glass.bevel * 2))
  }

  ShaderEffectSource {
    id: heightSrc
    sourceItem: heightField
    visible: false
  }

  ShaderEffect {
    anchors.fill: parent
    visible: glass.backdrop !== null
    fragmentShader: Qt.resolvedUrl("shaders/textglass.frag.qsb")

    property var sharpTex: glass.scene
    property var blurTex: glass.backdrop
    property var maskTex: maskSrc
    property var heightTex: heightSrc
    property size itemSize: Qt.size(glass.width, glass.height)
    property size res: glass.backdrop && glass.backdrop.sourceItem
      ? Qt.size(glass.backdrop.sourceItem.width, glass.backdrop.sourceItem.height)
      : Qt.size(1, 1)
    property point origin: glass.origin
    property real bevel: glass.bevel
    property real refraction: glass.refraction
    property real chroma: glass.chromAberration
    property real edgeHL: glass.edgeHighlight
    property real spec: glass.specular
    property real fresnel: glass.fresnel
    property real brightness: glass.brightness
    property real shadowAlpha: glass.shadowOpacity
    property real shadowOffY: glass.shadowOffsetY
    property vector4d tintColor: Qt.vector4d(glass.tint.r, glass.tint.g, glass.tint.b, glass.tintAlpha)
  }
}
