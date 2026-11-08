#!/usr/bin/env bash
# Toggle PCSX-ReARMed "Enhanced Resolution" (NEON). Makes a backup first.
# Usage: SD=/run/media/user/<LABEL> ./set_enhanced_resolution.sh enabled|disabled
set -u
: "${SD:?set SD}"; V="${1:?enabled|disabled}"
case "$V" in enabled|disabled) ;; *) echo "use enabled or disabled"; exit 1 ;; esac
F="$SD/retro_lib/retroarch-core-options.cfg"
[ -f "$F" ] || { echo "[error] $F not found"; exit 1; }
cp -n "$F" "$F.bak_pre_neon"
sed -i "s/^pcsx_rearmed_neon_enhancement_enable = .*/pcsx_rearmed_neon_enhancement_enable = \"$V\"/" "$F"
grep -n 'neon' "$F"; sync
