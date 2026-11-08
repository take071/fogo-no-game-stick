#!/usr/bin/env bash
# Change fastforward_ratio used for GBA games (file timer/gbx_mod.cfg on the card).
# Usage: SD=/run/media/user/<LABEL> ./set_fastforward.sh 2.5      (0 = disabled)
set -u
: "${SD:?set SD}"; V="${1:?give a ratio, e.g. 2.5}"
F="$SD/timer/gbx_mod.cfg"
[ -f "$F" ] || { echo "[error] $F not found"; exit 1; }
cp -n "$F" "$F.bak_pre_ff"
VAL=$(printf '%.6f' "$V")
sed -i "s/^fastforward_ratio = .*/fastforward_ratio = \"$VAL\"/" "$F"
grep -n '^fastforward_ratio' "$F"; sync
