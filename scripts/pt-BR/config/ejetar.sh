#!/usr/bin/env bash
# Ejeta o cartão com segurança. O nome do dispositivo muda (sda/sdb): SEMPRE confira com lsblk.
# Uso: ./ejetar.sh /dev/sdb
set -u
DEV="${1:?informe o dispositivo, ex.: /dev/sdb (veja: lsblk)}"
[ "$(lsblk -dno RM "$DEV" 2>/dev/null)" = "1" ] || { echo "[recusado] $DEV não é um dispositivo removível"; exit 1; }
cd ~ && sync
for p in "${DEV}"?*; do udisksctl unmount -b "$p" 2>/dev/null; done
udisksctl power-off -b "$DEV"
