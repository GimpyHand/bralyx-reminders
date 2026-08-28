# Due

A bar pill and popup for the [Omarchy](https://omarchy.org) Quattro shell. Create, list, snooze, edit, and delete desktop notification reminders. State lives in systemd user timers (no daemon, no network).

Plugin id: `bralyx.reminders`. Disable the built-in `omarchy.reminders` overlay while this is enabled so you do not get two reminder UIs:

```sh
omarchy plugin disable omarchy.reminders
```

## Install

```sh
omarchy plugin add https://github.com/GimpyHand/bralyx-reminders.git --enable
~/.config/omarchy/plugins/bralyx.reminders/install.sh
omarchy bar move bralyx.reminders --section right
```

`install.sh` copies `bin/reminderctl` to `~/.local/bin/reminderctl` and `chmod +x`. Re-running it is safe. The pill and popup call `reminderctl` from `PATH`, so `~/.local/bin` must be on your `PATH` (it is on a default Omarchy user session).

`omarchy plugin add` is what enables the plugin. `install.sh` only installs the helper binary. It does not edit `shell.json`.

## Dependencies

Stock Omarchy already provides these:

- `systemd` user session (`systemctl --user`, `systemd-run`)
- `jq` (JSON output from `reminderctl list`)
- `omarchy-notification-send` and `omarchy-shell` (fired reminders open the manager popup)

No `sudo`, `pkexec`, extra packages, or network access.

## Usage

Click the bell pill to open the manager from the bar. Right-click the pill to refresh the count. Click a fired notification to open the same popup.

Each reminder has snooze chips (5m / 15m / 30m / 1h), **Edit**, and **Delete**. New reminders: type a message, then click a duration chip or enter `15m` / `2h` / `1d` / `1w` / `HH:MM` and **Add**. Edit uses Days / Hours / Minutes fields.

Keyboard:

- `↑` `↓` — select
- `Enter` — snooze 5 minutes
- `E` — edit
- `Del` or `X` — delete
- `N` — new reminder
- `Esc` — close

```sh
reminderctl list
printf '%s' "Check the oven" | reminderctl set 15
reminderctl cancel <unit>
reminderctl snooze <unit> 10
printf '%s' "new message" | reminderctl edit <unit> 20
```

`set` / `edit` take the reminder message from **stdin** (max 500 bytes), never argv, so private text is not exposed in `/proc/<pid>/cmdline`.
## Configure

```sh
omarchy bar move bralyx.reminders --section right
```

## Remove

```sh
omarchy plugin remove bralyx.reminders
rm -f ~/.local/bin/reminderctl
```

`omarchy plugin remove` deletes the plugin folder. It does not remove `~/.local/bin/reminderctl` or already-armed systemd user timers. Cancel leftovers with `reminderctl list` / `reminderctl cancel` before deleting the helper.

## reminderctl

`bin/reminderctl` is required. It owns create / cancel / snooze / edit / list / fire against one-shot systemd **user** timers named `omarchy-reminder-<minutes>m-<unix>.timer` and sibling `.message` files in `$XDG_RUNTIME_DIR/omarchy-reminders/`. No sudo or pkexec is required. No extra packages, no network.

The `omarchy-reminder-*` timer prefix matches the built-in Omarchy reminder engine so existing timers keep working.
