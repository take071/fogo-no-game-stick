#!/usr/bin/env bash
# Convert PS1 CUE/BIN (or CHD) games to .PBP for the Game Stick.
#
# Usage:
#   SD=/run/media/user/<LABEL> PSX=/path/to/psxpackager ./convert_ps1.sh [--dry-run] [--delete]
#
#   --dry-run  only print what would happen, change nothing
#   --delete   after a VALID .PBP exists, delete the original .cue/.bin/.chd
#              (permanent! test the PBPs on the stick first). Default: keep originals.
#
# Steps: 1) fix FILE lines in .cue  2) convert  3) normalise extension to .PBP
#        4) (optional) delete originals. BIOS files (scph*/bios*) are never deleted.
set -u
: "${SD:?Set SD to the mount point of the data partition, e.g. SD=/run/media/user/<LABEL>}"
: "${PSX:?Set PSX to the psxpackager binary, e.g. PSX=\$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager}"
DRY=0; DELETE=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --delete)  DELETE=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $a"; exit 1 ;;
  esac
done
D="$SD/game/ps1"
[ -d "$D" ] || { echo "[error] $D not found"; exit 1; }
[ -x "$PSX" ] || { echo "[error] $PSX is not executable"; exit 1; }
cd "$D" || exit 1

# 1) fix .bin references inside .cue files (name mismatch was the cause of
#    "Could not find file '...bin'" in PSXPackager)
python3 - "$D" "$DRY" <<'EOF'
import os, re, sys, difflib
D, DRY = sys.argv[1], sys.argv[2] == '1'
pat = re.compile(r'^(\s*FILE\s+)"([^"]+)"(.*)$', re.M)
for root, _, files in os.walk(D):
    bins = [f for f in files if f.lower().endswith('.bin')]
    for cue in [f for f in files if f.lower().endswith('.cue')]:
        p = os.path.join(root, cue)
        txt = open(p, encoding='latin-1', newline='').read()
        changed = False
        def fix(m):
            global changed
            name = m.group(2)
            if os.path.exists(os.path.join(root, name)):
                return m.group(0)
            base = os.path.splitext(cue)[0].lower()
            cand = [b for b in bins if os.path.splitext(b)[0].lower() == base] \
                or difflib.get_close_matches(name, bins, n=1, cutoff=0.6)
            if cand:
                print(f'[fix] {cue}: {name} -> {cand[0]}')
                changed = True
                return f'{m.group(1)}"{cand[0]}"{m.group(3)}'
            print(f'[NO BIN] {cue}')
            return m.group(0)
        new = pat.sub(fix, txt)
        if changed and not DRY:
            open(p, 'w', encoding='latin-1', newline='').write(new)
EOF

# 2) convert everything that has no PBP yet
find . -type f \( -iname '*.cue' -o -iname '*.chd' \) -print0 | while IFS= read -r -d '' f; do
  b="${f%.*}"
  if [ -f "$b.PBP" ] || [ -f "$b.pbp" ]; then echo "[skip] $f"; continue; fi
  echo "[conv] $f"
  [ "$DRY" = 1 ] && continue
  "$PSX" -i "$f" -o "$(dirname "$f")" || echo "[ERROR] $f"
done

# 3) normalise extension to .PBP (exFAT ignores case, so go through a temp name)
if [ "$DRY" = 0 ]; then
  find . -type f -name '*.pbp' -print0 | while IFS= read -r -d '' f; do
    b="${f%.pbp}"; mv -- "$f" "$b.tmp_ren" && mv -- "$b.tmp_ren" "$b.PBP"
  done
fi

# 4) delete originals ONLY for games that have a non-empty PBP (opt-in)
if [ "$DELETE" = 1 ]; then
python3 - "$D" "$DRY" <<'EOF'
import os, re, sys
D, DRY = sys.argv[1], sys.argv[2] == '1'
def protected(n):
    n = n.lower(); return 'scph' in n or 'bios' in n
def rm(p):
    print('[delete]' if not DRY else '[would delete]', os.path.basename(p))
    if not DRY: os.remove(p)
for root, _, files in os.walk(D):
    for f in files:
        if not f.lower().endswith(('.cue', '.chd')): continue
        base = os.path.join(root, f.rsplit('.', 1)[0])
        if not (os.path.isfile(base + '.PBP') and os.path.getsize(base + '.PBP') > 0):
            print('[keep, no PBP]', f); continue
        p = os.path.join(root, f)
        if f.lower().endswith('.cue'):
            txt = open(p, encoding='latin-1').read()
            for n in re.findall(r'^\s*FILE\s+"([^"]+)"', txt, re.M | re.I):
                b = os.path.join(root, n)
                if os.path.isfile(b) and not protected(n): rm(b)
        rm(p)
EOF
else
  echo "[info] originals kept (use --delete to remove them after testing the PBPs)"
fi
sync
ls -lh "$D"
