import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Keyboard backlight slider. Talks to brightnessctl only through its
// documented -m (machine) output: "device,class,current,percent,max".
// Hides itself on machines without a *kbd_backlight* LED.
Panel {
  id: root
  moduleName: "io.github.douglas.kbd-backlight"
  ipcTarget: "io.github.douglas.kbd-backlight"

  property string device: ""
  property int level: 0
  property int maxLevel: 0
  property int pendingLevel: -1
  property real wheelAccumulator: 0
  readonly property bool available: device !== ""
  readonly property int percent: maxLevel > 0 ? Math.round(level * 100 / maxLevel) : 0

  visible: available
  implicitWidth: available ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  function setLevel(value) {
    if (!available) return
    var next = Math.max(0, Math.min(maxLevel, Math.round(value)))
    level = next
    if (setProc.running) { pendingLevel = next; return }
    pendingLevel = -1
    setProc.command = ["brightnessctl", "-q", "-d", device, "set", String(next)]
    setProc.running = true
  }

  // Third-party plugins may only summon their own id, so go through the
  // omarchy-osd CLI that omarchy-brightness-keyboard also uses.
  function showOsd() {
    Quickshell.execDetached(["omarchy-osd", "-i", "keyboard", "-p", String(percent)])
  }

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  // Firmware hotkeys (Fn+Space on ThinkPads) change the level behind our back
  // and sysfs sends no inotify event, so poll the LED's brightness file. A
  // FileView read is cheap: no process per tick.
  FileView {
    id: brightnessFile
    path: root.available ? "/sys/class/leds/" + root.device + "/brightness" : ""
    printErrors: false
    onLoaded: {
      // Our own write is in flight; its level is the one to show.
      if (setProc.running || root.pendingLevel >= 0) return
      var value = parseInt(String(text() || "").trim(), 10)
      if (!isNaN(value) && value !== root.level) root.level = value
    }
  }

  Timer {
    interval: 1000
    running: root.available
    repeat: true
    onTriggered: brightnessFile.reload()
  }

  Process {
    id: stateProc
    command: ["brightnessctl", "-m", "-l", "-c", "leds"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i].split(",")
          if (f.length < 5 || f[0].indexOf("kbd_backlight") < 0) continue
          root.device = f[0]
          root.level = parseInt(f[2], 10) || 0
          root.maxLevel = parseInt(f[4], 10) || 0
          return
        }
        root.device = ""
      }
    }
  }

  Process {
    id: setProc
    onRunningChanged: if (!running && root.pendingLevel >= 0) root.setLevel(root.pendingLevel)
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.level > 0 ? "󰌌" : "󰥻"
    onPressed: function(b) { root.toggle() }
    onWheelMoved: function(delta) {
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps === 0) return
      var step = Math.max(1, Math.round(root.maxLevel / 10))
      root.setLevel(root.level + wheel.steps * step)
      root.showOsd()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(200))

    content: PanelKeyCatcher {
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.setLevel(root.level + dx * Math.max(1, Math.round(root.maxLevel / 10)))
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        Item {
          width: parent.width
          implicitHeight: header.implicitHeight

          PanelSectionHeader {
            id: header
            text: "Keyboard backlight"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            textFormat: Text.PlainText
            text: Math.round(slider.dragging ? slider.liveValue * 100 / Math.max(1, root.maxLevel) : root.percent) + "%"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        CursorSurface {
          width: parent.width
          height: slider.implicitHeight + Style.spacing.controlGap
          foreground: root.bar.foreground
          outline: true

          PanelSlider {
            id: slider
            bar: root.bar
            anchors.fill: parent
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(6)
            minimum: 0
            maximum: Math.max(1, root.maxLevel)
            step: 1
            integer: true
            // Few-level keyboards (ThinkPads have 0-2) get a notch per level.
            tickCount: root.maxLevel <= 10 ? root.maxLevel + 1 : 0
            value: root.level
            onReleased: function(v) { root.setLevel(v) }
          }
        }
      }
    }
  }
}
