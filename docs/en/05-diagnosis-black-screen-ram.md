# 05 · Diagnosis: black screen and RAM in the Pokémon hacks

[← previous](04-pokemon-fastforward.md) · [← back](../../README.md) · [next: timer →](06-timer.md)

Legend: **[measured]** · **[hypothesis]**.

## Reported problems

1. Stone Dragon 3 (SD3) slow in battles; wanted smoothness in all Pokémon games.
2. Opening the bag **during a battle** in SD3 turns the screen black instantly; sound continues but stutters. Outside battle the bag works.
3. PK GS was slow after leaving SD3.
4. The timer's "TEMPO ACABOU" image flickers (ch. 06).
5. Sprout Tower (PK GS) ran at normal speed.

## System [measured]

- RetroArch 1.7.4, 1 core @ 1008 MHz, ~230 MB usable RAM, no swap.
- mGBA at `retro_lib/mgba_libretro.so` (710052 bytes, from 2018), listed as "ORIGINAL" in the vendor's `readme.txt`.
- The `game` frontend (menuguide) stays in RAM all the time: **~64 MB**.
- Both ROMs are FireRed (`BPRE`) v0, save type `FLASH1M_V103`, 32 MB each. SD3 has a correct header checksum; PK GS does not (mGBA ignores it).

## Ruled out

| Hypothesis | Result |
|---|---|
| Faulty card | `fsck.exfat` clean, 4.4 GB read with no error. I/O errors came from **USB drops** (`sda` → `sdb`) |
| Something "stuck" between games | `procs` empty after each game, same config checksum, free memory back to ~163 MB |
| Corrupt ROM | SD3 header intact, same save type (does not prove the hack has no bug) |
| Start button tied to fast-forward | Dropped on request |
| `mgba_idle_optimization` | Set to `Remove Known` in SD3's `.opt`: **black screen persisted** |
| Newer mGBA core (`mgba_new.so`) | Menu worked; **same black screen and speed** |
| gpSP (`mame2003_libretro.so`) | **No game opened** (looks for a missing `gba_bios.bin`). Reverted |
| CPU/GPU frequency | Only one frequency; `performance` had nothing to unlock |

Ruled out in the RAM session (read-only checks on the card): runtime patching (`.ips/.bps/.ups`), compressed ROM (both are plain `.gba` of 33554432 bytes), rewind (`rewind_enable = "false"`), savestate auto load/save (`false`), different save sizes (both 131072 bytes), core options in SD3's `.opt` (nothing reserves memory; PK GS has no `.opt`), and `performance` writes in `ra_wrap.sh` (none; it only reads governor/devfreq).

## Measurements [measured]

| Game | RetroArch RAM (`rss`) | Free RAM | CPU |
|---|---|---|---|
| PS1 (Castlevania) | ~43 MB (peak ~48) | ~17 to 49 MB | ~60–70% (`dtick` ~290–365) |
| PK GS (GBA) | ~78 MB | ~34 MB | ~93% (`dtick` ~467) |
| Stone Dragon 3 (GBA) | ~110–112 MB | **~3 to 6 MB** | ~93% |

- GBA hacks use more RAM than PS1 (PK GS ~1.8x; SD3 ~2.6x).
- SD3 uses ~33 MB more than PK GS **with same-size ROMs**: cause unknown.
- At ~93% of one core there is almost no headroom.
- RetroArch **does not crash** at the black screen: `rc=0`, high `dtick`, clean `ra.err`.
- In the SD3 log: `rss` climbs ~21 MB → ~75 MB → ~110 MB in ~10 s and then **stays fixed** at ~110636 kB (looks like a one-off allocation, not a leak); `livre` constant ~5.9 MB.

## Open hypotheses

1. **Memory pressure causes the black screen.** Consistent with low RAM and sound continuing, but the log does not show the moment of the black screen.
2. **CPU overload** when opening the bag in battle (sound stutters). No proof: no timestamp was noted.
3. **`fastforward_ratio` makes it worse** (it only acts in battle and the black screen only happens in battle). **Test A (`0.000000`) was not done.**
4. **Something in SD3's remap** (`input_libretro_device_p1 = "5"`, absent in PK GS). The remap is already `Stone Dragon 3.rmp.off` (Test B applied), but **the bag result was not noted**.
5. **The hack itself** behaves like this on the stick's hardware. A PC test with `mgba-qt` was declined.
6. **`performance` caused the `rc=139`** (menuguide crash). They stopped after reverting `performance`, `video_threaded`, `video_font_enable`, `history_list_enable` and `drop_caches` **together**; the exact cause was not isolated.
7. **The RAM "arithmetic":** base ~43 MB + ROM suggests one ROM copy in PK GS and two in SD3. It fits numerically, but no mechanism was found.
8. **`rss` includes mapped file cache (discardable).** If so, the "3–6 MB free" is misleading and low RAM probably does **not** cause the black screen. `smaps` separates anonymous from file memory.

## `smaps` meter (inserted, NOT yet tested on the stick)

Inserted into `ra_wrap.sh` between the `# smaps_ini` and `# smaps_fim` markers (lines 26 to 41), before `/usr/bin/retroarch "$@"`. Takes 8 samples every 15 s (~2 min) into `timer/smaps_log.txt`: `MemFree`, `MemAvailable`, `Cached`, `AnonPages`, `Mapped`, `VmRSS`/`RssAnon`/`RssFile` and the 8 largest mappings. No backup of `ra_wrap.sh` (author's decision); the marked block can be removed without a copy.

## Next tests (one variable at a time)

1. **`smaps`:** eject; PK GS ~2 min on the map; SD3 in battle → open bag → **note after how many seconds it turns black** → ~2 min; exit through the menu. On the PC: `cat timer/smaps_log.txt` and `tail -15 timer/hook.log`.
2. **Read:** SD3 `RssAnon` ~33 MB bigger = real extra memory (investigate core/hack); difference only in `RssFile` = cache (RAM is probably not the cause); `MemAvailable` of a few MB at bag time = real pressure. If the kernel lacks `RssAnon/RssFile`, ignore those lines. If `smaps_log.txt` never appears, check `[inicio]`/`[amostra]` in `hook.log` and the `/sdcard/timer/` path.
3. **Test A:** `scripts/config/set_fastforward.sh 0` and open the bag in battle in SD3.
4. Repeat the bag with the `.rmp` disabled, noting the result.
5. **Pick the ratio:** measure `dtick` in battles with 2.0, 2.5, 3.0. ~500 in all three = a matter of taste; a drop with a lower ratio = spare CPU.

## Clean up the meters at the end

```bash
cd /run/media/user/<LABEL>
sed -i '/# smaps_ini/,/# smaps_fim/d' timer/ra_wrap.sh
sed -i 's#sh /sdcard/timer/ra_wrap.sh -y#/usr/bin/retroarch -y#' timer/hook.sh
sed -i '/amostra_ps1/d' timer/hook.sh
sync
```

## Cautions

- Always eject before removing the card/cable (`scripts/config/eject.sh /dev/sdX`); there were USB drops and a "volume not unmounted" warning.
- A governor changed by script only returns to normal after unplugging the power.
- Savestates (`.state1`) may not load across different cores; `.srm` saves are unaffected.
- No general backup; **`saves/` is the only irreplaceable thing** on the card. Quit games through the menu.
