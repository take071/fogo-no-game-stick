#!/usr/bin/env bash
# Safely eject the card. The device name changes (sda/sdb): ALWAYS check with lsblk.
# Usage: ./eject.sh /dev/sdb
set -u
DEV="${1:?give the device, e.g. /dev/sdb (see: lsblk)}"
[ "$(lsblk -dno RM "$DEV" 2>/dev/null)" = "1" ] || { echo "[refused] $DEV is not a removable device"; exit 1; }
cd ~ && sync
for p in "${DEV}"?*; do udisksctl unmount -b "$p" 2>/dev/null; done
udisksctl power-off -b "$DEV"
