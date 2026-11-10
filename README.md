# 🔥 fogo no game stick

🇧🇷 [Leia em português](README.pt-BR.md)

Notes, scripts and findings from modding a generic **Game Stick 4K Lite** (red board, firmware "V5 Base TG", MiniGUI menu + RetroArch 1.7.4). Everything was done from a Fedora linux PC, without installing RetroArch and without running ARM code on x86_64.

> **Work in progress.** The project is not finished. This repo records what worked, what was tried and dropped, and what is still pending. Claims are tagged:
> **[measured]** seen in a log/command · **[inferred]** deduced, not confirmed · **[hypothesis]** suspicion without proof · **[pending]** not tested yet · **[tested by the author]** checked on the device, no log/measurement kept · **[observed]** noticed in use, not confirmed.

> **About "battles":** in this repo, "battles" always means the **turn-based battles of the Pokémon GBA hacks** (PK GS Chronicles 2.7.4 and Stone Dragon 3, both FireRed-based). The speed-up (`fastforward_ratio`) is applied to GBA games launched through the hook, but its visible effect is only in those battles; map, menus and text stay at normal speed. Pokémon Mystery Dungeon has no turn-based battles, and other consoles (PS1, arcade) are not affected.

> ⚠️ Use at your own risk. Back up before touching the firmware partition. Paths in this repo use `/run/media/user/<LABEL>` as the card mount point; replace with yours.

## Hardware / system at a glance

| Item | Value |
|---|---|
| Device | Game Stick 4K Lite, red board, V5 Base TG |
| CPU / RAM | 1 core @ 1008 MHz (only frequency), ~230 MB usable RAM, no swap **[measured]** |
| Emulator | RetroArch 1.7.4 (ARM 32-bit hard-float, glibc 2.29) **[measured]** |
| Cores | `pcsx_rearmed` (PS1), `mgba` (GBA, slot 7) |
| Card partitions | `p1–p3` boot (do not touch) · `p4` squashfs 65 MB (system, read-only) · `p5` exFAT (data, appears as `/sdcard`) |
| Games | `game/<console>/` (`atari cps fc gb gba gbc md n64 ps1 sfc`) |

## What was done

| # | Topic | Result | Doc |
|---|---|---|---|
| 1 | PS1: CUE/BIN → PBP conversion (fixing broken `.cue` references) | ✅ 6 games converted, 10 PBPs total, tested on the stick · ✅ multi-disc PBP tested **[tested by the author]** | [01](docs/en/01-ps1-pbp.md) |
| 2 | Saves/states redirected to `saves/` and `states/` by patching the squashfs | ✅ new saves land in the new folders **[measured]** · ✅ old saves load **[tested by the author]** | [02](docs/en/02-saves-and-covers.md) |
| 3 | Cover images (libretro-thumbnails) for all recognised games | ✅ downloaded · ✅ shown in the menu (cover name = game name) **[tested by the author]** · ❓ ROM hacks not confirmed | [02](docs/en/02-saves-and-covers.md) |
| 4 | PS1 "Enhanced Resolution" + RAM/CPU measurement tooling | ✅ applied · ✅ CPU cost/visuals/option file checked by the author · numbers via the [report](docs/en/08-measured-consumption.md) | [03](docs/en/03-graphics-and-consumption.md) |
| 5 | Faster **Pokémon battles** in the GBA hacks (`fastforward_ratio` through `hook.sh`) | ✅ works (2.5 "perfect", 3.0 in use) · ❓ seems better in closed areas, not confirmed **[observed]** | [04](docs/en/04-pokemon-fastforward.md) |
| 6 | Diagnosis of the black screen when opening the bag **during a Pokémon battle**, and RAM use in the hacks | 🔎 several causes ruled out, root cause open | [05](docs/en/05-diagnosis-black-screen-ram.md) |
| 7 | "00 Timer" (fake game that works as a timer) + custom cover art | ✅ works · ✅ alert steady for 15 s, game paused, any button dismisses it · ✅ works over an arcade game **[tested by the author]** · ❌ not in arcade list | [06](docs/en/06-timer.md), [06-1](docs/en/06-1timer.md) |
| 8 | Console **History tab**: hold **Start for 3 s** to wipe it and restart the menu; list/trim/delete from the PC | ✅ works on the tested device (one device only) | [history](docs/en/game_stick_history.md) |
| 9 | **Full screen** in games (`aspect_ratio_index` 18 → 1 in three configs) | ❓ applied; effect **not confirmed** (conflicts with doc 04) | [06-1](docs/en/06-1timer.md) |

## What we gave up on

| Idea | Why |
|---|---|
| Editing `gbx66.cfg` / `start_game.sh` on the exFAT card | The stick uses the internal ones in `/usr/local/share/minigui/` (only the squashfs patch worked) |
| Fast-forward button (L / Start / `_btn` codes) | L has a battle function, Start did nothing, pad sends keyboard keys; speed was already good |
| Auto fast-forward by timer or by reading game memory | Refused / would need a custom RetroArch build and per-hack addresses |
| Newer mGBA core, gpSP, `performance` governor, threaded video etc. | No gain, or no game opened (gpSP needs a `gba_bios.bin`); reverted |
| `kill -STOP` on RetroArch as a first attempt at the timer alert | Froze the game ~25 s with no sound. It works when done **before** starting `gtimer` (now in `run.sh`, [doc 06-1](docs/en/06-1timer.md)) |
| "00 Timer" inside the **arcade** list (new `games.db` row) | Menu hung on the loading screen twice; card restored |
| FPS counter, shaders, high-res textures | Not drawn by this build / not worth it / not supported by the core |

## Still pending

1. **Black screen when opening the bag during a Pokémon battle (Stone Dragon 3):** run Test A (`fastforward_ratio = 0`), confirm Test B (remap disabled) and note the second the screen turns black; run the `smaps` meter.
2. **Timer, remaining details:** audio pop when the game resumes, a button pressed during the pause may reach the game, `killall aplay` also stops other `aplay` processes ([06-1](docs/en/06-1timer.md), section 8).
3. **Record the consumption numbers (Enhanced Resolution and PK GS RAM):** the author already tested Enhanced Resolution (CPU cost, visual comparison, option-file integrity), but the numbers are not in the repo. Run `scripts/debug/consumption_report.sh`: it reads `timer/hook.log` and generates [doc 08](docs/en/08-measured-consumption.md). About PK GS (~78 MB or ~110 MB?): if its session comes out flagged ⚠, open **only** PK GS for ~2 min and generate again.
4. **Fast-forward:** pick the final `fastforward_ratio` (2.5 vs 3.0) and optionally restrict it to Pokémon games only. The author notices it works better in the **closed/indoor areas** of the Pokémon games and that it does **not make anything worse**, but this is **not confirmed** [observed].
5. **Clean up** test files and meters on the card (list in [doc 04](docs/en/04-pokemon-fastforward.md) and [05](docs/en/05-diagnosis-black-screen-ram.md)).
6. **Covers for ROM hacks:** the rule "cover = `.png` with the same name as the game" is confirmed for regular games, but it is **not known whether it works for ROM hacks**. Covers for hacks/translations and arcade names are done by hand, on purpose.
7. **Full screen:** [06-1](docs/en/06-1timer.md) says non-GBA games read the card's `gbx66.cfg`, but [04](docs/en/04-pokemon-fastforward.md) measured that the stick ignores it; [03](docs/en/03-graphics-and-consumption.md) also noted a 480x272 viewport versus the 1280x720 output in 06-1. Confirm on the stick which is right (GBA uses `gbx_mod.cfg`, which is really read, so start there).
8. **History tab:** automatic 15-game limit and single-game delete on the device, a boot hook (today the button only works after a game has been opened), a confirmation step, other devices/firmwares ([history doc](docs/en/game_stick_history.md), section 5).

### Resolved (author's tests on the device)

- ✅ **Timer over an arcade game** works (previously only tested over GBA).
- ✅ **Covers show in the menu** (the cover is the `.png` named like the game) and **old saves load** after the save-folder change.
- ✅ **Multi-disc PBP** (Tales of Destiny II) tested on the stick: it works.
- ✅ **Enhanced Resolution:** CPU cost, visual comparison and option-file integrity were checked by the author (numbers: see item 3).

## Repository layout

```
docs/en/  docs/pt-BR/     chapters 01–06 (+ 06-1 timer details), 07 scripts guide, 08 measured consumption (generated), history chapter (same content, two languages)
scripts/ps1/              convert_ps1.sh, multidisc_pbp.sh
scripts/covers/           check_covers.py, missing_covers_manual.py
scripts/config/           set_fastforward.sh, set_enhanced_resolution.sh, eject.sh, hist.py, make_mold.py, sel_limpa.sh
scripts/debug/            avg_per_game.sh, per_session.sh, consumption_report.sh (read timer/hook.log; the last one generates doc 08)
scripts/pt-BR/            the same scripts with Portuguese comments and messages (see scripts/pt-BR/LEIA-ME.md)
scripts/timer/            hook.sh (timer version, "update 3"), run.sh (final: 15 s alert, game paused)
assets/timer_covers/      10 AI-generated cover images for the "00 Timer" entries
```

## Files that will be added later

- `capas_gamestick.py` (bulk cover downloader; `missing_covers_manual.py` depends on its cache)
- the improved PS1 converter (`ps1_pbp.py`, multi-disc merge, `.chd` through `chdman`) and the `tests/` suite: written in a review session (23/23 on synthetic discs with the real PSXPackager 1.6.2) but **not part of this repo yet**
- `gbx_mod.cfg` and `ra_wrap.sh` (GBA launch config and wrapper with the RAM/CPU sampler)
- the *GBA* version of `hook.sh` (the one in `scripts/timer/` is the timer version; both need to be merged, see [doc 06](docs/en/06-timer.md))
- `gtimer` is **not** included on purpose (closed ARM binary, no source, unknown license)

## Scripts: quick start

> Full step-by-step guide (setup, every script, output explained, troubleshooting): **[docs/en/07-scripts-guide.md](docs/en/07-scripts-guide.md)**

The PC scripts need the card mounted and two environment variables:

```bash
lsblk; ls /run/media/$USER/                # find your card's label
export SD=/run/media/$USER/<LABEL>         # card mount point (data partition)
export PSX=$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager   # only for PS1 conversion
```

| I want to... | Run |
|---|---|
| Convert PS1 games to PBP (keeps originals) | `scripts/ps1/convert_ps1.sh --dry-run`, then without `--dry-run` |
| Also delete originals (after testing on the stick) | `scripts/ps1/convert_ps1.sh --delete` |
| See which games have no cover | `python3 scripts/covers/check_covers.py` |
| Change Pokémon battle speed | `scripts/config/set_fastforward.sh 2.5` |
| Toggle PS1 Enhanced Resolution | `scripts/config/set_enhanced_resolution.sh enabled` |
| Eject the card safely | `lsblk`, then `scripts/config/eject.sh /dev/sdb` |
| Read RAM/CPU from the log | `scripts/debug/avg_per_game.sh` |
| Generate the consumption report (doc 08) | `scripts/debug/consumption_report.sh` |
| See the console History tab from the PC | `python3 scripts/config/hist.py show` |
| Keep only the 15 most recent in History | `python3 scripts/config/hist.py trim` |

The scripts here are cleaned-up versions of the ones used during the project: paths are variables, there is a `--dry-run`, and deleting originals is now opt-in. `convert_ps1.sh` no longer corrupts accented `.cue` names. On the stick, `scripts/timer/run.sh` is the final version (15 s alert, game paused) and `scripts/timer/hook.sh` was left **byte-identical** to what runs there, because untested edits to a boot hook could break the menu.

> 🇧🇷 **Portuguese scripts:** `scripts/pt-BR/` holds copies with Portuguese comments and messages (`converter_ps1.sh`, `ejetar.sh`, `relatorio_consumo.sh`...). Behaviour is the same; the command names above refer to the English versions.

## Safety rules kept during the project

1. Do not install RetroArch on the PC; do not run ARM binaries on x86_64.
2. Only touch the firmware with a full backup and a tested way back.
3. Check the device name with `lsblk` before any `dd` (it changed from `sda` to `sdb`).
4. Never delete what is not copied elsewhere; test on the stick before deleting originals.
5. The stick's clock is wrong (files get a 1979 date), so do not trust dates; use `cp -n` when copying saves back.

## License

MIT, see [LICENSE](LICENSE). Cover art in `assets/` was generated with AI by the author. ROMs, BIOS and firmware images are **not** part of this repository.
