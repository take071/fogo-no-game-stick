# 01 · PS1: converting to PBP

[← back](../../README.md) · [next: saves and covers →](02-saves-and-covers.md)

## Problem

PSXPackager failed on every game with `Could not find file '...bin'`. The `.cue` files pointed to `.bin` names that did not exist in the folder (e.g. the `.cue` said `A Bug's Life (Dublado).bin` while the file was `A Bug's Life.bin`).

## Solution

`scripts/ps1/convert_ps1.sh`:

1. fixes each `.cue` `FILE` line to the `.bin` with the same name (or the closest one, via `difflib`);
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

## Multi-disc (Tales of Destiny II): **untested** [pending]

`scripts/ps1/multidisc_pbp.sh` extracts each disc back to bin/cue, builds an `.m3u` with the `.cue` files in order and packs everything into one multi-disc PBP.
The extraction flag (`-x`) was marked "adjust according to `--help`" and was **never confirmed**. Run `psxpackager --help`, set `EXTRACT_FLAG`, and keep the original PBPs until it works.
