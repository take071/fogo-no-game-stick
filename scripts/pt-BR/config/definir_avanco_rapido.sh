#!/usr/bin/env bash
# Muda o fastforward_ratio usado nos jogos de GBA (arquivo timer/gbx_mod.cfg no cartão).
# Uso: SD=/run/media/user/<LABEL> ./definir_avanco_rapido.sh 2.5      (0 = desligado)
set -u
: "${SD:?defina SD}"; V="${1:?informe um valor, ex.: 2.5}"
F="$SD/timer/gbx_mod.cfg"
[ -f "$F" ] || { echo "[erro] $F não encontrado"; exit 1; }
cp -n "$F" "$F.bak_pre_ff"
VAL=$(printf '%.6f' "$V")
sed -i "s/^fastforward_ratio = .*/fastforward_ratio = \"$VAL\"/" "$F"
grep -n '^fastforward_ratio' "$F"; sync
