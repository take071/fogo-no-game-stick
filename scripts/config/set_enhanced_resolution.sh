#!/usr/bin/env bash
# Toggle PCSX-ReARMed "Enhanced Resolution" (NEON). Makes a backup first.
# Usage: SD=/run/media/user/<LABEL> ./set_enhanced_resolution.sh enabled|disabled|check
#   check  = only show the neon lines and verify each one is well formed (key = "value")
#            (doc 03 reported a line that lost its closing quote: this finds it)
set -u
: "${SD:?set SD}"; V="${1:?enabled|disabled|check}"
case "$V" in enabled|disabled|check) ;; *) echo "use enabled, disabled or check"; exit 1 ;; esac
F="$SD/retro_lib/retroarch-core-options.cfg"
[ -f "$F" ] || { echo "[error] $F not found"; exit 1; }

check() {
  local bad
  grep -n 'neon' "$F"
  bad=$(grep 'neon' "$F" | grep -vcE '^[A-Za-z0-9_]+ = ".*"[[:space:]]*$')
  if [ "$bad" != 0 ]; then echo "[WARN] $bad neon line(s) are not in the form key = \"value\" (missing quote?)"; return 1; fi
  echo "[ok] all neon lines are well formed"
}

[ "$V" = check ] && { check; exit $?; }
grep -q '^pcsx_rearmed_neon_enhancement_enable = ' "$F" || { echo "[error] key pcsx_rearmed_neon_enhancement_enable not found; nothing changed"; exit 1; }
cp -n "$F" "$F.bak_pre_neon"
sed -i "s/^pcsx_rearmed_neon_enhancement_enable = .*/pcsx_rearmed_neon_enhancement_enable = \"$V\"/" "$F"
grep -q "^pcsx_rearmed_neon_enhancement_enable = \"$V\"\$" "$F" || { echo "[error] change did not apply; backup: $F.bak_pre_neon"; exit 1; }
check; rc=$?; sync; exit $rc
