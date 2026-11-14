#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables are consumed inside eval strings by ok()
# End-to-end tests for the PS1 converter, using the REAL psxpackager and tiny synthetic discs
# (no ROMs needed). Usage:
#   PSX=/path/to/psxpackager IMPL=bash      bash tests/run_tests.sh   # scripts/ps1/convert_ps1.sh
#   PSX=/path/to/psxpackager IMPL=python    bash tests/run_tests.sh   # scripts/ps1/ps1_pbp.py
#   PSX=/path/to/psxpackager IMPL=bash-pt   bash tests/run_tests.sh   # scripts/pt-BR/ps1/converter_ps1.sh
#   PSX=/path/to/psxpackager IMPL=python-pt bash tests/run_tests.sh   # scripts/pt-BR/ps1/ps1_pbp.py
# Needs: python3 + pycdlib (pip install pycdlib). chdman (mame-tools) is optional: CHD test is skipped without it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"
: "${PSX:?set PSX to the psxpackager binary}"
IMPL="${IMPL:-bash}"; SUM0="converted/merged=0"; WARNTAG="WARN"
case "$IMPL" in
  bash)      CMD=(bash "$ROOT/scripts/ps1/convert_ps1.sh") ;;
  python)    CMD=(python3 "$ROOT/scripts/ps1/ps1_pbp.py") ;;
  bash-pt)   CMD=(bash "$ROOT/scripts/pt-BR/ps1/converter_ps1.sh"); SUM0='convertidos/juntados=0'; WARNTAG='AVISO' ;;
  python-pt) CMD=(python3 "$ROOT/scripts/pt-BR/ps1/ps1_pbp.py");   SUM0='convertidos/juntados=0'; WARNTAG='AVISO' ;;
  *) echo "IMPL must be bash, python, bash-pt or python-pt"; exit 2 ;;
esac
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export SD="$T/sd" PSX PSX_TMP="$T/work"; D="$SD/game/ps1"; mkdir -p "$D" "$PSX_TMP"
PASS=0; FAIL=0
ok() { if eval "$2"; then PASS=$((PASS+1)); echo "  ok   - $1"; else FAIL=$((FAIL+1)); echo "  FAIL - $1   [$2]"; fi; }
disc() { python3 "$HERE/make_fake_disc.py" "$1" "$2" >/dev/null; }
magic() { [ "$(head -c4 "$1" | od -An -tx1 | tr -d ' \n')" = "00504250" ]; }
ndiscs() { local v; v="$(mktemp -d "$T/v.XXXX")"; "$PSX" -i "$1" -o "$v" -d "$2" -x -v 1 >/dev/null 2>&1; find "$v" -iname "* - Disc $2.cue" | grep -q .; }
tree_hash() { (cd "$1" && find . -type f -print0 | sort -z | xargs -0 md5sum | md5sum); }

echo "== setup ($IMPL)"
mkdir -p "$D"/{s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11}
disc "$D/s1/Solo (USA)" SLUS_000.01
for n in 1 2 3; do disc "$D/s2/Triplo (USA) (Disc $n)" SLUS_000.0$n; done
printf 'PNG1' > "$D/s2/Triplo (USA) (Disc 1).png"; printf 'PNG2' > "$D/s2/Triplo (USA) (Disc 2).png"
disc "$D/s3/Misto (Disc 1)" SLUS_000.01; disc "$D/s3/Misto (Disc 2)" SLUS_000.02
"$PSX" -i "$D/s3/Misto (Disc 1).cue" -o "$D/s3" -x -v 1 >/dev/null 2>&1; mv "$D/s3/Misto (Disc 1).pbp" "$D/s3/Misto (Disc 1).PBP"
rm "$D/s3/Misto (Disc 1).cue" "$D/s3/Misto (Disc 1).bin"
disc "$D/s4/Quebrado" SLUS_000.01; sed -i 's/Quebrado.bin/Quebrado (Dublado).bin/' "$D/s4/Quebrado.cue"
disc "$D/s5/Pokémon Cópia" SLUS_000.01
HAVE_CHD=0
if command -v chdman >/dev/null 2>&1; then
  disc "$D/s6/Soh Chd" SLUS_000.01
  if chdman createcd -i "$D/s6/Soh Chd.cue" -o "$D/s6/Soh Chd.chd" >/dev/null 2>&1; then HAVE_CHD=1; rm "$D/s6/Soh Chd.cue" "$D/s6/Soh Chd.bin"; fi
fi
disc "$D/s7/Parcial (Disc 1)" SLUS_000.01; disc "$D/s7/Parcial (Disc 3)" SLUS_000.03
printf 'x' > "$D/s8/scph5501.bin"; printf 'FILE "scph5501.bin" BINARY\n TRACK 01 MODE2/2352\n  INDEX 01 00:00:00\n' > "$D/s8/scph5501.cue"
# s9: ONLY single-disc PBPs (already converted) -> must be merged into one
for n in 1 2 3; do
  disc "$D/s9/Soh Pbp (Disc $n)" SLUS_000.0$n
  "$PSX" -i "$D/s9/Soh Pbp (Disc $n).cue" -o "$D/s9" -x -v 1 >/dev/null 2>&1
  mv "$D/s9/Soh Pbp (Disc $n).pbp" "$D/s9/Soh Pbp (Disc $n).PBP"; rm "$D/s9/Soh Pbp (Disc $n).cue" "$D/s9/Soh Pbp (Disc $n).bin"
done
# s10: "(Disc N of M)" naming; s11: "Part 1/Part 2" are NOT discs
for n in 1 2; do disc "$D/s10/Dois (Disc $n of 2)" SLUS_000.0$n; done
disc "$D/s11/Residente Part 1" SLUS_000.01; disc "$D/s11/Residente Part 2" SLUS_000.02
S5CUE_MD5="$(md5sum "$D/s5/Pokémon Cópia.cue" | cut -d' ' -f1)"

echo "== dry-run changes nothing"
H1="$(tree_hash "$D")"; "${CMD[@]}" --dry-run >/dev/null 2>&1; H2="$(tree_hash "$D")"
ok "tree identical after --dry-run" '[ "$H1" = "$H2" ]'

echo "== run 1: convert, keep originals"
"${CMD[@]}" > "$T/run1.log" 2>&1; RC1=$?
ok "single disc -> Solo (USA).PBP is valid" 'magic "$D/s1/Solo (USA).PBP"'
ok "single disc: originals kept" '[ -f "$D/s1/Solo (USA).cue" ] && [ -f "$D/s1/Solo (USA).bin" ]'
ok "3 discs -> ONE Triplo (USA).PBP" 'magic "$D/s2/Triplo (USA).PBP"'
ok "merged PBP really holds 3 discs" 'ndiscs "$D/s2/Triplo (USA).PBP" 3'
ok "no extra single-disc PBPs created for the merged game" '[ ! -e "$D/s2/Triplo (USA) (Disc 1).PBP" ] && [ ! -e "$D/s2/Triplo (USA) (Disc 1).pbp" ]'
ok "Disc 1 cover copied to merged name" '[ -f "$D/s2/Triplo (USA).png" ] && [ "$(cat "$D/s2/Triplo (USA).png")" = PNG1 ]'
ok "mixed (PBP + cue) -> merged Misto.PBP with 2 discs" 'magic "$D/s3/Misto.PBP" && ndiscs "$D/s3/Misto.PBP" 2'
ok "broken .cue reference fixed and converted" 'grep -q "FILE \"Quebrado.bin\"" "$D/s4/Quebrado.cue" && magic "$D/s4/Quebrado.PBP"'
ok "accented .cue untouched byte-for-byte (old script corrupted it)" '[ "$(md5sum "$D/s5/Pokémon Cópia.cue" | cut -d" " -f1)" = "$S5CUE_MD5" ] && magic "$D/s5/Pokémon Cópia.PBP"'
if [ "$HAVE_CHD" = 1 ]; then ok ".chd source converted via chdman" 'magic "$D/s6/Soh Chd.PBP"'; else echo "  skip - .chd test (no chdman)"; fi
ok "incomplete set (discs 1,3) NOT merged" '[ ! -e "$D/s7/Parcial.PBP" ] && grep -q "$WARNTAG" "$T/run1.log"'
ok "BIOS ignored (no PBP, files intact)" '[ ! -e "$D/s8/scph5501.PBP" ] && [ -f "$D/s8/scph5501.bin" ]'
ok "run 1 reports no error" '[ "$RC1" = 0 ]'

ok "only-PBP discs merged into ONE Soh Pbp.PBP with 3 discs" 'magic "$D/s9/Soh Pbp.PBP" && ndiscs "$D/s9/Soh Pbp.PBP" 3'
ok "\"(Disc 1 of 2)\" -> key is just \"Dois\" (old regex gave \"Dois 2)\")" 'magic "$D/s10/Dois.PBP" && ndiscs "$D/s10/Dois.PBP" 2 && ls "$D/s10" | grep -vq "2)"'
ok "\"Part 1\"/\"Part 2\" stay separate games (not merged)" 'magic "$D/s11/Residente Part 1.PBP" && magic "$D/s11/Residente Part 2.PBP" && [ ! -e "$D/s11/Residente.PBP" ]'

echo "== folder as argument (no SD set)"
mkdir -p "$T/pos/sub"; disc "$T/pos/sub/Arg (USA)" SLUS_000.01
env -u SD "${CMD[@]}" "$T/pos" >/dev/null 2>&1
ok "FOLDER argument works without SD, including subfolders" 'magic "$T/pos/sub/Arg (USA).PBP"'

echo "== run 2: idempotent"
"${CMD[@]}" > "$T/run2.log" 2>&1
ok "second run converts nothing new" 'grep -q "$SUM0" "$T/run2.log"'

echo "== run 3: --delete"
"${CMD[@]}" --delete > "$T/run3.log" 2>&1
ok "single: originals removed, PBP kept" '[ ! -e "$D/s1/Solo (USA).cue" ] && [ ! -e "$D/s1/Solo (USA).bin" ] && magic "$D/s1/Solo (USA).PBP"'
ok "merged: all disc sources removed, merged PBP kept" '[ -z "$(ls "$D"/s2/*Disc* 2>/dev/null | grep -v png)" ] && magic "$D/s2/Triplo (USA).PBP"'
ok "merged: per-disc covers removed, merged cover kept" '[ ! -e "$D/s2/Triplo (USA) (Disc 1).png" ] && [ -f "$D/s2/Triplo (USA).png" ]'
ok "mixed: Disc 1 PBP and Disc 2 cue/bin removed" '[ ! -e "$D/s3/Misto (Disc 1).PBP" ] && [ ! -e "$D/s3/Misto (Disc 2).cue" ] && magic "$D/s3/Misto.PBP"'
ok "accented game removed, PBP kept" '[ ! -e "$D/s5/Pokémon Cópia.cue" ] && [ ! -e "$D/s5/Pokémon Cópia.bin" ] && magic "$D/s5/Pokémon Cópia.PBP"'
[ "$HAVE_CHD" = 1 ] && ok ".chd removed, PBP kept" '[ ! -e "$D/s6/Soh Chd.chd" ] && magic "$D/s6/Soh Chd.PBP"'
ok "incomplete set kept even with --delete" '[ -f "$D/s7/Parcial (Disc 1).cue" ] && [ -f "$D/s7/Parcial (Disc 3).cue" ]'
ok "only-PBP discs: the 3 single PBPs removed, merged kept" '[ ! -e "$D/s9/Soh Pbp (Disc 1).PBP" ] && [ ! -e "$D/s9/Soh Pbp (Disc 3).PBP" ] && magic "$D/s9/Soh Pbp.PBP"'
ok "\"of\" discs: sources removed, merged kept" '[ ! -e "$D/s10/Dois (Disc 1 of 2).cue" ] && magic "$D/s10/Dois.PBP"'
ok "Part 1/2: originals removed, both PBPs kept" '[ ! -e "$D/s11/Residente Part 1.cue" ] && magic "$D/s11/Residente Part 2.PBP"'
ok "BIOS never deleted" '[ -f "$D/s8/scph5501.bin" ] && [ -f "$D/s8/scph5501.cue" ]'

echo; echo "RESULT ($IMPL): $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ] || { echo "--- run1.log"; cat "$T/run1.log"; echo "--- run3.log"; cat "$T/run3.log"; exit 1; }
