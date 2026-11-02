import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.Commons
import qs.Commons as Commons

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: "Enter Password"
  readonly property string iconFont: "JetBrainsMono Nerd Font"
  readonly property color fg: Commons.Color.lock.text
  readonly property color accent: Commons.Color.accent
  readonly property real ui: Math.max(0.6, Math.min(width / 1920, height / 1080))

  readonly property string userName: Quickshell.env("USER") || ""
  readonly property string displayName: userName.length > 0 ? userName.charAt(0).toUpperCase() + userName.slice(1) : ""

  readonly property int fieldFontSize: Math.round(20 * ui)
  readonly property int passwordDotFontSize: Math.round(24 * ui)
  readonly property int passwordDotLetterSpacing: Math.round(4 * ui)
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0

  property date now: new Date()

  // Playing player first, otherwise the first one that has a track loaded.
  readonly property var player: {
    var list = Mpris.players ? Mpris.players.values : []
    var fallback = null
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!p || !(p.trackTitle || p.trackArtist)) continue
      if (p.isPlaying) return p
      if (!fallback) fallback = p
    }
    return fallback
  }
  readonly property bool hasMedia: player !== null
  readonly property var battery: UPower.displayDevice
  readonly property int batteryLevel: battery && battery.isPresent ? Math.round(Number(battery.percentage || 0) * 100) : -1

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function glyph(code) {
    return String.fromCodePoint(code)
  }

  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) seconds = 0
    var s = Math.floor(seconds)
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  function batteryGlyph() {
    if (battery && battery.state === UPowerDeviceState.Charging) return glyph(0xF0084)
    var steps = [0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]
    return glyph(steps[Math.max(0, Math.min(10, Math.round(batteryLevel / 10)))])
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onFailedAttemptsChanged: if (failedAttempts > 0) { shake.restart(); castBanshoTenin() }

  // ── Pain effects ───────────────────────────────────────
  // eyeGlow: Rinnegan glow on the avatar's eyes.
  // pain*: drives shaders/shinra.frag over the wallpaper.
  //   click avatar   -> Shinra Tensei (Rinnegan + charge + shockwave)
  //   wrong password -> Bansho Ten'in (space pulled in towards the card)
  // rainTime: Amegakure rain overlay (shaders/rain.frag), always on.
  property real eyeGlow: 0
  property real painCharge: 0
  property real painWave: 0
  property real painFlash: 0
  property real painPull: 0
  property real painShake: 0
  property real painEye: 0
  property real painTime: 0
  property real rainTime: 0
  property real painReach: Math.min(width, height) * 0.3
  property real painRadius: Math.min(width, height) * 0.28
  property point painCenter: Qt.point(width / 2, height / 2)
  // The two giant Rinnegan eyes sit either side of the login card.
  readonly property point painEyeL: Qt.point(width * 0.25, height * 0.37)
  readonly property point painEyeR: Qt.point(width * 0.75, height * 0.37)
  readonly property size painEyeSize: Qt.size(width * 0.13, width * 0.052)
  readonly property bool painActive: painCharge > 0 || painWave > 0 || painPull > 0 || painEye > 0 || painFlash > 0

  // ── Pain quotes ────────────────────────────────────────
  readonly property var painQuotes: [
    "Feel pain, contemplate pain, accept pain, know pain.",
    "Those who do not understand true pain can never understand true peace.",
    "Love breeds sacrifice, which in turn breeds hatred.",
    "From this moment on, the world will know pain.",
    "Justice comes from vengeance, but that justice only breeds more vengeance.",
    "War brings death, injury and pain to both sides."
  ]
  readonly property var shinraQuotes: [
    "Shinra Tensei.",
    "Almighty Push.",
    "Know pain.",
    "This world shall know pain."
  ]
  property int quoteIndex: Math.floor(Math.random() * painQuotes.length)
  property int shinraQuoteIndex: 0
  property real quoteType: 1
  property bool shinraQuoteActive: false
  readonly property bool quoteInShinra: shinraQuoteActive && painActive

  function castShinraTensei() {
    eyeFlashAnim.stop()
    banshoAnim.stop()
    shinraQuoteIndex = Math.floor(Math.random() * shinraQuotes.length)
    painCenter = avatar.mapToItem(stage, avatar.width / 2, avatar.height / 2)
    painReach = Math.min(width, height) * 0.3
    painRadius = Math.min(width, height) * 0.28
    painPull = 0
    shinraQuoteActive = true
    shinraAnim.restart()
  }

  // Wrong password: space is yanked in towards the login card.
  function castBanshoTenin() {
    if (shinraAnim.running) return
    eyeFlashAnim.stop()
    painCenter = loginCard.mapToItem(stage, loginCard.width / 2, loginCard.height / 2)
    painReach = loginCard.width * 0.55
    painRadius = loginCard.width * 0.1
    shinraQuoteActive = false
    banshoAnim.restart()
  }

  SequentialAnimation {
    id: shinraAnim
    PropertyAction { target: root; property: "painWave"; value: 0 }
    PropertyAction { target: root; property: "quoteType"; value: 0 }
    NumberAnimation { target: root; property: "eyeGlow"; to: 1; duration: 200; easing.type: Easing.OutQuad }
    // charge: the Rinnegan opens, the world dims and is drawn in
    ParallelAnimation {
      NumberAnimation { target: root; property: "painCharge"; from: 0; to: 1; duration: 800; easing.type: Easing.InQuad }
      NumberAnimation { target: root; property: "painEye"; from: 0; to: 1; duration: 650; easing.type: Easing.OutBack }
      SequentialAnimation {
        PauseAnimation { duration: 250 }
        NumberAnimation { target: root; property: "quoteType"; from: 0; to: 1; duration: 700 }
      }
    }
    // release: Shinra Tensei
    PropertyAction { target: root; property: "painFlash"; value: 1 }
    PropertyAction { target: root; property: "painShake"; value: 16 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "painWave"; from: 0.001; to: 1; duration: 2300; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "painFlash"; to: 0; duration: 450; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "painShake"; to: 0; duration: 1000; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "painCharge"; to: 0; duration: 700 }
    }
    PauseAnimation { duration: 700 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "painEye"; to: 0; duration: 700; easing.type: Easing.InQuad }
      NumberAnimation { target: root; property: "eyeGlow"; to: 0; duration: 900 }
    }
    PropertyAction { target: root; property: "painWave"; value: 0 }
    PropertyAction { target: root; property: "shinraQuoteActive"; value: false }
  }

  SequentialAnimation {
    id: banshoAnim
    PropertyAction { target: root; property: "painEye"; value: 0 }
    PropertyAction { target: root; property: "painWave"; value: 0 }
    PropertyAction { target: root; property: "painShake"; value: 7 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "eyeGlow"; to: 1; duration: 160; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "painPull"; to: 1; duration: 380; easing.type: Easing.OutCubic }
    }
    ParallelAnimation {
      NumberAnimation { target: root; property: "painShake"; to: 0; duration: 700 }
      SequentialAnimation {
        PauseAnimation { duration: 700 }
        NumberAnimation { target: root; property: "painPull"; to: 0; duration: 550; easing.type: Easing.InQuad }
      }
    }
    NumberAnimation { target: root; property: "eyeGlow"; to: 0; duration: 900 }
  }

  NumberAnimation on painTime {
    running: root.painActive
    loops: Animation.Infinite
    from: 0
    to: 1000
    duration: 1000000
  }

  NumberAnimation on rainTime {
    running: true
    loops: Animation.Infinite
    from: 0
    to: 100000
    duration: 100000000
  }

  function eyeFlash() {
    if (!shinraAnim.running && !banshoAnim.running) eyeFlashAnim.restart()
  }

  SequentialAnimation {
    id: eyeFlashAnim
    NumberAnimation { target: root; property: "eyeGlow"; to: 1; duration: 350; easing.type: Easing.InOutSine }
    PauseAnimation { duration: 900 }
    NumberAnimation { target: root; property: "eyeGlow"; to: 0; duration: 900; easing.type: Easing.InOutSine }
  }

  // Rinnegan pulse now and then while idle.
  Timer {
    interval: 14000
    running: true
    repeat: true
    onTriggered: root.eyeFlash()
  }
  Timer {
    interval: 700
    running: true
    onTriggered: root.eyeFlash()
  }


  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  // MPRIS position isn't pushed; poke it so the progress bar moves.
  Timer {
    interval: 1000
    running: root.hasMedia && root.player.isPlaying
    repeat: true
    onTriggered: root.player.positionChanged()
  }

  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    id: stage
    anchors.fill: parent
    color: Commons.Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
      visible: false
    }

    // Visible background: softly blurred and dimmed so the glass reads.
    MultiEffect {
      id: sceneBg
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      visible: wallpaper.status === Image.Ready
      blurEnabled: true
      blur: 0.0
      blurMax: 48
      brightness: -0.06
      saturation: 0.1
    }

    // Shinra Tensei / Bansho Ten'in layer, drawn over the wallpaper only while active.
    ShaderEffectSource {
      id: bgSrc
      sourceItem: sceneBg
      visible: false
    }
    Image {
      id: rinneganImg
      source: Qt.resolvedUrl("assets/rinnegan.png")
      sourceSize.width: 1024
      sourceSize.height: 1024
      mipmap: true
      visible: false
    }
    ShaderEffect {
      id: painFx
      anchors.fill: sceneBg
      visible: root.painActive
      fragmentShader: Qt.resolvedUrl("shaders/shinra.frag.qsb")
      property var source: bgSrc
      property var eyeTex: rinneganImg
      property size res: Qt.size(width, height)
      property point center: root.painCenter
      property real radius: root.painRadius
      property point eyeL: root.painEyeL
      property point eyeR: root.painEyeR
      property size eyeSize: root.painEyeSize
      property real reach: root.painReach
      property real eye: root.painEye
      property real charge: root.painCharge
      property real wave: root.painWave
      property real flash: root.painFlash
      property real pull: root.painPull
      property real shake: root.painShake
      property real time: root.painTime
    }

    // Heavily blurred copy the glass cards sample from.
    MultiEffect {
      id: frost
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      visible: false
      blurEnabled: true
      blur: 1.0
      blurMax: 64
      brightness: 0.04
    }

    // Shared textures the liquid glass cards refract.
    ShaderEffectSource {
      id: sceneTex
      // The glass refracts Shinra Tensei / Bansho Ten'in too.
      sourceItem: painFx.visible ? painFx : sceneBg
      visible: false
    }
    ShaderEffectSource {
      id: frostTex
      sourceItem: frost
      visible: false
    }

    // Vignette towards the bottom keeps the music card legible.
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.15) }
        GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.0) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.35) }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // ── Clock ──────────────────────────────────────────────
    Column {
      id: clock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Math.round(parent.height * 0.09)
      spacing: Math.round(-8 * root.ui) - timeGlass.pad - dateGlass.pad

      TextGlass {
        id: timeGlass
        anchors.horizontalCenter: parent.horizontalCenter
        backdrop: frostTex
        scene: sceneTex
        bevel: Math.round(9 * root.ui)

        Text {
          text: Qt.formatDateTime(root.now, "HH:mm")
          color: "white"
          font.family: Style.font.family
          font.pixelSize: Math.round(170 * root.ui)
          font.weight: Font.Bold
          font.letterSpacing: Math.round(-4 * root.ui)
        }
      }

      TextGlass {
        id: dateGlass
        anchors.horizontalCenter: parent.horizontalCenter
        backdrop: frostTex
        scene: sceneTex
        bevel: Math.max(2, Math.round(2.5 * root.ui))
        tintAlpha: 0.3
        shadowOffsetY: 2

        Text {
          text: Qt.formatDateTime(root.now, "dddd, d MMMM")
          color: "white"
          font.family: Style.font.family
          font.pixelSize: Math.round(26 * root.ui)
          font.weight: Font.DemiBold
          font.letterSpacing: Math.round(1 * root.ui)
        }
      }
    }

    // ── Battery chip ───────────────────────────────────────
    GlassCard {
      backdrop: frostTex
      scene: sceneTex
      visible: root.batteryLevel >= 0
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: Math.round(28 * root.ui)
      width: batteryRow.implicitWidth + Math.round(32 * root.ui)
      height: Math.round(40 * root.ui)
      radius: height / 2

      Row {
        id: batteryRow
        anchors.centerIn: parent
        spacing: Math.round(8 * root.ui)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.batteryGlyph()
          color: root.batteryLevel <= 15 ? Commons.Color.lock.textError : root.fg
          font.family: root.iconFont
          font.pixelSize: Math.round(18 * root.ui)
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.batteryLevel + "%"
          color: root.fg
          font.family: Style.font.family
          font.pixelSize: Math.round(15 * root.ui)
        }
      }
    }

    // ── Login card ─────────────────────────────────────────
    GlassCard {
      id: loginCard
      backdrop: frostTex
      scene: sceneTex
      width: Math.round(420 * root.ui)
      height: loginColumn.implicitHeight + Math.round(64 * root.ui)
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: Math.round(70 * root.ui)
      radius: Math.round(32 * root.ui)
      tint: "black"
      // the glass darkens while Pain's techniques act on it
      tintAlpha: 0.14 + 0.2 * Math.max(root.painPull, root.painCharge)

      SequentialAnimation {
        id: shake
        NumberAnimation { target: loginCard; property: "offsetX"; to: -14; duration: 50 }
        NumberAnimation { target: loginCard; property: "offsetX"; to: 12; duration: 70 }
        NumberAnimation { target: loginCard; property: "offsetX"; to: -8; duration: 70 }
        NumberAnimation { target: loginCard; property: "offsetX"; to: 4; duration: 60 }
        NumberAnimation { target: loginCard; property: "offsetX"; to: 0; duration: 50 }
      }

      Column {
        id: loginColumn
        anchors.centerIn: parent
        width: parent.width - Math.round(64 * root.ui)
        spacing: Math.round(18 * root.ui)

        // Avatar: Pain (assets/avatar.png). Click to cast Shinra Tensei.
        Item {
          id: avatar
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.round(132 * root.ui)
          height: width

          Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#241433"
            border.width: Math.max(2, Math.round(3 * root.ui))
            border.color: Qt.tint(Qt.rgba(0.62, 0.45, 0.85, 0.75), Qt.rgba(0.78, 0.6, 1, 0.9 * root.eyeGlow))

            Text {
              anchors.centerIn: parent
              visible: face.status !== Image.Ready
              text: root.displayName.charAt(0)
              color: root.fg
              font.family: Style.font.family
              font.pixelSize: Math.round(42 * root.ui)
              font.weight: Font.DemiBold
            }
          }

          Image {
            id: face
            anchors.fill: parent
            anchors.margins: Math.max(2, Math.round(3 * root.ui))
            source: Qt.resolvedUrl("assets/avatar.png")
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            visible: false
          }

          Rectangle {
            id: faceMask
            anchors.fill: face
            radius: width / 2
            visible: false
            layer.enabled: true
          }

          MultiEffect {
            anchors.fill: face
            source: face
            visible: face.status === Image.Ready
            maskEnabled: true
            maskSource: faceMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
          }

          // Rinnegan glow on the eyes (positions in assets/avatar.png, 512px).
          Repeater {
            model: [Qt.point(211 / 512, 219 / 512), Qt.point(299.75 / 512, 219 / 512)]
            delegate: Item {
              required property point modelData
              width: face.width * 0.09
              height: width
              x: face.x + modelData.x * face.width - width / 2
              y: face.y + modelData.y * face.height - height / 2
              opacity: root.eyeGlow
              visible: opacity > 0.01

              Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.9
                height: width * 0.7
                radius: height / 2
                color: "#a46bff"
                opacity: 0.6
                layer.enabled: true
                layer.effect: MultiEffect {
                  blurEnabled: true
                  blur: 1.0
                  blurMax: 24
                }
              }
              Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.7
                height: width * 0.6
                radius: height / 2
                color: "#efe2ff"
                opacity: 0.35
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.wakeRequested()
              root.castShinraTensei()
              root.forcePasswordFocus()
            }
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Welcome back, " + root.displayName
          color: "white"
          style: Text.Raised
          styleColor: Qt.rgba(0, 0, 0, 0.35)
          font.family: Style.font.family
          font.pixelSize: Math.round(20 * root.ui)
          font.weight: Font.Medium
        }

        Rectangle {
          id: inputField
          width: parent.width
          height: Math.round(54 * root.ui)
          radius: height / 2
          color: Qt.rgba(1, 1, 1, passwordInput.activeFocus ? 0.10 : 0.06)
          border.width: root.errorState || passwordInput.activeFocus ? 2 : 1
          border.color: root.errorState
            ? Commons.Color.lock.borderError
            : (passwordInput.activeFocus ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8) : Qt.rgba(1, 1, 1, 0.18))
          clip: true

          Behavior on border.color { ColorAnimation { duration: 150 } }

          Text {
            id: lockIcon
            anchors.left: parent.left
            anchors.leftMargin: Math.round(20 * root.ui)
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph(0xF033E)
            color: Commons.Color.lock.placeholder
            font.family: root.iconFont
            font.pixelSize: Math.round(18 * root.ui)
          }

          TextInput {
            id: passwordInput
            anchors.fill: parent
            anchors.leftMargin: Math.round(48 * root.ui) + root.fingerprintReserve
            anchors.rightMargin: Math.round(48 * root.ui) + root.fingerprintReserve
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            activeFocusOnPress: true
            clip: true
            enabled: root.inputEnabled && !root.authenticatingPassword
            readOnly: root.authenticatingPassword
            echoMode: TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            color: root.fg
            selectionColor: Commons.Color.lock.selection
            selectedTextColor: root.fg
            font.family: Style.font.family
            font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
            font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
            cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
            cursorDelegate: Rectangle {
              width: 2
              color: root.fg
              visible: passwordInput.cursorVisible
            }

            onTextChanged: {
              if (!root.syncingPasswordText) root.passwordTextEdited(text)
              if (text.length > 0) root.wakeRequested()
              if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
            }

            onAccepted: {
              var submitted = root.passwordText
              root.passwordTextEdited("")
              if (submitted.length > 0) root.submitPassword(submitted)
            }

            Keys.onPressed: function(event) {
              root.wakeRequested()
              if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                root.passwordTextEdited("")
                event.accepted = true
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.fill: passwordInput
            text: root.authenticatingPassword ? "Checking…" : (root.errorState ? root.failureMessage : root.placeholderText)
            visible: passwordInput.text.length === 0
            color: root.authenticatingPassword ? root.fg : (root.errorState ? Commons.Color.lock.textError : Commons.Color.lock.placeholder)
            font.family: Style.font.family
            font.pixelSize: Math.round(16 * root.ui)
            font.italic: !root.authenticatingPassword && root.errorState
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }

          Text {
            id: fingerprintIcon
            objectName: "fingerprintIndicator"
            anchors.right: parent.right
            anchors.rightMargin: Math.round(20 * root.ui)
            anchors.verticalCenter: parent.verticalCenter
            visible: root.fingerprintConfigured
            text: root.glyph(0xF0237)
            color: Commons.Color.lock.placeholder
            font.family: root.iconFont
            font.pixelSize: Math.round(20 * root.ui)
          }
        }
      }
    }

    // ── Pain quote ────────────────────────────────────────
    Column {
      id: quote
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: loginCard.bottom
      anchors.topMargin: Math.round(26 * root.ui)
      width: Math.min(parent.width - 64, Math.round(820 * root.ui))
      spacing: Math.round(6 * root.ui)

      readonly property string full: root.quoteInShinra
        ? root.shinraQuotes[root.shinraQuoteIndex]
        : root.painQuotes[root.quoteIndex]
      readonly property string shown: root.quoteInShinra
        ? full.substring(0, Math.round(full.length * root.quoteType))
        : full

      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: root.quoteInShinra ? "#9a5cff" : "black"
        shadowBlur: root.quoteInShinra ? 1.0 : 0.6
        shadowOpacity: root.quoteInShinra ? 1.0 : 0.7
        shadowHorizontalOffset: 0
        shadowVerticalOffset: root.quoteInShinra ? 0 : 2
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        text: "“" + quote.shown + (root.quoteInShinra && root.quoteType < 1 ? "▏" : "”")
        color: root.quoteInShinra ? "#f1e8ff" : Qt.rgba(1, 1, 1, 0.88)
        font.family: Style.font.family
        font.pixelSize: Math.round((root.quoteInShinra ? 26 : 17) * root.ui)
        font.italic: !root.quoteInShinra
        font.weight: root.quoteInShinra ? Font.Bold : Font.Normal
        font.letterSpacing: root.quoteInShinra ? Math.round(1.5 * root.ui) : 0
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "— Pain"
        color: root.quoteInShinra ? "#b88cff" : Qt.rgba(0.75, 0.6, 1, 0.9)
        font.family: Style.font.family
        font.pixelSize: Math.round(13 * root.ui)
        font.letterSpacing: Math.round(2 * root.ui)
      }

      // Fade to the next quote every 20 s while idle.
      Timer {
        interval: 20000
        running: !root.quoteInShinra
        repeat: true
        onTriggered: quoteSwap.restart()
      }
      SequentialAnimation {
        id: quoteSwap
        NumberAnimation { target: quote; property: "opacity"; to: 0; duration: 400 }
        ScriptAction { script: root.quoteIndex = (root.quoteIndex + 1) % root.painQuotes.length }
        NumberAnimation { target: quote; property: "opacity"; to: 1; duration: 600 }
      }
    }

    // ── Now playing ────────────────────────────────────────
    GlassCard {
      id: musicCard
      backdrop: frostTex
      scene: sceneTex
      width: Math.round(560 * root.ui)
      height: Math.round(150 * root.ui)
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.round(56 * root.ui)
      radius: Math.round(28 * root.ui)
      visible: opacity > 0
      opacity: root.hasMedia ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 250 } }

      readonly property real pad: Math.round(18 * root.ui)
      readonly property real length: root.hasMedia && root.player.lengthSupported ? root.player.length : 0
      readonly property real position: root.hasMedia && root.player.positionSupported ? root.player.position : 0

      // Album art, rounded.
      Item {
        id: art
        anchors.left: parent.left
        anchors.leftMargin: musicCard.pad
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - musicCard.pad * 2
        height: width

        Rectangle {
          anchors.fill: parent
          radius: Math.round(16 * root.ui)
          color: Qt.rgba(1, 1, 1, 0.08)
          Text {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: root.glyph(0xF0388)
            color: Commons.Color.lock.placeholder
            font.family: root.iconFont
            font.pixelSize: Math.round(40 * root.ui)
          }
        }

        Image {
          id: cover
          anchors.fill: parent
          source: root.hasMedia ? (root.player.trackArtUrl || "") : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize.width: width * 2
          sourceSize.height: height * 2
          visible: false
        }

        Rectangle {
          id: coverMask
          anchors.fill: parent
          radius: Math.round(16 * root.ui)
          visible: false
          layer.enabled: true
        }

        MultiEffect {
          anchors.fill: parent
          source: cover
          visible: cover.status === Image.Ready
          maskEnabled: true
          maskSource: coverMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1.0
        }
      }

      Item {
        anchors.left: art.right
        anchors.leftMargin: musicCard.pad
        anchors.right: parent.right
        anchors.rightMargin: musicCard.pad + Math.round(4 * root.ui)
        anchors.top: art.top
        anchors.bottom: art.bottom

        Column {
          anchors.left: parent.left
          anchors.right: controls.left
          anchors.rightMargin: Math.round(12 * root.ui)
          anchors.top: parent.top
          anchors.topMargin: Math.round(4 * root.ui)
          spacing: Math.round(4 * root.ui)

          Text {
            width: parent.width
            text: root.hasMedia ? (root.player.trackTitle || "Unknown") : ""
            color: root.fg
            elide: Text.ElideRight
            font.family: Style.font.family
            font.pixelSize: Math.round(19 * root.ui)
            font.weight: Font.DemiBold
          }
          Text {
            width: parent.width
            text: root.hasMedia ? (root.player.trackArtist || root.player.identity || "") : ""
            color: root.fg
            opacity: 0.7
            elide: Text.ElideRight
            font.family: Style.font.family
            font.pixelSize: Math.round(15 * root.ui)
          }
        }

        Row {
          id: controls
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: Math.round(4 * root.ui)

          Repeater {
            model: [
              { code: 0xF04AE, action: "previous" },
              { code: -1, action: "toggle" },
              { code: 0xF04AD, action: "next" }
            ]

            delegate: Rectangle {
              required property var modelData
              readonly property bool primary: modelData.action === "toggle"
              width: Math.round((primary ? 46 : 38) * root.ui)
              height: width
              radius: width / 2
              anchors.verticalCenter: parent ? parent.verticalCenter : undefined
              color: primary
                ? Qt.rgba(1, 1, 1, hover.containsMouse ? 0.28 : 0.18)
                : Qt.rgba(1, 1, 1, hover.containsMouse ? 0.12 : 0.0)

              Text {
                anchors.centerIn: parent
                text: root.glyph(modelData.code > 0 ? modelData.code : (root.hasMedia && root.player.isPlaying ? 0xF03E4 : 0xF040A))
                color: root.fg
                font.family: root.iconFont
                font.pixelSize: Math.round((parent.primary ? 22 : 20) * root.ui)
              }

              MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.wakeRequested()
                  if (!root.hasMedia) return
                  if (modelData.action === "previous" && root.player.canGoPrevious) root.player.previous()
                  else if (modelData.action === "next" && root.player.canGoNext) root.player.next()
                  else if (modelData.action === "toggle" && root.player.canTogglePlaying) root.player.togglePlaying()
                  root.forcePasswordFocus()
                }
              }
            }
          }
        }

        // Progress
        Column {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: Math.round(6 * root.ui)
          visible: musicCard.length > 0

          Rectangle {
            width: parent.width
            height: Math.round(5 * root.ui)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.15)

            Rectangle {
              height: parent.height
              radius: parent.radius
              width: parent.width * Math.max(0, Math.min(1, musicCard.position / Math.max(1, musicCard.length)))
              color: root.fg
              Behavior on width { NumberAnimation { duration: 900 } }
            }
          }

          Item {
            width: parent.width
            height: elapsed.implicitHeight
            Text {
              id: elapsed
              text: root.formatTime(musicCard.position)
              color: root.fg
              opacity: 0.6
              font.family: Style.font.family
              font.pixelSize: Math.round(12 * root.ui)
            }
            Text {
              anchors.right: parent.right
              text: root.formatTime(musicCard.length)
              color: root.fg
              opacity: 0.6
              font.family: Style.font.family
              font.pixelSize: Math.round(12 * root.ui)
            }
          }
        }
      }
    }

    // ── Amegakure rain (always falling, over everything) ───
    ShaderEffect {
      anchors.fill: parent
      fragmentShader: Qt.resolvedUrl("shaders/rain.frag.qsb")
      property size res: Qt.size(width, height)
      property real time: root.rainTime
      property real uiScale: root.ui
      property point center: root.painCenter
      property real wave: root.painWave
    }
  }
}
