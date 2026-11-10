#!/usr/bin/env bash
# Liga/desliga a "Enhanced Resolution" (NEON) do PCSX-ReARMed. Faz backup antes.
# Uso: SD=/run/media/user/<LABEL> ./definir_resolucao_melhorada.sh enabled|disabled
set -u
: "${SD:?defina SD}"; V="${1:?enabled|disabled}"
case "$V" in enabled|disabled) ;; *) echo "use enabled ou disabled"; exit 1 ;; esac
F="$SD/retro_lib/retroarch-core-options.cfg"
[ -f "$F" ] || { echo "[erro] $F não encontrado"; exit 1; }
cp -n "$F" "$F.bak_pre_neon"
sed -i "s/^pcsx_rearmed_neon_enhancement_enable = .*/pcsx_rearmed_neon_enhancement_enable = \"$V\"/" "$F"
grep -n 'neon' "$F"; sync
