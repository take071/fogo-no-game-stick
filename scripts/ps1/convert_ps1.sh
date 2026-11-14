#!/usr/bin/env bash
# Convert PS1 games (.cue/.bin or .chd) to .PBP for the Game Stick, merging multi-disc
# games into ONE multi-disc PBP.
#
# Usage:
#   scripts/ps1/convert_ps1.sh [FOLDER] [options]
#     FOLDER = folder with the PS1 games (searched recursively). If omitted, uses $SD/game/ps1.
#   PSX is found automatically (~/Downloads/psxpackager/psxpackager-linux-x64/psxpackager or
#   `psxpackager` in PATH); otherwise set PSX=/path/to/psxpackager.
#
#   --dry-run        only print what would happen, change nothing
#   --delete         after a VALID .PBP exists, delete the originals (.cue/.bin/.chd and the
#                    single-disc PBPs that were merged). PERMANENT: test the PBPs on the
#                    stick first. Default: keep originals.
#   --no-merge       do not merge discs; convert every disc to its own PBP
#   --force-partial  merge even if disc numbers are not contiguous (e.g. only discs 1 and 3)
#   --level N        PBP compression level 0-9 (default 5)
#   -h, --help       this help
#
# Environment (optional):
#   CHDMAN   chdman binary (default: chdman). Needed only for .chd sources, because
#            PSXPackager 1.6.x cannot read CHD. Fedora: sudo dnf install mame-tools
#   PSX_TMP  work folder (default: ~/.cache/gamestick_psx). Needs free space for the
#            extracted discs; keep it OFF the SD card and off a small tmpfs.
#
# What it handles (all tested against the real PSXPackager 1.6.2, see tests/):
#   * .cue pointing to a missing .bin (name/case mismatch)  -> fixes the FILE line (UTF-8 safe)
#   * single disc                                           -> Game.PBP
#   * "Game (Disc 1).cue", "(Disc 2)", ...                  -> ONE "Game.PBP" with all discs
#   * mixed sources: Disc 1 already a .PBP, Disc 2 a .cue   -> merged too
#   * BIOS files (scph*/bios*) are never converted or deleted.
#
# NOTE (PSXPackager): "-x" means "overwrite", NOT "extract". Extraction needs no flag:
# giving a .pbp to -i already extracts it to .bin/.cue (and "-d 1,2" picks discs).
set -u
set -o pipefail

DRY=0; DELETE=0; MERGE=1; FORCE=0; LEVEL=5; DIRARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --delete) DELETE=1 ;;
    --no-merge) MERGE=0 ;;
    --force-partial) FORCE=1 ;;
    --level) shift; LEVEL="${1:?--level needs a number 0-9}" ;;
    -h|--help) sed -n '2,36p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1"; exit 1 ;;
    *) if [ -z "$DIRARG" ]; then DIRARG="$1"; else echo "only one folder allowed (got extra: $1)"; exit 1; fi ;;
  esac
  shift
done
case "$LEVEL" in [0-9]) ;; *) echo "[error] --level must be 0-9"; exit 1 ;; esac

if [ -n "$DIRARG" ]; then D="${DIRARG%/}"
else : "${SD:?Give the games FOLDER as argument, or set SD=/run/media/user/<LABEL>}"; D="$SD/game/ps1"; fi
D="$(cd "$D" 2>/dev/null && pwd)" || { echo "[error] folder not found: ${DIRARG:-$SD/game/ps1}"; exit 1; }
if [ -z "${PSX:-}" ]; then
  for c in "$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager" "$(command -v psxpackager 2>/dev/null)"; do
    [ -n "$c" ] && [ -x "$c" ] && { PSX="$c"; break; }
  done
fi
: "${PSX:?psxpackager not found: set PSX=/path/to/psxpackager}"
[ -x "$PSX" ] || { echo "[error] $PSX is not executable"; exit 1; }
CHDMAN="${CHDMAN:-chdman}"
TMPROOT="${PSX_TMP:-${XDG_CACHE_HOME:-$HOME/.cache}/gamestick_psx}"
mkdir -p "$TMPROOT" || { echo "[error] cannot create $TMPROOT"; exit 1; }
WORK="$(mktemp -d "$TMPROOT/run.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
case "$D/" in "$WORK"/*) echo "[error] PSX_TMP must not be inside the games folder"; exit 1 ;; esac

N_OK=0; N_SKIP=0; N_ERR=0; N_DEL=0

# ---------------------------------------------------------------- helpers
lower() { printf '%s' "${1,,}"; }

protected() {                     # BIOS files are never converted or deleted
  local n; n="$(lower "$1")"
  [[ $n == *scph* || $n == *bios* ]]
}

valid_pbp() {                     # non-empty AND starts with the PBP magic (00 'P' 'B' 'P')
  [ -f "$1" ] && [ -s "$1" ] || return 1
  [ "$(head -c4 "$1" | od -An -tx1 | tr -d ' \n')" = "00504250" ]
}

existing_pbp() {                  # prints the existing "<base>.PBP|.pbp" path, if any
  local b="$1"
  if [ -f "$b.PBP" ]; then printf '%s' "$b.PBP"; return 0; fi
  if [ -f "$b.pbp" ]; then printf '%s' "$b.pbp"; return 0; fi
  return 1
}

avail_kb() { df -Pk "$WORK" | awk 'NR==2{print $4}'; }

rm_file() {
  if [ "$DRY" = 1 ]; then echo "  [would delete] ${1##*/}"; return; fi
  if rm -f -- "$1"; then echo "  [deleted] ${1##*/}"; N_DEL=$((N_DEL+1)); fi
}

# Prints the FILE targets of a .cue (byte-safe: works with UTF-8 and latin-1 names).
cue_files() {
  local LC_ALL=C line re='^[[:space:]]*[Ff][Ii][Ll][Ee][[:space:]]+"([^"]+)"'
  while IFS= read -r line || [ -n "$line" ]; do
    [[ $line =~ $re ]] && printf '%s\n' "${BASH_REMATCH[1]}"
  done < "$1"
}

# 1) fix FILE lines that point to a .bin that does not exist -------------------------
fix_cue() {
  local cue="$1" dir base nfile bins=() b bn tmp name cand line out changed=0 pre post
  local LC_ALL=C
  local re='^([[:space:]]*[Ff][Ii][Ll][Ee][[:space:]]+")([^"]+)(".*)$'
  dir="$(dirname "$cue")"; base="$(basename "${cue%.*}")"
  nfile=$(cue_files "$cue" | wc -l)
  while IFS= read -r -d '' b; do bins+=("${b##*/}"); done \
    < <(find "$dir" -maxdepth 1 -type f -iname '*.bin' -print0)
  out="$(mktemp "$WORK/cue.XXXXXX")"
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ $re ]]; then
      pre="${BASH_REMATCH[1]}"; name="${BASH_REMATCH[2]}"; post="${BASH_REMATCH[3]}"
      if [ ! -e "$dir/$name" ]; then
        cand=""
        for bn in "${bins[@]}"; do                       # (a) same name, different case
          [[ "${bn,,}" == "${name,,}" ]] && { cand="$bn"; break; }
        done
        if [ -z "$cand" ] && [ "$nfile" = 1 ]; then       # (b)/(c) only for single-FILE cues
          for bn in "${bins[@]}"; do
            tmp="${bn%.*}"
            [[ "${tmp,,}" == "${base,,}" ]] && { cand="$bn"; break; }
          done
          [ -z "$cand" ] && [ "${#bins[@]}" = 1 ] && cand="${bins[0]}"
        fi
        if [ -n "$cand" ]; then
          echo "[fix] ${cue##*/}: $name -> $cand"; changed=1
          line="$pre$cand$post"
        else
          echo "[NO BIN] ${cue##*/} (references '$name')"
        fi
      fi
    fi
    printf '%s\n' "$line" >> "$out"
  done < "$cue"
  if [ "$changed" = 1 ] && [ "$DRY" = 0 ]; then cat "$out" > "$cue"; fi
  rm -f "$out"
}

# 2) disc tags ---------------------------------------------------------------------
# sets DISC_N / DISC_KEY. Returns 1 when the name has no "(Disc N)" tag.
disc_parse() {
  local b="$1" re saved
  re='^(.*[^[:space:]_-])?[[:space:]_-]*[([](disc|disco|disk|cd)[[:space:]]*([0-9]+)([[:space:]]*(of|de)[[:space:]]*[0-9]+)?[])](.*)$'
  saved="$(shopt -p nocasematch)"; shopt -s nocasematch
  if [[ $b =~ $re ]]; then
    DISC_N=$((10#${BASH_REMATCH[3]}))
    DISC_KEY="${BASH_REMATCH[1]}${BASH_REMATCH[6]}"
    DISC_KEY="${DISC_KEY#"${DISC_KEY%%[![:space:]]*}"}"; DISC_KEY="${DISC_KEY%"${DISC_KEY##*[![:space:]]}"}"
    eval "$saved"; return 0
  fi
  eval "$saved"; return 1
}

# Prepares a .cue for conversion; echoes its path. For .chd, extracts it with chdman.
prep_source() {                    # type path tag
  local type="$1" path="$2" tag="$3" dd
  case "$type" in
    cue) printf '%s' "$path" ;;
    chd)
      command -v "$CHDMAN" >/dev/null 2>&1 || { echo "[chd] $path: PSXPackager cannot read .chd and chdman was not found; install mame-tools or run: chdman extractcd -i \"$path\" -o \"${path%.*}.cue\" -ob \"${path%.*}.bin\"" >&2; return 1; }
      dd="$WORK/$tag"; mkdir -p "$dd"
      "$CHDMAN" extractcd -i "$path" -o "$dd/disc.cue" -ob "$dd/disc.bin" >&2 || { echo "[ERROR] chdman failed on $path" >&2; return 1; }
      printf '%s' "$dd/disc.cue" ;;
    pbp)                           # extraction needs NO flag: a .pbp as input is extracted
      dd="$WORK/$tag"; mkdir -p "$dd"
      "$PSX" -i "$path" -o "$dd" -x -v 1 >"$dd/.log" 2>&1 || { echo "[ERROR] extraction failed: $path" >&2; sed 's/^/    /' "$dd/.log" >&2; return 1; }
      local c; c="$(find "$dd" -maxdepth 1 -iname '*.cue' | sort | head -n1)"
      [ -n "$c" ] || { echo "[ERROR] no .cue extracted from $path" >&2; return 1; }
      printf '%s' "$c" ;;
  esac
}

# Runs psxpackager on $1 (cue or m3u) and moves the result to $2 (final .PBP path).
pack() {
  local input="$1" final="$2" out="$WORK/out.$RANDOM" produced
  mkdir -p "$out"
  if ! "$PSX" -i "$input" -o "$out" -l "$LEVEL" -x -v 1 >"$out.log" 2>&1; then
    echo "[ERROR] psxpackager failed: ${final##*/}"; sed 's/^/    /' "$out.log"; rm -rf "$out" "$out.log"; return 1
  fi
  rm -f "$out.log"
  produced="$(find "$out" -maxdepth 1 -iname '*.pbp' | head -n1)"
  if [ -z "$produced" ] || ! valid_pbp "$produced"; then
    echo "[ERROR] no valid PBP produced: ${final##*/}"; rm -rf "$out"; return 1
  fi
  cp -- "$produced" "$final.part" && mv -f -- "$final.part" "$final" || { echo "[ERROR] cannot write $final"; rm -f "$final.part"; rm -rf "$out"; return 1; }
  rm -rf "$out"; valid_pbp "$final"
}

# Real check before deleting anything: extract the LAST disc of the merged PBP.
# Measured with PSXPackager 1.6.2: a multi-disc PBP extracts as "<name> - Disc N.cue", while a
# SINGLE-disc PBP ignores "-d 2" and extracts its only disc (without that suffix). So requiring
# the " - Disc N" suffix is what proves the PBP really holds N discs.
verify_discs() {                   # final ndiscs
  local v="$WORK/verify.$RANDOM"; mkdir -p "$v"
  "$PSX" -i "$1" -o "$v" -d "$2" -x -v 1 >/dev/null 2>&1
  local ok=1
  [ -n "$(find "$v" -maxdepth 1 -iname "* - Disc $2.cue" | head -n1)" ] || ok=0
  rm -rf "$v"; [ "$ok" = 1 ]
}

delete_sources() {                 # list of "type<TAB>path" on stdin
  local type path f
  while IFS=$'\t' read -r type path; do
    [ -n "$path" ] || continue
    case "$type" in
      cue)
        while IFS= read -r f; do
          [ -f "${path%/*}/$f" ] && ! protected "$f" && rm_file "${path%/*}/$f"
        done < <(cue_files "$path")
        rm_file "$path" ;;
      chd|pbp) rm_file "$path" ;;
    esac
  done
}

delete_disc_covers() {             # dir, then the base names of the merged discs
  local dir="$1" b e; shift
  for b in "$@"; do
    for e in png jpg jpeg PNG JPG JPEG; do [ -f "$dir/$b.$e" ] && rm_file "$dir/$b.$e"; done
  done
}

move_cover() {                     # keep the Disc 1 cover as the merged game's cover
  local dir="$1" key="$2" first="$3" e
  for e in png jpg jpeg PNG JPG JPEG; do
    if [ -f "$dir/$first.$e" ] && [ ! -e "$dir/$key.png" ] && [ ! -e "$dir/$key.jpg" ] && [ ! -e "$dir/$key.jpeg" ]; then
      echo "  [cover] $first.$e -> $key.$e"
      [ "$DRY" = 1 ] || cp -- "$dir/$first.$e" "$dir/$key.$e"
    fi
  done
}

# ---------------------------------------------------------------- per-game logic
convert_single() {                 # dir base type path
  local dir="$1" base="$2" type="$3" path="$4" cue final="$1/$2.PBP"
  if existing_pbp "$dir/$base" >/dev/null && valid_pbp "$(existing_pbp "$dir/$base")"; then
    echo "[skip] $base (PBP exists)"; N_SKIP=$((N_SKIP+1))
    [ "$DELETE" = 1 ] && delete_sources <<< "$type"$'\t'"$path"
    return
  fi
  echo "[conv] $base"
  [ "$DRY" = 1 ] && return
  cue="$(prep_source "$type" "$path" "s.$RANDOM")" || { N_ERR=$((N_ERR+1)); return; }
  if pack "$cue" "$final"; then
    N_OK=$((N_OK+1))
    [ "$DELETE" = 1 ] && delete_sources <<< "$type"$'\t'"$path"
  else
    N_ERR=$((N_ERR+1)); echo "[keep] originals of $base kept (no valid PBP)"
  fi
}

merge_group() {                    # dir key nums... (uses BEST_T / BEST_P)
  local dir="$1" key="$2"; shift 2
  local nums=("$@") n final="$dir/$key.PBP" m3u cue tag total
  total=${#nums[@]}
  local srcs="" need=0 sz first=""
  # contiguous 1..N?
  local want=1 contiguous=1
  for n in "${nums[@]}"; do [ "$n" = "$want" ] || contiguous=0; want=$((want+1)); done
  if [ "$contiguous" = 0 ] && [ "$FORCE" = 0 ]; then
    echo "[WARN] $key: discs found: ${nums[*]} (not 1..$total). Not merged. Use --force-partial to merge anyway."
    N_SKIP=$((N_SKIP+1)); return
  fi
  local bases=()
  for n in "${nums[@]}"; do
    srcs+="${BEST_T[$n]}"$'\t'"${BEST_P[$n]}"$'\n'
    bases+=("$(basename "${BEST_P[$n]%.*}")")
    [ -z "$first" ] && first="${bases[0]}"
  done

  if existing_pbp "$dir/$key" >/dev/null && valid_pbp "$(existing_pbp "$dir/$key")"; then
    final="$(existing_pbp "$dir/$key")"
    echo "[skip] $key (merged PBP exists)"; N_SKIP=$((N_SKIP+1))
    if [ "$DELETE" = 1 ]; then
      if [ "$DRY" = 1 ] || verify_discs "$final" "$total"; then
        delete_sources <<< "$srcs"; delete_disc_covers "$dir" "${bases[@]}"
      else
        echo "[keep] $key.PBP does not contain $total discs; originals kept"
      fi
    fi
    return
  fi

  echo "[merge] $key ($total discs: ${nums[*]})"
  for n in "${nums[@]}"; do echo "  disc $n <- ${BEST_P[$n]##*/} (${BEST_T[$n]})"; done
  [ "$DRY" = 1 ] && { move_cover "$dir" "$key" "$first"; return; }

  # free space check (extraction of pbp/chd is much bigger than the packed file)
  for n in "${nums[@]}"; do
    case "${BEST_T[$n]}" in
      cue) while IFS= read -r sz; do [ -f "$dir/$sz" ] && need=$((need + $(stat -c %s "$dir/$sz")/1024)); done < <(cue_files "${BEST_P[$n]}") ;;
      *) need=$((need + $(stat -c %s "${BEST_P[$n]}")/1024*3)) ;;
    esac
  done
  if [ "$(avail_kb)" -lt "$need" ]; then
    echo "[ERROR] $key: needs ~$((need/1024)) MB in $WORK, only $(( $(avail_kb)/1024 )) MB free (set PSX_TMP)"
    N_ERR=$((N_ERR+1)); return
  fi

  m3u="$WORK/$key.m3u"; : > "$m3u"
  for n in "${nums[@]}"; do
    tag="d$n.$RANDOM"
    cue="$(prep_source "${BEST_T[$n]}" "${BEST_P[$n]}" "$tag")" || { echo "[ERROR] $key: disc $n failed"; N_ERR=$((N_ERR+1)); return; }
    printf '%s\n' "$cue" >> "$m3u"
  done
  if pack "$m3u" "$final"; then
    N_OK=$((N_OK+1)); move_cover "$dir" "$key" "$first"
    if [ "$DELETE" = 1 ]; then
      if verify_discs "$final" "$total"; then
        delete_sources <<< "$srcs"; delete_disc_covers "$dir" "${bases[@]}"
      else
        echo "[keep] $key.PBP failed the $total-disc check; originals kept"
      fi
    fi
  else
    N_ERR=$((N_ERR+1)); echo "[keep] originals of $key kept (no valid PBP)"
  fi
  rm -f "$m3u"
}

process_dir() {
  local dir="$1" f base ext lext type key n
  declare -A GROUP=()            # key -> lines "N<TAB>type<TAB>path"
  declare -A HASCUE=()           # base -> 1 (has a .cue)
  local files=()
  while IFS= read -r -d '' f; do files+=("$f"); done < <(find "$dir" -maxdepth 1 -type f -print0 | sort -z)
  for f in "${files[@]}"; do
    base="$(basename "${f%.*}")"; ext="${f##*.}"; lext="${ext,,}"
    [[ "$base" == .* ]] && continue
    [ "$lext" = cue ] && HASCUE["$base"]=1
  done
  for f in "${files[@]}"; do
    base="$(basename "${f%.*}")"; ext="${f##*.}"; lext="${ext,,}"
    [[ "$base" == .* ]] && continue
    case "$lext" in cue|chd|pbp) ;; *) continue ;; esac
    if protected "$base"; then echo "[bios] ignored ${f##*/}"; continue; fi
    type="$lext"
    [ "$type" = chd ] && [ -n "${HASCUE[$base]:-}" ] && continue   # .cue wins over .chd
    if disc_parse "$base"; then key="$DISC_KEY"; n="$DISC_N"
    else
      [ "$type" = pbp ] && continue                                 # a final single PBP: nothing to do
      key="$base"; n=1
    fi
    GROUP["$key"]+="$n"$'\t'"$type"$'\t'"$f"$'\n'
  done

  local k
  [ "${#GROUP[@]}" -gt 0 ] || return 0          # folder without games
  while IFS= read -r -d '' k; do
    [ -n "$k" ] || continue
    local lines="${GROUP[$k]}" nums=() t p
    declare -A BEST_T=() BEST_P=()
    local curpri
    declare -A BEST_PRI=()
    while IFS=$'\t' read -r n t p; do
      [ -z "$n" ] && continue
      case "$t" in cue) curpri=3 ;; chd) curpri=2 ;; *) curpri=1 ;; esac
      if [ -z "${BEST_T[$n]:-}" ] || [ "$curpri" -gt "${BEST_PRI[$n]}" ]; then
        BEST_T[$n]="$t"; BEST_P[$n]="$p"; BEST_PRI[$n]=$curpri
      fi
    done <<< "$lines"
    mapfile -t nums < <(printf '%s\n' "${!BEST_T[@]}" | sort -n)
    if [ "${#nums[@]}" -ge 2 ] && [ "$MERGE" = 1 ]; then
      merge_group "$dir" "$k" "${nums[@]}"
    else
      for n in "${nums[@]}"; do
        [ "${BEST_T[$n]}" = pbp ] && continue
        p="${BEST_P[$n]}"
        convert_single "$dir" "$(basename "${p%.*}")" "${BEST_T[$n]}" "$p"
      done
    fi
    unset BEST_T BEST_P BEST_PRI
  done < <(printf '%s\0' "${!GROUP[@]}" | sort -z)
}

# ---------------------------------------------------------------- main
echo "Folder: $D  [dry-run=$DRY delete=$DELETE merge=$MERGE]"

# step 1: fix .cue references (all folders)
while IFS= read -r -d '' c; do fix_cue "$c"; done \
  < <(find "$D" -type f -iname '*.cue' -not -path '*/.*' -print0 | sort -z)

# step 2: convert / merge, folder by folder
while IFS= read -r -d '' d; do process_dir "$d"; done \
  < <(find "$D" -type d -not -path '*/.*' -print0 | sort -z)

# step 3: normalise extension to .PBP (exFAT ignores case, so go through a temp name)
if [ "$DRY" = 0 ]; then
  while IFS= read -r -d '' f; do
    b="${f%.pbp}"; mv -- "$f" "$b.tmp_ren" && mv -- "$b.tmp_ren" "$b.PBP"
  done < <(find "$D" -type f -name '*.pbp' -not -path '*/.*' -print0)
fi

[ "$DELETE" = 1 ] || echo "[info] originals kept (use --delete to remove them after testing the PBPs)"
echo "== summary: converted/merged=$N_OK  skipped=$N_SKIP  errors=$N_ERR  deleted=$N_DEL"
sync
ls -lh "$D"
[ "$N_ERR" = 0 ]
