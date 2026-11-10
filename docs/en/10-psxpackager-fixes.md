# 10 – PSXPackager fixes (PS1 and multi-disc)

I **measured** these with the real PSXPackager 1.6.2 on synthetic PS1 discs (no ROMs). They correct mistakes in my old scripts.

## What changed in my understanding

1. **`-x` is not "extract".** In 1.6.2, `-x` means *overwrite without asking*. This repo's `multidisc_pbp.sh` (and older scripts of mine) use `-x` as extraction, so they are **wrong**.
2. **Extracting needs no flag:** passing a `.pbp` to `-i` already produces `.bin/.cue`. `-d 1,2` picks discs.
3. **`.m3u` works** (absolute and relative paths) and yields **one** multi-disc PBP named after the `.m3u`.
4. **`.chd` is not supported.** Extract first with `chdman` (package `mame-tools`).
5. **The exit code is reliable:** `0` on success, `1` on failure.
6. **`-d N` on a single-disc PBP ignores `N`** and extracts the only disc (rc=0). To verify a multi-disc PBP I require the ` - Disc N` suffix in the extracted name; just checking "a `.cue` was produced" would be a false positive.
7. **Accent bug (reproduced):** the step that fixes `.cue` files rewrote a correct UTF-8 `.cue` as latin-1 (`Pokémon Cópia`: `e9` instead of `c3 a9`), corrupting it and possibly leaving an orphan `.bin`.
8. **`&` bug in covers:** the cover repo writes `&` as `_`, and the old script only replaced the `&` in the title. It lost "Mega Man & Bass" and "Mother 1 & 2".

**I couldn't reproduce** the `printf '%.6f'` problem with the pt_BR locale (my test environment lacked it). I applied the fix since it's cheap, but the bug itself is **not confirmed**.

## How the fixed converter works

It does everything in one pass: fixes `.cue` files without touching UTF-8 name bytes, converts single-disc games, merges `Game (Disc 1)`, `(Disc 2)`... into one `Game.PBP`, accepts mixed sources and `.chd` (via `chdman`), copies Disc 1's cover and **never** touches BIOS (`scph*`, `bios*`). It refuses to merge incomplete sets (discs 1 and 3, say) without `--force-partial`. Options: `--dry-run`, `--delete`, `--no-merge`, `--force-partial`, `--level 0-9`.

The `.cue` fixing is now **more conservative**: I removed the `difflib` similarity match (it could link several `FILE`s to the same `.bin`). It now only fixes by equal name (ignoring case) or, in a one-`FILE` `.cue`, by the same-basename `.bin` or the only `.bin` in the folder; otherwise it warns `[NO BIN]`.

When deleting, I only delete after a valid PBP exists (non-empty, with the `PBP` header); for multi-disc, I first **extract the last disc** to prove all N discs are there.

Note: the default work area is `~/.cache/gamestick_psx` (`PSX_TMP`). Extracting discs takes a lot of space; keep it off the card and off a small `/tmp`.

## Tests (done earlier, with synthetic discs)

23/23 on the converter (bash and Python), 13/13 on the config scripts, 9/9 on cover matching, clean `shellcheck`. **No real game or device** was used: I still have to open a multi-disc PBP on the stick, especially the disc swap. `eject.sh` was only validated for syntax.

## Pending

- Bring the fixed scripts (`convert_ps1.sh`, `ps1_pbp.py`, `capas_gamestick.py`) into this repo and replace the old `multidisc_pbp.sh`. **They are not here yet.**
- `.gitignore` with `.psxtmp*`, `_tmp_*`, `*.m3u`, `*.part`; `requirements.txt` (`pillow`; `pycdlib` for tests only); CI with shellcheck + `py_compile` + tests.
- List `amostra_ps1.sh` in the README's pending items.
- Install `mame-tools` where I convert `.chd`.
