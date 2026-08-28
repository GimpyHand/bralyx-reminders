#!/usr/bin/env bash
# Put reminderctl on PATH. Idempotent: re-running overwrites ~/.local/bin/reminderctl
# with the copy shipped in this plugin. Does not edit Omarchy config.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/reminderctl"
dest="${HOME}/.local/bin/reminderctl"

if [[ ! -f $src ]]; then
  echo "missing $src" >&2
  exit 1
fi

mkdir -p "$(dirname "$dest")"
cp "$src" "$dest"
chmod +x "$dest"
echo "installed $dest"
