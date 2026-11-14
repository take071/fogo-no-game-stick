#!/usr/bin/env bash
# Tests for scripts/config/set_fastforward.sh and set_enhanced_resolution.sh on a fake card.
# Usage: bash tests/test_config.sh          (English scripts)
#        IMPL=pt bash tests/test_config.sh   (scripts/pt-BR twins)
set -u
# shellcheck disable=SC2034
HERE="$(cd "$(dirname "$0")" && pwd)"; R="$(dirname "$HERE")/scripts"
if [ "${IMPL:-en}" = pt ]; then C="$R/pt-BR/config"; FF=definir_avanco_rapido.sh; ER=definir_resolucao_melhorada.sh; else C="$R/config"; FF=set_fastforward.sh; ER=set_enhanced_resolution.sh; fi
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; export SD="$T"
mkdir -p "$T/timer" "$T/retro_lib"
PASS=0; FAIL=0
ok() { if eval "$2"; then PASS=$((PASS+1)); echo "  ok   - $1"; else FAIL=$((FAIL+1)); echo "  FAIL - $1   [$2]"; fi; }
printf 'video_smooth = "true"\nfastforward_ratio = "0.000000"\ninput_hold_fast_forward = "l"\n' > "$T/timer/gbx_mod.cfg"

echo "== set_fastforward.sh"
bash "$C/$FF" 2.5 >/dev/null 2>&1
ok "2.5 -> 2.500000" 'grep -q "^fastforward_ratio = \"2.500000\"$" "$T/timer/gbx_mod.cfg"'
ok "other lines untouched" 'grep -q "^input_hold_fast_forward = \"l\"$" "$T/timer/gbx_mod.cfg" && grep -q "^video_smooth" "$T/timer/gbx_mod.cfg"'
ok "backup made once" '[ -f "$T/timer/gbx_mod.cfg.bak_pre_ff" ] && grep -q "0.000000" "$T/timer/gbx_mod.cfg.bak_pre_ff"'
bash "$C/$FF" 3,0 >/dev/null 2>&1
ok "comma input 3,0 -> 3.000000 (dot in the file)" 'grep -q "^fastforward_ratio = \"3.000000\"$" "$T/timer/gbx_mod.cfg"'
bash "$C/$FF" 0 >/dev/null 2>&1
ok "0 disables" 'grep -q "^fastforward_ratio = \"0.000000\"$" "$T/timer/gbx_mod.cfg"'
ok "second backup does not overwrite the first" 'grep -q "0.000000" "$T/timer/gbx_mod.cfg.bak_pre_ff"'
bash "$C/$FF" abc >/dev/null 2>&1; ok "rejects non-number" '[ $? -ne 0 ]'
# the comma-locale case is simulated through the dot normalisation; see MELHORIAS.md for the caveat
printf 'video_smooth = "true"\n' > "$T/timer/gbx_mod.cfg"
bash "$C/$FF" 2.5 >/dev/null 2>&1; ok "missing key: fails and does not touch file" '[ $? -ne 0 ] && ! grep -q fastforward "$T/timer/gbx_mod.cfg"'

echo "== set_enhanced_resolution.sh"
printf 'pcsx_rearmed_neon_enhancement_enable = "disabled"\npcsx_rearmed_neon_enhancement_no_main = "disabled"\nother = "x"\n' > "$T/retro_lib/retroarch-core-options.cfg"
bash "$C/$ER" enabled >/dev/null 2>&1
ok "enabled applied" 'grep -q "^pcsx_rearmed_neon_enhancement_enable = \"enabled\"$" "$T/retro_lib/retroarch-core-options.cfg"'
ok "no_main left alone" 'grep -q "^pcsx_rearmed_neon_enhancement_no_main = \"disabled\"$" "$T/retro_lib/retroarch-core-options.cfg"'
bash "$C/$ER" check >/dev/null 2>&1; ok "check passes on well-formed file" '[ $? -eq 0 ]'
printf 'pcsx_rearmed_neon_enhancement_enable = "enabled"\npcsx_rearmed_neon_enhancement_no_main = "disabled\n' > "$T/retro_lib/retroarch-core-options.cfg"
bash "$C/$ER" check >/dev/null 2>&1; ok "check catches the missing closing quote (doc 03 pending item)" '[ $? -ne 0 ]'
printf 'other = "x"\n' > "$T/retro_lib/retroarch-core-options.cfg"
bash "$C/$ER" enabled >/dev/null 2>&1; ok "missing key: fails" '[ $? -ne 0 ]'

echo; echo "RESULT: $PASS passed, $FAIL failed"; [ "$FAIL" = 0 ]
