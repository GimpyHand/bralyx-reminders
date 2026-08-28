#!/usr/bin/env bash
# Put reminderctl on PATH. Idempotent: re-running replaces ~/.local/bin/reminderctl
# with the copy shipped in this plugin. Does not edit Omarchy config.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/reminderctl"
dest_dir="${HOME}/.local/bin"
dest="${dest_dir}/reminderctl"

if [[ ! -f $src || -L $src ]]; then
  echo "missing or invalid source: $src" >&2
  exit 1
fi

mkdir -p "$dest_dir"

if [[ -L $dest_dir ]]; then
  echo "refusing symlink parent directory: $dest_dir" >&2
  exit 1
fi
if [[ ! -d $dest_dir ]]; then
  echo "parent is not a directory: $dest_dir" >&2
  exit 1
fi

if [[ -e $dest || -L $dest ]]; then
  if [[ -L $dest ]]; then
    echo "refusing to overwrite symlink: $dest" >&2
    exit 1
  fi
  if [[ ! -f $dest ]]; then
    echo "refusing non-regular destination: $dest" >&2
    exit 1
  fi
fi

tmp=$(mktemp -p "$dest_dir" ".reminderctl.XXXXXX")
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT

cp "$src" "$tmp"
chmod 755 "$tmp"

if [[ -L $dest ]]; then
  echo "refusing to overwrite symlink: $dest" >&2
  exit 1
fi
if [[ -e $dest && ! -f $dest ]]; then
  echo "refusing non-regular destination: $dest" >&2
  exit 1
fi

mv -f "$tmp" "$dest"
trap - EXIT
echo "installed $dest"
