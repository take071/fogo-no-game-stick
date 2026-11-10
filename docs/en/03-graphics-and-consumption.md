# 03 · PS1 graphics and consumption

[← previous](02-saves-and-covers.md) · [← back](../../README.md) · [next: Pokémon →](04-pokemon-fastforward.md)

## Files the stick reads

- `retro_lib/retroarch-core-options.cfg`: core options (pointed to by `core_options_path`, with `global_core_options = "true"`).
- `retro_lib/pcsx_rearmed_libretro.so`: PS1 core.
- `retroarch/` and `timer/retroarch-core-options.cfg` look like leftovers from another system (Recalbox) and are probably not read **[inferred]**.
- Note: chapter 04 shows the card's `gbx66.cfg` is not used (but see the unresolved conflict with [06-1](06-1timer.md), section 5). Whether the card's **core options** file is really the one read was not confirmed on its own; the effect seen below is visual and subtle.

## PS1 Enhanced Resolution

Before **[measured]**: `video_smooth = "true"`, shader off, `pcsx_rearmed_dithering = "disabled"`, `neon_enhancement_enable = "disabled"`, `neon_enhancement_no_main = "disabled"`. The file's `.bak_original` had both NEON options on; someone turned them off later.

Change: `scripts/config/set_enhanced_resolution.sh enabled` (same as a `sed` on `pcsx_rearmed_neon_enhancement_enable`). Checked with `grep`.

Result:
- Crash Bandicoot 2 showed no visible glitches; the horizontal lines from the first photo disappeared **[seen in photos]**.
- Edges still jagged and textures still pixelated. The option does not raise PS1 texture resolution; at 480x272 the expected gain is modest **[inferred]**.
- The comparison is not rigorous: the photos show different scenes.
- No backup was made before (the new script does). To revert: `set_enhanced_resolution.sh disabled`.
- In the pasted `grep` output, `no_main` showed up without the closing quote. Probably a copy error. **The author checked the options file** [tested by the author]; `consumption_report.sh` now repeats that check and records it in [doc 08](08-measured-consumption.md).

Not applied: light shader (`sharp-bilinear`/`xbr`; the `retroarch/shaders` folder exists but was not listed), high-res textures (PCSX-ReARMed does not support them).

## How consumption is measured

- `timer/ra_wrap.sh` (GBA, slot 7) logs to `hook.log` every 5 s: `dtick` (CPU), `livre` (MemFree) and `rss` (RetroArch RAM).
- `timer/amostra_ps1.sh` (PS1, slot 9) does the same and also logs `pico` (`VmHWM`).
- `dtick` per 5 s: ~500 = one full core (CPU% = `dtick/5`). `livre` ignores discardable cache: good for comparing games, not as total RAM.
- The `smaps` meter in `ra_wrap.sh` writes to `timer/smaps_log.txt`; the file does not exist because `hook.sh` only sends GBA through `ra_wrap.sh` **[inferred]**.

Scripts: `scripts/debug/avg_per_game.sh` and `per_session.sh`.

## Measured consumption

| Game | Avg RAM | Max RAM | Peak | Min free | Avg CPU |
|---|---|---|---|---|---|
| Castlevania (PS1) | 41 MB | 42 MB | 47 MB | 17.1 MB | 49% |
| Crash Bandicoot 2 (PS1) | 40 MB | 41 MB | 46 MB | 58.8 MB | 75% |
| PK GS (GBA) | 94 MB* | 110 MB* | n/a | 2.6 MB* | 80%* |
| Stone Dragon 3 (GBA) | 107 MB | 110 MB | n/a | 2.4 MB | 82% |

\* contaminated by an attribution error (below).

CPU figures from other sessions (ch. 05) sit around 60–70% for PS1 and ~93% for GBA (`dtick` ~467); averages differ depending on which samples are included.

- **PS1:** ~40 MB and 49–75% of one core, with headroom. With Enhanced Resolution on, Crash 2 used the same RAM as Castlevania without it (peaks 46 and 47 MB).
- **Stone Dragon 3:** consistent over 7 sessions (107–110 MB, 2–6 MB free). RAM stays fixed after loading: looks like a single allocation, not a leak. Why it uses ~33 MB more than PK GS with same-size ROMs (32 MB) is **unknown**.
- **GBA in general:** ~93% of one core; RetroArch does not crash (`rc=0`, clean `ra.err`).

## The PK GS attribution problem

The script attributes each sample to the last `hook` line read. Per session:

| PK GS | Samples | Max RSS |
|---|---|---|
| 1st | 25 | 78 MB |
| 2nd and 3rd | 1 each | 75 MB |
| 4th | 4 | 109 MB |
| 5th | 12 | 109 MB |
| 6th | 22 | 110 MB |

PK GS's real value seems to be ~78 MB (clean session). The 109–110 MB ones coincide with Stone Dragon 3: probably SD3 samples logged under a PK GS `hook` **[inferred]**. The alternative (PK GS really climbing to ~110 MB) cannot be ruled out with the current log.

## Pending

The author already ran tests 1, 3 and 4 below (Enhanced Resolution CPU cost, option-file integrity and a visual comparison) [tested by the author], but **the numbers were not kept in the repo**. To record them and answer pending items 1, 2 and 3 at once:

```bash
export SD=/run/media/$USER/<LABEL>
scripts/debug/consumption_report.sh     # in Portuguese: scripts/pt-BR/debug/relatorio_consumo.sh
```

The command only **reads** `timer/hook.log` and `retroarch-core-options.cfg` and generates [doc 08](08-measured-consumption.md) with RAM/CPU per game and per session, the current NEON state and the integrity check.

1. CPU cost of Enhanced Resolution: Castlevania ~2 min with the option on vs. the earlier 49%. *(done by the author; numbers in doc 08)*
2. PK GS: open only it for ~2 min, exit and generate the report; `rss` ~78 MB confirms the attribution error (the suspect session is flagged ⚠).
3. Options file integrity (`grep neon`). *(done; the report repeats the check)*
4. Photos of the same point in the game with the option on and off. *(done by the author)*
5. `smaps_log.txt`: only created in a GBA game, after 15 s.
