import QtQuick
import qs.Commons as Commons

// Clear liquid glass: a port of ybouane/liquidglass (thick pill bevel that
// refracts a sharp backdrop, dispersion, Fresnel, specular, rim light) plus a
// mirror term, a key light that follows the cursor, and the elastic lean /
// stretch from rdev/liquid-glass-react. Shader: shaders/liquidglass.frag.
Item {
  id: card

  // Texture providers covering the whole screen (e.g. ShaderEffectSource).
  property var backdrop: null
  property var scene: backdrop
  property real radius: 28
  property color tint: Commons.Color.background
  property real tintAlpha: 0.06

  // ybouane/liquidglass knobs (see its src/defaults.ts).
  property real refraction: 0.9
  property real chromAberration: 0.08
  property real edgeHighlight: 0.0       // rim lines + inner glow (off)
  property real specular: 0.0            // shiny highlights (off)
  property real fresnel: 0.0             // white sheen on the curved edge (off)
  property real zRadius: 40
  property real saturation: 0.15
  property real brightness: 0.03
  property real blurAmount: 0.0       // 0 = crystal clear, 1 = uses `backdrop` fully
  property real mirror: 0.0           // reflection of the surroundings in the bevel (off)
  property real elasticity: 0.0       // >0 leans/stretches towards the cursor
  property real bevel: 1.0             // lens edge that bends the background (0 = flat pane)
  property real shadowOpacity: 0.35
  property real shadowSpread: 14
  property real shadowOffsetY: 4
  readonly property real shadowPad: shadowSpread * 2 + shadowOffsetY + 8

  // Cursor in backdrop.sourceItem coordinates.
  property point pointer: Qt.point(0, 0)
  property bool pointerActive: false
  // Extra horizontal offset for callers (e.g. a shake animation).
  property real offsetX: 0

  default property alias content: inner.data

  // Untransformed centre in backdrop coordinates (avoids a feedback loop with
  // the elastic transform below).
  readonly property point restCenter: {
    card.x; card.y; card.width; card.height; card.visible
    if (!backdrop || !backdrop.sourceItem || !card.parent) return Qt.point(0, 0)
    return card.parent.mapToItem(backdrop.sourceItem, card.x + card.width / 2, card.y + card.height / 2)
  }
  readonly property real dx: pointer.x - restCenter.x
  readonly property real dy: pointer.y - restCenter.y
  readonly property real fade: {
    if (!pointerActive) return 0
    var ex = Math.max(0, Math.abs(dx) - width / 2)
    var ey = Math.max(0, Math.abs(dy) - height / 2)
    var e = Math.sqrt(ex * ex + ey * ey)
    return e > 200 ? 0 : 1 - e / 200
  }
  readonly property bool pointerInside: pointerActive && Math.abs(dx) <= width / 2 && Math.abs(dy) <= height / 2

  property real elasticX: dx * elasticity * 0.1 * fade
  property real elasticY: dy * elasticity * 0.1 * fade
  property real stretchX: stretch(true)
  property real stretchY: stretch(false)
  property real mouseOffX: pointerActive ? Math.max(-100, Math.min(100, dx / Math.max(1, width) * 100)) : 0
  property real mouseOffY: pointerActive ? Math.max(-100, Math.min(100, dy / Math.max(1, height) * 100)) : 0

  Behavior on elasticX { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
  Behavior on elasticY { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
  Behavior on stretchX { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
  Behavior on stretchY { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
  Behavior on mouseOffX { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
  Behavior on mouseOffY { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

  function stretch(horizontal) {
    var dist = Math.sqrt(dx * dx + dy * dy)
    if (fade <= 0 || dist === 0) return 1
    var nx = Math.abs(dx / dist), ny = Math.abs(dy / dist)
    var k = Math.min(dist / 300, 1) * elasticity * fade
    var s = horizontal ? 1 + nx * k * 0.3 - ny * k * 0.15 : 1 + ny * k * 0.3 - nx * k * 0.15
    return Math.max(0.8, s)
  }

  transform: [
    Scale {
      origin.x: card.width / 2
      origin.y: card.height / 2
      xScale: card.stretchX
      yScale: card.stretchY
    },
    Translate {
      x: card.elasticX + card.offsetX
      y: card.elasticY
    }
  ]

  ShaderEffect {
    x: -card.shadowPad
    y: -card.shadowPad
    width: card.width + card.shadowPad * 2
    height: card.height + card.shadowPad * 2
    visible: card.backdrop !== null
    fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb")

    property var sharpTex: card.scene
    property var blurTex: card.backdrop
    property size panelSize: Qt.size(card.width, card.height)
    property size res: card.backdrop && card.backdrop.sourceItem
      ? Qt.size(card.backdrop.sourceItem.width, card.backdrop.sourceItem.height)
      : Qt.size(1, 1)
    property point origin: Qt.point(
      card.restCenter.x + card.elasticX + card.offsetX - card.width / 2 * card.stretchX,
      card.restCenter.y + card.elasticY - card.height / 2 * card.stretchY)
    property point scl: Qt.point(card.stretchX, card.stretchY)
    property point light: Qt.point(card.mouseOffX / 100, card.mouseOffY / 100)
    property real pad: card.shadowPad
    property real radius: card.radius
    property real refraction: card.refraction
    property real chroma: card.chromAberration
    property real edgeHL: card.edgeHighlight
    property real spec: card.specular
    property real fresnel: card.fresnel
    property real zRadius: card.zRadius
    property real brightness: card.brightness
    property real sat: card.saturation
    property real blurMix: card.blurAmount
    property real mirror: card.mirror
    property real shadowAlpha: card.shadowOpacity
    property real shadowSpread: card.shadowSpread
    property real shadowOffY: card.shadowOffsetY
    property real bevel: card.bevel
    property vector4d tintColor: Qt.vector4d(card.tint.r, card.tint.g, card.tint.b, card.tintAlpha)
  }

  Item {
    id: inner
    anchors.fill: parent
  }
}
