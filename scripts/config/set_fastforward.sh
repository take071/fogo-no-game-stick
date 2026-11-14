#!/usr/bin/env bash
# Change fastforward_ratio used for GBA games (file timer/gbx_mod.cfg on the card).
# Usage: SD=/run/media/user/<LABEL> ./set_fastforward.sh 2.5      (0 = disabled)
# Accepts "2.5" or "2,5". The number is always written with a dot, whatever the system locale
# (in pt_BR printf may use a comma, which would break the .cfg).
set -u
: "${SD:?set SD}"; V="${1:?give a ratio, e.g. 2.5}"
[[ $V =~ ^[0-9]+([.,][0-9]+)?$ ]] || { echo "[error] '$V' is not a number (use e.g. 2.5)"; exit 1; }
V="${V/,/.}"
F="$SD/timer/gbx_mod.cfg"
[ -f "$F" ] || { echo "[error] $F not found"; exit 1; }
grep -q '^fastforward_ratio = ' "$F" || { echo "[error] no 'fastforward_ratio = ' line in $F; nothing changed"; exit 1; }
cp -n "$F" "$F.bak_pre_ff"
VAL=$(LC_ALL=C printf '%.6f' "$V")
sed -i "s/^fastforward_ratio = .*/fastforward_ratio = \"$VAL\"/" "$F"
grep -q "^fastforward_ratio = \"$VAL\"\$" "$F" || { echo "[error] change did not apply; backup: $F.bak_pre_ff"; exit 1; }
grep -n '^fastforward_ratio' "$F"; sync
