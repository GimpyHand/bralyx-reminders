var MAX_MESSAGE = 500
var MAX_STDOUT = 65536

function validMinutes(value) {
  var minutes = String(value || "").trim()
  if (!/^[1-9][0-9]{0,6}$/.test(minutes)) return ""
  if (Number(minutes) > 999999) return ""
  return minutes
}

function isValidUnit(value) {
  return /^omarchy-reminder-[0-9]+m-[0-9]+$/.test(String(value || "").trim())
}

function capText(value, max) {
  var text = String(value || "")
  max = max || MAX_MESSAGE
  return text.length > max ? text.substring(0, max) : text
}

function capStdout(value) {
  return capText(value, MAX_STDOUT)
}

function capMessage(value) {
  return capText(value, MAX_MESSAGE)
}

function reminderArgs(minutes) {
  var valid = validMinutes(minutes)
  if (!valid) return []
  return [valid]
}

function clampUnit(value) {
  return String(value || "").trim()
}

function parseList(raw) {
  var data = {}
  try { data = JSON.parse(capStdout(raw)) } catch (e) { data = {} }
  var items = Array.isArray(data.reminders) ? data.reminders : []
  var out = []
  for (var i = 0; i < items.length; i++) {
    var row = items[i]
    if (!row || !isValidUnit(row.unit)) continue
    if (row.message != null) row.message = capMessage(row.message)
    out.push(row)
  }
  return out
}

function isBlank(value) {
  return String(value || "").trim().length === 0
}

function shortMessage(value, max) {
  var text = capMessage(value).replace(/\s+/g, " ").trim()
  max = max || 90
  return text.length > max ? text.substring(0, max - 1) + "…" : text
}

function remainingLabel(seconds) {
  var s = Number(seconds)
  if (isNaN(s) || s < 0) return ""
  var days = Math.floor(s / 86400)
  var hours = Math.floor((s % 86400) / 3600)
  var minutes = Math.floor((s % 3600) / 60)
  var rem = Math.floor(s % 60)
  if (days > 0) return hours > 0 ? days + "d " + hours + "h" : days + "d"
  if (hours > 0) return minutes > 0 ? hours + "h " + minutes + "m" : hours + "h"
  if (minutes > 0 && rem > 0) return minutes + "m " + rem + "s"
  if (minutes > 0) return minutes + "m"
  return rem + "s"
}

function formatDelay(seconds) {
  var s = Math.max(0, Math.ceil(Number(seconds) || 0))
  var weeks = Math.floor(s / 604800)
  var days = Math.floor((s % 604800) / 86400)
  var hours = Math.floor((s % 86400) / 3600)
  var minutes = Math.ceil((s % 3600) / 60)
  if (minutes === 60) {
    hours += 1
    minutes = 0
  }
  if (hours === 24) {
    days += 1
    hours = 0
  }
  if (days === 7) {
    weeks += 1
    days = 0
  }
  var parts = []
  if (weeks) parts.push(weeks + "w")
  if (days) parts.push(days + "d")
  if (hours) parts.push(hours + "h")
  if (minutes) parts.push(minutes + "m")
  return parts.length ? parts.join("") : "1m"
}

function presetMinutes() {
  return [5, 15, 30, 60]
}

function presetLabel(minutes) {
  var n = Number(minutes)
  if (n >= 60 && n % 60 === 0) return (n / 60) + "h"
  return n + "m"
}

function minutesUntilClock(value) {
  var match = String(value || "").trim().match(/^(\d{1,2}):(\d{2})$/)
  if (!match) return ""
  var hour = Number(match[1])
  var minute = Number(match[2])
  if (hour > 23 || minute > 59) return ""
  var now = new Date()
  var target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, minute, 0, 0)
  if (target.getTime() <= now.getTime()) target.setDate(target.getDate() + 1)
  var mins = Math.ceil((target.getTime() - now.getTime()) / 60000)
  return mins > 0 ? String(mins) : ""
}

function parseDelay(value) {
  var text = String(value || "").trim().toLowerCase()
  if (!text) return ""
  if (text.indexOf(":") !== -1) return minutesUntilClock(text)
  var compact = text.replace(/\s+/g, "")
  if (/^\d+$/.test(compact)) return validMinutes(compact)
  if (!/^(\d+[wdhm])+$/.test(compact)) return ""
  var total = 0
  var re = /(\d+)([wdhm])/g
  var match
  while ((match = re.exec(compact))) {
    var n = Number(match[1])
    if (match[2] === "w") total += n * 10080
    else if (match[2] === "d") total += n * 1440
    else if (match[2] === "h") total += n * 60
    else total += n
  }
  return total > 0 ? validMinutes(String(total)) : ""
}

function remainingFromAt(at, nowTs) {
  var seconds = Number(at) - Number(nowTs)
  if (isNaN(seconds)) return 0
  return seconds < 0 ? 0 : seconds
}

function dueLabel(at) {
  var date = new Date(Number(at) * 1000)
  if (isNaN(date.getTime())) return ""
  var year = date.getFullYear()
  var month = String(date.getMonth() + 1)
  var day = String(date.getDate())
  if (month.length < 2) month = "0" + month
  if (day.length < 2) day = "0" + day
  var hour24 = date.getHours()
  var minute = String(date.getMinutes())
  if (minute.length < 2) minute = "0" + minute
  var ampm = hour24 >= 12 ? "PM" : "AM"
  var hour12 = hour24 % 12
  if (hour12 === 0) hour12 = 12
  var hour = String(hour12)
  if (hour.length < 2) hour = "0" + hour
  return year + "-" + month + "-" + day + " " + hour + ":" + minute + " " + ampm
}

function delayParts(seconds) {
  var totalMin = Math.max(0, Math.ceil((Number(seconds) || 0) / 60))
  return {
    days: Math.floor(totalMin / 1440),
    hours: Math.floor((totalMin % 1440) / 60),
    minutes: totalMin % 60
  }
}

function minutesFromParts(days, hours, minutes) {
  var total = Number(days || 0) * 1440 + Number(hours || 0) * 60 + Number(minutes || 0)
  return total > 0 ? validMinutes(String(total)) : ""
}

function addMinutesToParts(days, hours, minutes, extraMinutes) {
  var total = Number(days || 0) * 1440 + Number(hours || 0) * 60 + Number(minutes || 0) + Number(extraMinutes || 0)
  if (total < 1) total = 1
  return delayParts(total * 60)
}

if (typeof module !== "undefined") {
  module.exports = {
    MAX_MESSAGE: MAX_MESSAGE,
    MAX_STDOUT: MAX_STDOUT,
    validMinutes: validMinutes,
    isValidUnit: isValidUnit,
    capText: capText,
    capStdout: capStdout,
    capMessage: capMessage,
    reminderArgs: reminderArgs,
    clampUnit: clampUnit,
    parseList: parseList,
    isBlank: isBlank,
    shortMessage: shortMessage,
    remainingLabel: remainingLabel,
    formatDelay: formatDelay,
    presetMinutes: presetMinutes,
    presetLabel: presetLabel,
    minutesUntilClock: minutesUntilClock,
    parseDelay: parseDelay,
    remainingFromAt: remainingFromAt,
    dueLabel: dueLabel,
    delayParts: delayParts,
    minutesFromParts: minutesFromParts,
    addMinutesToParts: addMinutesToParts
  }
}
