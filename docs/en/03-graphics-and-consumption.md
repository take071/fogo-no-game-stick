# 03 – PS1 graphics and RAM/CPU usage

Legend: **[measured]** · **[inferred]** · **[pending]**

## How the card is organized (short)

- `gbx66.cfg` at the card root and `retro_lib/retroarch-core-options.cfg`: the second holds the core options (`core_options_path`, with `global_core_options = "true"`) **[measured]**.
- `retro_lib/pcsx_rearmed_libretro.so` is the PS1 core.
- The `retroarch/` folder and `timer/retroarch-core-options.cfg` look like leftovers from another system and are probably not read **[inferred]**.
- Hardware: 1 core @ 1008 MHz **[measured, `hook.log`]**.

## PS1 Enhanced Resolution

**Before** **[measured]**: `video_smooth = "true"`, no shader, `pcsx_rearmed_dithering = "disabled"`, `neon_enhancement_enable = "disabled"` and `neon_enhancement_no_main = "disabled"`. The `.bak_original` of the options file had both `neon_enhancement` options on; someone (me) turned them off later.

**What I changed:**

```bash
sed -i 's/^pcsx_rearmed_neon_enhancement_enable = .*/pcsx_rearmed_neon_enhancement_enable = "enabled"/' retro_lib/retroarch-core-options.cfg
```

**What I saw in game:** in Crash Bandicoot 2 the horizontal lines from the first photo went away, but edges are still jagged and textures pixelated (photos 13, 14 and 16 in [docs/fotos](../fotos)). Enhanced Resolution doesn't raise texture resolution, and on a small screen the gain is modest **[inferred]**. The photos show different scenes, so the comparison is **not rigorous** **[pending]**.

**Undo** (I made no backup first):

```bash
sed -i 's/^pcsx_rearmed_neon_enhancement_enable = .*/pcsx_rearmed_neon_enhancement_enable = "disabled"/' retro_lib/retroarch-core-options.cfg
```

In the `grep` output I pasted, `no_main` showed up without the closing quote. Probably a copy error, but I haven't checked: `grep neon retro_lib/retroarch-core-options.cfg` **[pending]**.

## How I measure usage

- `timer/ra_wrap.sh` writes to `hook.log` every 5 s: `dtick` (CPU), `livre` (MemFree) and `rss` (RetroArch RAM). GBA only (slot 7).
- `timer/amostra_ps1.sh` does the same for PS1 (slot 9) and also logs `pico` (`VmHWM`).
- `dtick` per 5 s: ~500 is one full core; CPU % = `dtick / 5`.
- `livre` is MemFree and does **not** count reclaimable cache. See [doc 05](05-diagnosis-black-screen-ram.md): this matters.

## Results per game **[measured]**

| Game | Avg RAM | Max RAM | Peak | Lowest headroom (MemFree) | Avg CPU |
|---|---|---|---|---|---|
| Castlevania (PS1) | 41 MB | 42 MB | 47 MB | 17.1 MB | 49% |
| Crash Bandicoot 2 (PS1) | 40 MB | 41 MB | 46 MB | 58.8 MB | 75% |
| PK GS (GBA) | 94 MB* | 110 MB* | n/a | 2.6 MB* | 80%* |
| Stone Dragon 3 (GBA) | 107 MB | 110 MB | n/a | 2.4 MB | 82% |

\* PK GS values are contaminated by an attribution error (below).

- **PS1:** ~40 MB and 49–75% of one core. With Enhanced Resolution on, Crash 2 used the same RAM as Castlevania without it.
- **GBA:** ~93% of one core in stable samples (`dtick` ~467), almost no margin. RetroArch doesn't crash (`rc=0`, clean `ra.err`).
- **Stone Dragon 3:** fixed 107–110 MB after loading, across 7 sessions.

### PK GS attribution problem

The averaging script ties each sample to the last `hook` line it read. Listing session by session, the first (clean) PK GS session gives ~78 MB; the 109–110 MB ones coincide with Stone Dragon 3 **[inferred]**. So the 94 MB PK GS average isn't reliable. The safe fix is to write the game name inside each `[amostra]` line in `ra_wrap.sh`.

## Pending

1. CPU cost of Enhanced Resolution (Castlevania ~2 min on/off).
2. PK GS alone for ~2 min and `tail -30 timer/hook.log` to confirm ~78 MB.
3. `grep neon ...` to check the options file.
4. Photos from the same spot with the option on and off.
