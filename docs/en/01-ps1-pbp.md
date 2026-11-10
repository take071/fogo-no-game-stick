# 01 · PS1: converting to PBP

[← back](../../README.md) · [next: saves and covers →](02-saves-and-covers.md)

## Problem

PSXPackager failed on every game with `Could not find file '...bin'`. The `.cue` files pointed to `.bin` names that did not exist in the folder (e.g. the `.cue` said `A Bug's Life (Dublado).bin` while the file was `A Bug's Life.bin`).

## Solution

`scripts/ps1/convert_ps1.sh`:

1. fixes each `.cue` `FILE` line **conservatively**: same name ignoring case or, for a `.cue` with a single `FILE`, the `.bin` with the `.cue`'s base name (or the only `.bin` in the folder). No fuzzy matching, and the `.cue` is read and written as UTF-8, so names with accents are not corrupted;
2. converts with PSXPackager 1.6.2 whatever has no PBP yet;
3. normalises the extension to `.PBP` (the PBPs that already worked used upper case; PSXPackager writes `.pbp`; exFAT ignores case, so `mv` goes through a temporary name);
4. **optional (`--delete`)**: deletes the originals only for games with a valid PBP (> 0 bytes). BIOS files (`scph*`, `bios*`) are never deleted.

## Result

6 games converted without errors (A Bug's Life, Alundra, Alundra 2, Diablo, Castlevania SotN, Crash Bandicoot). With the ones that already existed, the `ps1` folder has 10 PBPs, **tested on the stick** **[measured]**.

## Changes compared to the original project script

- Personal paths became the `SD` and `PSX` variables.
- New `--dry-run` (changes nothing).
- Deleting originals used to be automatic; it is now opt-in (`--delete`) because it is permanent.
- Extra protection for BIOS files in the delete step.
- The original script existed in three identical copies; only one is kept.
- **Accent bug fixed.** The first version read and wrote `.cue` files as latin-1: a **correct** `.cue` named `Pokémon Cópia` was rewritten with latin-1 bytes (`e9` instead of `c3 a9`), corrupting it, and the delete step could leave an orphan `.bin` **[measured in a review session, synthetic disc]**. The current version keeps the bytes intact; checked offline on synthetic `.cue` files (accented name untouched, broken reference fixed, ambiguous `.cue` left alone).
- **`difflib` matching removed:** it could bind several `FILE` lines to the same `.bin`.
- **`.chd` is not supported** by PSXPackager 1.6.2 **[measured]**. The script now prints a `[chd]` line with the `chdman extractcd` command instead of failing. Extract first (`mame-tools` package).

## Multi-disc (Tales of Destiny II): **tested on the device, it works** [tested by the author]

`scripts/ps1/multidisc_pbp.sh` extracts each disc back to bin/cue, builds an `.m3u` with the `.cue` files in order and packs everything into one multi-disc PBP.

The extraction flag was a guess in the first version. A later review session measured the real PSXPackager 1.6.2 with synthetic discs **[measured]**:

- **`-x` is NOT "extract":** it means *overwrite without asking*. The earlier script and docs used it as the extraction flag, which was wrong.
- Extracting needs **no flag**: a `.pbp` in `-i` already produces `.bin/.cue`; `-d 1,2` picks the discs.
- A `.m3u` in `-i` (absolute or relative paths) produces **one** multi-disc PBP, named like the `.m3u`.
- `-d N` on a single-disc PBP ignores `N` and extracts the only disc (rc=0). To prove a PBP really has several discs, check for the ` - Disc N` suffix in the extracted name; "a `.cue` was generated" is not enough.
- The exit code is reliable: `0` success, `1` failure.

The script was corrected accordingly (no `EXTRACT_FLAG`). **The author ran the script on a real multi-disc game and opened the PBP on the stick: it works** [tested by the author; no log kept]. Still, keep the original PBPs until you have checked your own game.
