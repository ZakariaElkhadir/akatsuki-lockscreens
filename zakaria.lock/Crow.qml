import QtQuick
import QtQuick.Shapes

// A flapping crow silhouette that bursts out from a point and flies away.
// Call launch(x, y) with coordinates in the parent's space.
Item {
  id: crow

  property color color: "#0a0608"
  property real flap: 0
  property real progress: 0
  property real startX: 0
  property real startY: 0
  property real dirX: 0
  property real dirY: -1
  property real distance: 600
  property real size: 1

  width: 100
  height: 60
  visible: progress > 0 && progress < 1
  x: startX + dirX * distance * easeOut(progress) - width / 2
  y: startY + dirY * distance * easeOut(progress) - height / 2
  opacity: progress < 0.1 ? progress / 0.1 : 1 - Math.pow((progress - 0.1) / 0.9, 2)
  scale: size * (0.25 + 0.9 * progress)
  rotation: dirX * 25

  function easeOut(t) { return 1 - Math.pow(1 - t, 2.2) }

  function launch(px, py, delay) {
    var ang = Math.random() * Math.PI * 2
    startX = px
    startY = py
    dirX = Math.cos(ang)
    dirY = Math.sin(ang) * 0.75 - 0.25
    distance = 350 + Math.random() * 650
    size = 0.45 + Math.random() * 0.75
    flight.stop()
    progress = 0
    pause.duration = delay
    flight.start()
  }

  SequentialAnimation {
    id: flight
    PauseAnimation { id: pause; duration: 0 }
    NumberAnimation {
      target: crow
      property: "progress"
      from: 0.001
      to: 1
      duration: 1700 + Math.random() * 900
      easing.type: Easing.Linear
    }
  }

  SequentialAnimation on flap {
    loops: Animation.Infinite
    running: crow.visible
    NumberAnimation { to: 1; duration: 120; easing.type: Easing.InOutSine }
    NumberAnimation { to: 0; duration: 150; easing.type: Easing.InOutSine }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    transform: Scale { origin.x: 50; origin.y: 34; yScale: 1 - crow.flap * 1.35 }

    ShapePath {
      strokeWidth: -1
      fillColor: crow.color
      // wings + body + tail
      PathSvg { path: "M50 30 C44 21 30 10 0 9 C14 14 22 19 27 25 C20 24 14 25 9 27 C22 28 31 31 37 35 C41 38 45 39 47 41 L44 52 L50 47 L56 52 L53 41 C55 39 59 38 63 35 C69 31 78 28 91 27 C86 25 80 24 73 25 C78 19 86 14 100 9 C70 10 56 21 50 30 Z" }
    }
    ShapePath {
      strokeWidth: -1
      fillColor: crow.color
      // head + beak
      PathSvg { path: "M45 31 A5 5 0 1 1 55 31 A5 5 0 1 1 45 31 Z M48 28 L50 22 L52 28 Z" }
    }
  }
}
