# 07 · Scripts usage guide

[← back](../../README.md)

All scripts live in `scripts/`. **Portuguese versions** (translated comments and messages, same behaviour) live in `scripts/pt-BR/`; see `scripts/pt-BR/LEIA-ME.md` for the name table. Output tags are translated there too (e.g. `[corrigido]`, `[SEM BIN]`, `[converter]`, `[pular]`, `[ERRO]` instead of `[fix]`, `[NO BIN]`, `[conv]`, `[skip]`, `[ERROR]`). The ones in `ps1/`, `covers/`, `config/` and `debug/` run **on your Linux PC** with the stick's card plugged in. The ones in `timer/` run **inside the stick**.

## 1. Setup (once)

**PC requirements (Fedora):**

```bash
sudo dnf install python3 python3-pillow   # Pillow is only needed for covers
# udisks2 and lsblk already ship with Fedora
```

To convert PS1 you also need **PSXPackager** (the `psxpackager` Linux x64 binary, downloaded from its GitHub project).

**Find where the card was mounted:**

```bash
lsblk                         # the large exFAT partition (e.g. 58 GB) is the data one
ls /run/media/$USER/          # the folder name is the card's label
```

**Set the variables** (valid only for the open terminal):

```bash
export SD=/run/media/$USER/<LABEL>      # replace <LABEL> with the folder shown above
export PSX=$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager
ls "$SD/game"                           # must list atari, cps, fc, gb, gba, gbc, md, n64, ps1, sfc
```

If `ls` does not list the game folders, `SD` is wrong. Do not run anything below before that works.

Enter the repo folder (`cd ~/Downloads/fogo-no-game-stick`) and, if needed, make the scripts executable: `chmod +x scripts/*/*.sh scripts/*/*.py`.

> **Golden rule:** whenever `--dry-run` exists, run it first, check the output, and only then run for real.

---

## 2. Convert PS1 games to PBP: `scripts/ps1/convert_ps1.sh`

Put the games (`.cue` + `.bin`) in `$SD/game/ps1/` and run. (`.chd` is **not** read by PSXPackager 1.6.2: extract it first with `chdman extractcd`, from the `mame-tools` package.)

```bash
scripts/ps1/convert_ps1.sh --dry-run    # shows what it would do, changes nothing
scripts/ps1/convert_ps1.sh              # fixes the .cue files and converts; KEEPS the originals
```

Reading the output:

| Tag | Meaning |
|---|---|
| `[fix] X.cue: A.bin -> B.bin` | the `.cue` pointed to a missing `.bin` and was fixed |
| `[NO BIN] X.cue` | no matching `.bin` found; that game will not be converted |
| `[conv] file` | will convert (or is converting) |
| `[skip] file` | a `.PBP` with the same name already exists |
| `[chd] file` | PSXPackager cannot read `.chd`; the line prints the `chdman` command to extract it first |
| `[ERROR] file` | PSXPackager failed on that game |

**Test the PBPs on the stick.** Only when you are sure:

```bash
scripts/ps1/convert_ps1.sh --dry-run --delete   # lists what would be deleted
scripts/ps1/convert_ps1.sh --delete             # deletes .cue/.bin/.chd of games with a valid PBP
```

Deleting is permanent. BIOS files (`scph*`, `bios*`) are never deleted.

### Multi-disc PBP (tested by the author, it works): `scripts/ps1/multidisc_pbp.sh`

For games with several discs, already converted to separate PBPs (`Name (Disc 1).PBP`, `Name (Disc 2).PBP`...):

```bash
NAME="Tales of Destiny II (USA)" DISCS=3 scripts/ps1/multidisc_pbp.sh
```

No extraction flag is needed (in PSXPackager `-x` means *overwrite*, not *extract*; see doc 01). The result lands in `$SD/game/ps1/_tmp_multidisc/out/`. The script deletes and moves nothing: check and test the new PBP before replacing the originals.

---

## 3. Covers

**See which games have no cover:**

```bash
python3 scripts/covers/check_covers.py
```

It prints `[NO COVER] folder/game` and a total at the end. A cover is a `.png`/`.jpg` with the **same name as the game**, in the same folder (hypothesis, see doc 02).

**Fetch a few covers by hand:** `scripts/covers/missing_covers_manual.py`. Edit the `TASKS` list at the top of the file (repos, destination without extension, and words from the name) and run:

```bash
python3 scripts/covers/missing_covers_manual.py
```

This script depends on the cache produced by `capas_gamestick.py` (`~/.cache/capas_gamestick`), which will be added to the repo later. Without the cache it prints `[no candidate]`. It never overwrites an existing cover.

**"00 Timer" covers:** copy the PNGs from `assets/timer_covers/` into each console's folder, named like the fake "game" (e.g. `gba.png` becomes `00 Timer.png` in `$SD/game/gba/`).

---

## 4. Config tweaks

Both make an **automatic backup** (`.bak_pre_...`) on first run.

**Pokémon battle speed** (`timer/gbx_mod.cfg`, values used: 2.5 and 3.0; `0` turns it off):

```bash
scripts/config/set_fastforward.sh 2.5
```

It applies to GBA games launched through `hook.sh`, but the effect only shows in **Pokémon battles** (map, menus and text stay normal). It requires `gbx_mod.cfg` on the card (to be added to the repo).

**PS1 Enhanced Resolution:**

```bash
scripts/config/set_enhanced_resolution.sh enabled      # or: disabled
```

After any tweak, eject the card (below) and test on the stick.

---

## 5. Eject the card safely: `scripts/config/eject.sh`

The device name changes (`sda`, `sdb`...). **Check with `lsblk` first.**

```bash
lsblk
scripts/config/eject.sh /dev/sdb      # the whole disk, no number at the end
```

The script refuses non-removable devices, unmounts the partitions and powers the card off.

---

## 6. Measure RAM and CPU: `scripts/debug/`

They read `timer/hook.log`, which the stick fills while you play (the `ra_wrap.sh` and `amostra_ps1.sh` meters must be installed on the card). Flow: play ~2 min, quit through the menu, eject, plug into the PC, `export SD=...` and run:

```bash
scripts/debug/avg_per_game.sh      # average RAM/CPU per game
scripts/debug/per_session.sh       # max RAM per play session
```

`rss` is RetroArch's RAM; `cpu_avg` is `dtick/5` (~100% = one full core). Beware of the PK GS sample misattribution (doc 03).

**Generate the Markdown report** (replaces reading those numbers by hand; it also checks the options file and shows the NEON state):

```bash
scripts/debug/consumption_report.sh               # writes docs/pt-BR/08-consumo-medido.md and docs/en/08-measured-consumption.md
scripts/debug/consumption_report.sh --lang en     # English only
```

It only reads the card. Sessions whose max RAM differs a lot for the same game are flagged ⚠ (possible mis-attribution). Then review and commit the generated files.

---

## 7. Timer scripts on the stick: `scripts/timer/hook.sh` and `run.sh`

They do not run on the PC. They live in `timer/` **on the card** and the stick runs them by itself.

**`run.sh`** is the final version (15 s alert, game paused while it shows, any button dismisses it). It can be copied on its own; it does not touch `hook.sh`:

```bash
cp "$SD/timer/run.sh" "$SD/timer/run.sh.bak"      # backup first
cp scripts/timer/run.sh "$SD/timer/run.sh"
sync
```

`DUR` (seconds) and `PAUSAR` are at the top of the file. `PAUSAR=0` brings the flicker back. Details and check commands: doc 06-1. To restore: `cp "$SD/timer/run.sh.bak" "$SD/timer/run.sh"`.

**`hook.sh`** is the timer version:

```bash
cp "$SD/timer/hook.sh" "$SD/timer/hook.sh.bak_before_update3"   # backup REQUIRED
```

⚠️ **Do not copy this repo's `hook.sh` over yours** without reading doc 06: it is the timer version and may remove fast-forward from the GBA games. Merge both first. To restore: `cp "$SD/timer/hook.sh.bak_before_update3" "$SD/timer/hook.sh"`.

The `gtimer` binary is not in the repo; it must be at `$SD/timer/gtimer`.

---

## 8. History tab: `scripts/config/hist.py`, `make_mold.py`, `sel_limpa.sh`

Full explanation, install and warnings: [game_stick_history.md](game_stick_history.md). **From the PC** (needs `SD`):

```bash
python3 scripts/config/hist.py show        # list, newest first (read-only)
python3 scripts/config/hist.py trim        # keep only the 15 most recent (one per game)
python3 scripts/config/hist.py del 55      # remove one game by GameID
python3 scripts/config/hist.py clear       # wipe everything
```

`show` only reads; the others **write to the card** with no confirmation and no backup: eject it safely before using it in the stick. **On the stick**, `sel_limpa.sh` wipes the history when you hold **Start for 3 s** on the History tab. One-time setup: `python3 scripts/config/make_mold.py` (creates the empty template), copy `sel_limpa.sh` to `$SD/histtools/`, add one line to the hook and check the button code (`SEL=`). Tested on **one** device only; it works only after a game has been opened since power-on.

---

## Common problems

| Symptom | Likely cause |
|---|---|
| `Set SD to the mount point...` | `SD` variable not set in this terminal |
| `[error] .../game/ps1 not found` | `SD` points to the wrong place or the card is not mounted |
| `psxpackager: Permission denied` | `chmod +x "$PSX"` |
| `ModuleNotFoundError: PIL` | `sudo dnf install python3-pillow` |
| `[error] could not find the repo root` | run the report from inside the repository or set `OUT=/path/to/repo` |
| `[refused] ... is not a removable device` | wrong disk; use the card's, checked with `lsblk` |
| Input/output error in the terminal | the card dropped and came back under another name; `cd ~`, check `lsblk` and set `SD` again |
