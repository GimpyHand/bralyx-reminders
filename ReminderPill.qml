import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ReminderFlowModel.js" as ReminderFlowModel

BarWidget {
  id: root
  moduleName: "bralyx.reminders"

  property int reminderCount: 0
  property string tooltip: "No reminders"

  readonly property string label: reminderCount > 0 ? String(reminderCount) : ""
  readonly property var verticalLines: ["󰢌", label]
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button.implicitWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    root.runList()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function runList() {
    if (!jsonProc.running) jsonProc.running = true
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Component.onCompleted: {
    root.runList()
    pollTimer.running = true
  }

  Timer {
    id: pollTimer
    interval: 30000
    repeat: true
    onTriggered: root.runList()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("ReminderFlow.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "bralyx.reminders.widget"
    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  Process {
    id: jsonProc
    command: ["reminderctl", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateFromList(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) { root.reminderCount = 0; root.tooltip = "" }
    }
  }

  function updateFromList(raw) {
    var rows = ReminderFlowModel.parseList(raw)
    root.reminderCount = rows.length
    if (rows.length === 0) {
      root.tooltip = "No reminders — click to add one"
      return
    }
    var lines = []
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i]
      var label = r.message && r.message.trim() ? ReminderFlowModel.shortMessage(r.message, 48) : (r.minutes + " min")
      lines.push(label + " · " + (r.atTime || ""))
    }
    root.tooltip = lines.join("\n")
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.label
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : true
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75
    active: root.reminderCount > 0
    tooltipText: root.tooltip
    onPressed: function(b) {
      if (b === Qt.RightButton) root.refresh()
      else root.togglePanel()
    }

    Row {
      visible: !root.vertical
      anchors.centerIn: parent
      spacing: Style.space(2)

      OpticalGlyph {
        text: "󰢌"
        fontFamily: button.fontFamily
        fontSize: button.fontSize
        color: button.active ? button.activeColor : button.foreground
      }

      Text {
        visible: root.reminderCount > 0
        text: root.label
        color: button.active ? button.activeColor : button.foreground
        font.family: button.fontFamily
        font.pixelSize: Style.font.caption
        verticalAlignment: Text.AlignVCenter
      }
    }

    Column {
      visible: root.vertical
      anchors.fill: parent
      Repeater {
        model: root.verticalLines
        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 2 ? button.fontSize * 0.85 : button.fontSize
          color: button.active ? button.activeColor : button.foreground
        }
      }
    }

    Accessible.role: Accessible.Button
    Accessible.name: "Reminders"
    Accessible.description: root.tooltip
  }
}
