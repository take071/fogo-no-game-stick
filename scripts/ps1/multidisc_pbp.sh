#!/usr/bin/env bash
# Merge several single-disc PBPs into ONE multi-disc PBP (via .m3u).
# STATUS: not tried on a real multi-disc game yet. In PSXPackager 1.6.2 (tested with
# synthetic discs) there is NO extraction flag: passing a .pbp to -i already
# extracts it to .bin/.cue, and an .m3u in -i builds one multi-disc PBP.
# CAUTION: "-x" means "overwrite without asking", NOT "extract".
# Keep your original PBPs until you have tested the result on the stick.
#
# Usage:
#   SD=/run/media/user/<LABEL> PSX=/path/to/psxpackager \
#   NAME="Tales of Destiny II (USA)" DISCS=3 ./multidisc_pbp.sh
# Expects: "$SD/game/ps1/<NAME> (Disc 1).PBP" ... "(Disc N).PBP"
set -u
: "${SD:?set SD}"; : "${PSX:?set PSX}"; : "${NAME:?set NAME}"
DISCS="${DISCS:-3}"
D="$SD/game/ps1"; TMP="$D/_tmp_multidisc"
cd "$D" || exit 1
mkdir -p "$TMP"

# 1) extract each disc to bin/cue
for n in $(seq 1 "$DISCS"); do
  mkdir -p "$TMP/d$n"
  "$PSX" -i "$D/$NAME (Disc $n).PBP" -o "$TMP/d$n" || { echo "[ERROR] disc $n"; exit 1; }
done
find "$TMP" -type f

# 2) build the .m3u with the .cue files, in order
: > "$TMP/$NAME.m3u"
for n in $(seq 1 "$DISCS"); do
  c=$(find "$TMP/d$n" -iname '*.cue' | head -n1)
  [ -n "$c" ] || { echo "[ERROR] no .cue for disc $n"; exit 1; }
  echo "$c" >> "$TMP/$NAME.m3u"
done
cat "$TMP/$NAME.m3u"

# 3) pack into a multi-disc PBP
"$PSX" -i "$TMP/$NAME.m3u" -o "$TMP/out"
ls -lh "$TMP/out"
echo "Check the result, then move it to $D yourself. Nothing was deleted."
