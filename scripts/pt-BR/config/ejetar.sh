#!/usr/bin/env bash
# Ejeta o cartão com segurança. O nome do dispositivo muda (sda/sdb): confira SEMPRE com lsblk.
# Uso: ./ejetar.sh /dev/sdb
# Erros ao desmontar são mostrados (não escondidos) e param o script ANTES de desligar, então uma
# partição ocupada nunca é desligada por engano.
set -u
DEV="${1:?informe o dispositivo, ex.: /dev/sdb (veja: lsblk)}"
[ -b "$DEV" ] || { echo "[erro] $DEV não é um dispositivo de bloco"; exit 1; }
[ "$(lsblk -dno RM "$DEV" 2>/dev/null)" = "1" ] || { echo "[recusado] $DEV não é um dispositivo removível"; exit 1; }
cd ~ && sync
for p in "${DEV}"?*; do
  [ -b "$p" ] || continue
  findmnt -n "$p" >/dev/null 2>&1 || continue          # não montada: nada a fazer
  udisksctl unmount -b "$p" || { echo "[erro] não foi possível desmontar $p (ocupada? feche terminais/gerenciadores de arquivos que a usam)"; exit 1; }
done
udisksctl power-off -b "$DEV"
