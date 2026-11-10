# 🔥 fogo no game stick

🇧🇷 [Leia em português](README.md)

This is where I keep everything I found out and changed on my **Game Stick 4K Lite** (red board, firmware "V5 Base TG", MiniGUI menu + RetroArch 1.7.4). I did it all from a Fedora PC, without installing RetroArch and without running ARM code on x86_64.

> **Work in progress.** This repo is my notebook: what worked, what I tried and dropped, and what is still missing. I tag every claim: **[measured]** seen in a log/command · **[inferred]** deduced, not confirmed · **[hypothesis]** suspicion without proof · **[pending]** not tested yet.

> **About "battles":** here, "battles" always means the **turn-based battles of the Pokémon GBA hacks** (PK GS Chronicles 2.7.4 and Stone Dragon 3, both FireRed-based). The speed-up (`fastforward_ratio`) applies to GBA games launched through the hook, but you only notice it in those battles; map, menus and text stay at normal speed. Pokémon Mystery Dungeon has no turn-based battles, and PS1/arcade are not affected.

> ⚠️ Use at your own risk. Back up before touching the firmware partition. Examples use `/run/media/user/<LABEL>` as the card mount point; replace it with yours.

## The device at a glance

| Item | Value |
|---|---|
| Device | Game Stick 4K Lite, red board, V5 Base TG |
| CPU / RAM | 1 core @ 1008 MHz (only frequency), ~230 MB usable, no swap **[measured]** |
| Kernel | Linux 4.4.194 armv7l, BusyBox 1.27.2 **[measured]** |
| Emulator | RetroArch 1.7.4 (ARM 32-bit hard-float, glibc 2.29) **[measured]** |
| Cores | `pcsx_rearmed` (PS1), `mgba` (GBA, slot 7) |
| Card partitions | `p1–p3` boot (don't touch) · `p4` squashfs 65 MB (system, read-only) · `p5` exFAT (data, shows as `/sdcard`) |
| Games | `game/<console>/` (`atari cps fc gb gba gbc md n64 ps1 sfc`) |

## What I did

| # | Topic | Result | Doc |
|---|---|---|---|
| 1 | PS1: CUE/BIN → PBP (fixing broken `.cue` files) | ✅ 6 games converted, 10 PBPs total, tested on the stick | [01](docs/en/01-ps1-pbp.md) |
| 2 | Saves/states redirected to `saves/` and `states/` (squashfs patch) | ✅ new saves land in the new folders **[measured]** | [02](docs/en/02-saves-and-covers.md) |
| 3 | Cover art (libretro-thumbnails) | ✅ downloaded · ❓ menu display not confirmed | [02](docs/en/02-saves-and-covers.md) |
| 4 | PS1 "Enhanced Resolution" + RAM/CPU measuring | ✅ applied · ❓ CPU cost not isolated yet | [03](docs/en/03-graphics-and-consumption.md) |
| 5 | Faster Pokémon battles (`fastforward_ratio` via `hook.sh`) | ✅ works (2.5 "perfect", 3.0 in use) | [04](docs/en/04-pokemon-fastforward.md) |
| 6 | Black screen when opening the bag in battle + RAM use in the hacks | 🔎 several causes ruled out; `smaps` showed **real memory**, not cache | [05](docs/en/05-diagnosis-black-screen-ram.md) |
| 7 | "00 Timer": alert **fixed for 15 s**, game pauses and resumes, any button dismisses | ✅ solved (it used to flicker) | [06](docs/en/06-timer.md) |
| 8 | Full screen 16:9 (`aspect_ratio_index = 1`) | ✅ on GBA games · ❓ other consoles depend on the internal cfg | [06](docs/en/06-timer.md) |
| 9 | **Hold Start for 3 s** on the History tab wipes history and restarts the menu | ✅ tested, on one device only | [08](docs/en/08-history-button.md) |
| 10 | "00 Timer" inside the **arcade** list | ❌ gave up (menu hung); the timer works across the whole stick | [06](docs/en/06-timer.md) |

Photos I took along the way are in [`docs/fotos/`](docs/fotos), with captions in [09 – evolution in photos](docs/en/09-photos-evolution.md).

## What I gave up on

| Idea | Why |
|---|---|
| Editing `gbx66.cfg` / `start_game.sh` **on the exFAT card** | The stick uses the internal config in `/usr/local/share/minigui/`. Only the squashfs patch and `hook.sh` worked. (See the open question under "Still pending".) |
| Fast-forward button (L / Start / `_btn` codes) | L already does something in battle, Start did nothing, and the pad sends keyboard keys. Speed was already fine |
| Auto fast-forward by timer or by reading game memory | Refused / would need a custom RetroArch and one address per hack |
| Newer mGBA, gpSP, `performance` governor, threaded video etc. | No gain, or no game opened (gpSP needs `gba_bios.bin`); reverted |
| Timer inside the **arcade** list (new `games.db` row) | The menu hung on the loading screen twice; I restored the card |
| Using **Select** as the history button | Holding Select opens the device's settings menu |
| FPS counter, shaders, high-res textures | Not drawn by this build / not worth it / not supported by the core |

> **Correction:** I used to note that `kill -STOP` on RetroArch "made the timer worse" and was reverted. I later understood my mistake: in that old attempt I froze the game **after** starting `gtimer`, and nothing guaranteed the `kill -CONT`. Freezing **before**, with a `trap` to resume, works. Details in [doc 06](docs/en/06-timer.md).

## Still pending

1. **Black screen opening the bag in battle (Stone Dragon 3):** run Test A (`fastforward_ratio = 0`), record the result of Test B (remap disabled) and the second the screen goes black.
2. **Timer over an arcade game:** I only saw it over GBA. Should be the same, but it's a hypothesis.
3. **Full screen outside GBA:** check whether the internal cfg (`/usr/local/share/minigui/gbx66.cfg`) also needs the patch.
4. **Covers in the menu** and **old saves** (Stone Dragon 3, PK GS) after the folder change.
5. **Enhanced Resolution:** CPU cost (Castlevania ~2 min on/off) and a fair visual comparison; check the closing quote on `no_main`.
6. **PK GS RAM:** ~78 MB or ~110 MB? (log attribution problem). Run the same `smaps` test on it.
7. **Multi-disc PBP** (Tales of Destiny II): see [doc 10](docs/en/10-psxpackager-fixes.md); the fixed script still has to be added to the repo.
8. **Automatic 15-game history limit** on the device itself.
9. **Pick the final `fastforward_ratio`** (2.5 or 3.0) and optionally limit it to Pokémon only.
10. **Clean up** test files and meters on the card.

## Repository layout

```
docs/en/  docs/pt-BR/     chapters 01–10 (same content in both languages)
docs/fotos/               photos from the tests, in the order I took them
scripts/ps1/              convert_ps1.sh, multidisc_pbp.sh
scripts/covers/           check_covers.py, missing_covers_manual.py
scripts/config/           set_fastforward.sh, set_enhanced_resolution.sh, eject.sh
scripts/debug/            avg_per_game.sh, per_session.sh, diag_swap.sh
scripts/timer/            hook.sh, run.sh (new), run_original.sh, hook_timer_restaurado.sh
assets/timer_covers/      10 AI-generated covers for the "00 Timer" entries
```

## Files I still have to add

- `capas_gamestick.py` (bulk cover downloader; `missing_covers_manual.py` depends on its cache)
- `gbx_mod.cfg` and `ra_wrap.sh` (GBA config and the wrapper with the RAM/CPU sampler)
- the *GBA* version of `hook.sh` (the one in `scripts/timer/hook.sh` is the timer version; they need to be merged)
- the history scripts: `hist.py`, `make_mold.py`, `sel_limpa.sh` (see [doc 08](docs/en/08-history-button.md))
- `gtimer` is **not** included on purpose (closed ARM binary, no source, unknown license)

## Scripts: quick start

> Full step-by-step guide: **[docs/en/07-scripts-guide.md](docs/en/07-scripts-guide.md)**

```
lsblk; ls /run/media/$USER/                # find your card's label
export SD=/run/media/$USER/<LABEL>         # mount point (data partition)
export PSX=$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager   # only for PS1 conversion
```

| I want to... | Run |
|---|---|
| Convert PS1 to PBP (keeps originals) | `scripts/ps1/convert_ps1.sh --dry-run`, then without `--dry-run` |
| Delete originals (after testing on the stick) | `scripts/ps1/convert_ps1.sh --delete` |
| See which games have no cover | `python3 scripts/covers/check_covers.py` |
| Change battle speed | `scripts/config/set_fastforward.sh 2.5` |
| Toggle Enhanced Resolution | `scripts/config/set_enhanced_resolution.sh enabled` |
| Eject the card | `lsblk`, then `scripts/config/eject.sh /dev/sdb` |
| Read RAM/CPU from the log | `scripts/debug/avg_per_game.sh` |

## Rules I follow

1. I don't install RetroArch on the PC and I don't run ARM binaries on x86_64.
2. I only touch the firmware with a full backup and a tested way back.
3. I check the device name with `lsblk` before any `dd` (it changed from `sda` to `sdb`).
4. I never delete what isn't copied elsewhere; I test on the stick before deleting originals.
5. The stick's clock is wrong (files get a 1979 date). I don't trust dates and I use `cp -n` when copying saves back.
6. **I never overwrite `timer/hook.sh` without keeping the original.** That's how the timer stopped opening (see [doc 06](docs/en/06-timer.md)).
7. `.sh` files edited on Windows get `\r`: I run `sed -i 's/\r//g'` before copying them to the card.

## License

MIT, see [LICENSE](LICENSE). Cover art in `assets/` was generated with AI by me. ROMs, BIOS and firmware images are **not** part of this repo.
