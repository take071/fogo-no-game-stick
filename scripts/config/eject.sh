#!/usr/bin/env bash
# Safely eject the card. The device name changes (sda/sdb): ALWAYS check with lsblk.
# Usage: ./eject.sh /dev/sdb
# Unmount errors are shown (not hidden) and stop the script BEFORE power-off, so a busy
# partition can never be powered off by mistake.
set -u
DEV="${1:?give the device, e.g. /dev/sdb (see: lsblk)}"
[ -b "$DEV" ] || { echo "[error] $DEV is not a block device"; exit 1; }
[ "$(lsblk -dno RM "$DEV" 2>/dev/null)" = "1" ] || { echo "[refused] $DEV is not a removable device"; exit 1; }
cd ~ && sync
for p in "${DEV}"?*; do
  [ -b "$p" ] || continue
  findmnt -n "$p" >/dev/null 2>&1 || continue          # not mounted: nothing to do
  udisksctl unmount -b "$p" || { echo "[error] could not unmount $p (busy? close terminals/file managers using it)"; exit 1; }
done
udisksctl power-off -b "$DEV"
