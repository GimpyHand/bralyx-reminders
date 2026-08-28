import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ReminderFlowModel.js" as ReminderFlowModel

Panel {
  id: root
  moduleName: "due.reminders"
  ipcTarget: "due.reminders"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property var reminders: []
  property int selectedIndex: 0
  property string editingUnit: ""
  property string editMessage: ""
  property int editDays: 0
  property int editHours: 0
  property int editMinutes: 1
  property string pendingDeleteUnit: ""
  property string composerMinutes: "15"
  property var runnerQueue: []
  property var runnerOnDone: function() {}
  property int nowTs: Math.floor(Date.now() / 1000)

  readonly property var presets: ReminderFlowModel.presetMinutes()
  readonly property var extendPresets: [
    { label: "+1h", minutes: 60 },
    { label: "+1d", minutes: 1440 },
    { label: "+1w", minutes: 10080 }
  ]
  readonly property color fg: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool typing: msgField.activeFocus
    || delayField.activeFocus
    || (editDaysField.field && editDaysField.field.activeFocus)
    || (editHoursField.field && editHoursField.field.activeFocus)
    || (editMinutesField.field && editMinutesField.field.activeFocus)
  readonly property int panelWidth: Style.space(420)

  function open() {
    root.controller.show()
    root.resetModes()
    root.refresh()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.resetModes()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function resetModes() {
    root.editingUnit = ""
    root.pendingDeleteUnit = ""
    root.selectedIndex = 0
    if (msgField) msgField.text = ""
    root.editDays = 0
    root.editHours = 0
    root.editMinutes = 1
    if (delayField) delayField.text = ""
  }

  function refresh() {
    root.runReminderctl(["list"], function(raw) {
      root.reminders = ReminderFlowModel.parseList(raw)
      if (root.selectedIndex >= root.reminders.length)
        root.selectedIndex = Math.max(0, root.reminders.length - 1)
    })
  }

  function runReminderctl(args, onDone) {
    root.runnerQueue = root.runnerQueue.concat([{ args: args, onDone: onDone || function() {} }])
    root.pumpRunner()
  }

  function pumpRunner() {
    if (runner.running || root.runnerQueue.length === 0) return
    var job = root.runnerQueue[0]
    var rest = []
    for (var i = 1; i < root.runnerQueue.length; i++) rest.push(root.runnerQueue[i])
    root.runnerQueue = rest
    root.runnerOnDone = job.onDone
    runner.command = ["reminderctl"].concat(job.args)
    runner.running = true
  }

  function currentReminder() {
    if (root.selectedIndex < 0 || root.selectedIndex >= root.reminders.length) return null
    return root.reminders[root.selectedIndex]
  }

  function select(delta) {
    if (root.reminders.length === 0) return
    root.selectedIndex = (root.selectedIndex + delta + root.reminders.length) % root.reminders.length
  }

  function snooze(unit, minutes) {
    if (!ReminderFlowModel.isValidUnit(unit) || !minutes) return
    root.runReminderctl(["snooze", unit, String(minutes)], function() { root.refresh() })
  }

  function saveEdit() {
    var unit = root.editingUnit
    if (!ReminderFlowModel.isValidUnit(unit)) return
    var minutes = ReminderFlowModel.minutesFromParts(root.editDays, root.editHours, root.editMinutes)
    if (!minutes) return
    var message = msgField.text
    root.cancelEdit()
    root.runReminderctl(["edit", unit, minutes].concat(message ? [message] : []), function() { root.refresh() })
  }

  function startEdit(reminder) {
    if (!reminder || !ReminderFlowModel.isValidUnit(reminder.unit)) return
    root.editingUnit = reminder.unit
    root.editMessage = reminder.message || ""
    var parts = ReminderFlowModel.delayParts(ReminderFlowModel.remainingFromAt(reminder.at, root.nowTs))
    root.editDays = parts.days
    root.editHours = parts.hours
    root.editMinutes = Math.max(0, parts.minutes)
    if (editDaysField.field) editDaysField.field.value = root.editDays
    if (editHoursField.field) editHoursField.field.value = root.editHours
    if (editMinutesField.field) editMinutesField.field.value = root.editMinutes
    msgField.text = root.editMessage
    msgField.cursorPosition = 0
    Qt.callLater(function() { msgField.forceActiveFocus() })
  }

  function cancelEdit() {
    root.editingUnit = ""
    root.editMessage = ""
    root.editDays = 0
    root.editHours = 0
    root.editMinutes = 1
    msgField.text = ""
    delayField.text = ""
  }

  function bumpEdit(extraMinutes) {
    var parts = ReminderFlowModel.addMinutesToParts(root.editDays, root.editHours, root.editMinutes, extraMinutes)
    root.editDays = parts.days
    root.editHours = parts.hours
    root.editMinutes = parts.minutes
    if (editDaysField.field) editDaysField.field.value = root.editDays
    if (editHoursField.field) editHoursField.field.value = root.editHours
    if (editMinutesField.field) editMinutesField.field.value = root.editMinutes
  }

  function requestDelete(unit) {
    if (!ReminderFlowModel.isValidUnit(unit)) return
    root.pendingDeleteUnit = unit
  }

  function confirmDelete() {
    var unit = root.pendingDeleteUnit
    root.pendingDeleteUnit = ""
    if (!ReminderFlowModel.isValidUnit(unit)) return
    if (root.editingUnit === unit) root.cancelEdit()
    root.runReminderctl(["cancel", unit], function() { root.refresh() })
  }

  function submitCreate() {
    var minutes = ReminderFlowModel.parseDelay(delayField.text)
    if (!minutes) minutes = ReminderFlowModel.validMinutes(root.composerMinutes)
    if (!minutes) return
    var message = msgField.text.trim()
    msgField.text = ""
    delayField.text = ""
    root.runReminderctl(["set", minutes].concat(message ? [message] : []), function() { root.refresh() })
  }

  function focusComposer() {
    root.cancelEdit()
    Qt.callLater(function() { msgField.forceActiveFocus() })
  }

  Process {
    id: runner
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.runnerOnDone(text)
    }
    onExited: root.pumpRunner()
  }

  Timer {
    interval: 1000
    running: root.opened
    repeat: true
    onTriggered: root.nowTs = Math.floor(Date.now() / 1000)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.panelWidth)
    contentHeight: panel.fittedContentHeight(body.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.typing || root.pendingDeleteUnit !== ""
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.select(dy)
      }
      onCloseRequested: root.close()
      onDeleteRequested: {
        var row = root.currentReminder()
        if (row) root.requestDelete(row.unit)
      }
      onReturnRequested: {
        var row = root.currentReminder()
        if (row) root.snooze(row.unit, 5)
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "n" || t === "N") root.focusComposer()
        else if (t === "e" || t === "E") {
          var row = root.currentReminder()
          if (row) root.startEdit(row)
        }
      }

      Keys.onPressed: function(event) {
        if (root.pendingDeleteUnit !== "") {
          if (confirmDialog.handleKey(event)) event.accepted = true
          return
        }
        if (event.key === Qt.Key_Delete && !root.typing) {
          var row = root.currentReminder()
          if (row) root.requestDelete(row.unit)
          event.accepted = true
        }
      }

      Column {
        id: body
        width: parent.width
        spacing: Style.space(10)

          Text {
            width: parent.width
            text: root.reminders.length === 0
              ? "No reminders"
              : root.reminders.length + (root.reminders.length === 1 ? " reminder" : " reminders")
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
          }

          Repeater {
            model: root.reminders

            delegate: Rectangle {
              id: card
              required property int index
              required property var modelData

              readonly property bool selected: index === root.selectedIndex
              readonly property bool editing: modelData.unit === root.editingUnit
              readonly property int remain: ReminderFlowModel.remainingFromAt(modelData.at, root.nowTs)

              width: body.width
              height: cardColumn.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: (selected || editing) ? Style.hoverFillFor(root.fg, Color.accent) : "transparent"

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.selectedIndex = card.index
              }

              Column {
                id: cardColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(8)
                spacing: Style.space(6)

                Text {
                  width: parent.width
                  text: modelData.message && String(modelData.message).trim()
                    ? ReminderFlowModel.shortMessage(modelData.message, 72)
                    : ("In " + modelData.minutes + " min")
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                  wrapMode: Text.NoWrap
                }

                Text {
                  width: parent.width
                  text: ReminderFlowModel.dueLabel(modelData.at) + " · in " + ReminderFlowModel.remainingLabel(card.remain)
                  color: root.fg
                  opacity: 0.65
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Flow {
                  width: parent.width
                  spacing: Style.space(4)

                  Repeater {
                    model: root.presets
                    Button {
                      required property int modelData
                      text: ReminderFlowModel.presetLabel(modelData)
                      tooltipText: "Snooze " + text
                      foreground: root.fg
                      fontFamily: root.fontFamily
                      fontSize: Style.font.caption
                      horizontalPadding: Style.space(8)
                      verticalPadding: Style.space(4)
                      onClicked: root.snooze(card.modelData.unit, modelData)
                    }
                  }

                  Button {
                    text: "Edit"
                    foreground: root.fg
                    fontFamily: root.fontFamily
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(8)
                    verticalPadding: Style.space(4)
                    onClicked: root.startEdit(card.modelData)
                  }

                  Button {
                    text: "Delete"
                    foreground: root.fg
                    fontFamily: root.fontFamily
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(8)
                    verticalPadding: Style.space(4)
                    onClicked: root.requestDelete(card.modelData.unit)
                  }
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: root.editingUnit !== "" ? "Edit reminder" : "New reminder"
              color: root.fg
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            TextField {
              id: msgField
              width: parent.width
              placeholderText: "What?"
              foreground: root.fg
              font.family: root.fontFamily
              onTextEdited: if (root.editingUnit !== "") root.editMessage = text
              Keys.onReturnPressed: root.editingUnit !== "" ? root.saveEdit() : root.submitCreate()
              Keys.onEnterPressed: root.editingUnit !== "" ? root.saveEdit() : root.submitCreate()
              Keys.onEscapePressed: root.editingUnit !== "" ? root.cancelEdit() : root.close()
            }

            Flow {
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.editingUnit !== "" ? root.extendPresets : root.presets
                Button {
                  required property var modelData
                  text: root.editingUnit !== "" ? modelData.label : ReminderFlowModel.presetLabel(modelData)
                  tooltipText: root.editingUnit !== "" ? ("Add " + text) : ("Remind in " + text)
                  foreground: root.fg
                  fontFamily: root.fontFamily
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(8)
                  verticalPadding: Style.space(4)
                  selected: root.editingUnit === "" && delayField.text === "" && root.composerMinutes === String(modelData)
                  onClicked: {
                    if (root.editingUnit !== "") root.bumpEdit(modelData.minutes)
                    else {
                      root.composerMinutes = String(modelData)
                      delayField.text = ""
                      root.submitCreate()
                    }
                  }
                }
              }
            }

            Row {
              visible: root.editingUnit !== ""
              width: parent.width
              height: visible ? implicitHeight : 0
              clip: true
              spacing: Style.space(8)

              NumberField {
                id: editDaysField
                label: "Days"
                from: 0
                to: 99
                value: root.editDays
                fieldWidth: (parent.width - parent.spacing * 2) / 3
                foreground: root.fg
                fontFamily: root.fontFamily
                onModified: root.editDays = value
              }

              NumberField {
                id: editHoursField
                label: "Hours"
                from: 0
                to: 23
                value: root.editHours
                fieldWidth: (parent.width - parent.spacing * 2) / 3
                foreground: root.fg
                fontFamily: root.fontFamily
                onModified: root.editHours = value
              }

              NumberField {
                id: editMinutesField
                label: "Minutes"
                from: 0
                to: 59
                value: root.editMinutes
                fieldWidth: (parent.width - parent.spacing * 2) / 3
                foreground: root.fg
                fontFamily: root.fontFamily
                onModified: root.editMinutes = value
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: delayField
                visible: root.editingUnit === ""
                width: visible ? parent.width - addBtn.width - parent.spacing : 0
                placeholderText: "15m, 2h, 1d, 1w or 15:30"
                foreground: root.fg
                font.family: root.fontFamily
                Keys.onReturnPressed: root.editingUnit !== "" ? root.saveEdit() : root.submitCreate()
                Keys.onEnterPressed: root.editingUnit !== "" ? root.saveEdit() : root.submitCreate()
                Keys.onEscapePressed: root.editingUnit !== "" ? root.cancelEdit() : root.close()
              }

              Button {
                id: addBtn
                text: root.editingUnit !== "" ? "Save" : "Add"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: root.editingUnit !== "" ? root.saveEdit() : root.submitCreate()
              }

              Button {
                id: cancelBtn
                visible: root.editingUnit !== ""
                width: visible ? implicitWidth : 0
                text: "Cancel"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: root.cancelEdit()
              }
            }
          }
        }

      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        opened: root.pendingDeleteUnit !== ""
        z: 10
        message: "Delete this reminder?"
        confirmText: "Delete"
        background: Color.popups.background
        foreground: root.fg
        scrim: Color.menu.scrim
        selectedBackground: Style.hoverFillFor(root.fg, Color.accent)
        selectedText: Color.accent
        fontFamily: root.fontFamily
        cornerRadius: Style.cornerRadius
        onCanceled: root.pendingDeleteUnit = ""
        onConfirmed: root.confirmDelete()
      }
    }
  }
}
