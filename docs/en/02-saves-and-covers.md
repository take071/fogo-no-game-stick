# 02 · Saves in their own folder, and covers

[← previous](01-ps1-pbp.md) · [← back](../../README.md) · [next: graphics and consumption →](03-graphics-and-consumption.md)

## Part A: saves and states in `saves/` and `states/`

### What was found

- Saves were stored next to the games (`game/gba/*.srm`, `game/ps1/*.srm`, `.state1`).
- The exFAT `gbx66.cfg` files (root and `retro_lib/`) and the squashfs one had `savefile_directory = "default"`.
- Changing **only** the exFAT cfgs **did not work**: the stick did not read that file, wrote saves next to the games and did not recognise the old saves. (Consistent with what was learned later: the stick uses the internal config in `/usr/local/share/minigui/`.)
- The stick's clock is wrong: files it writes get the date `1979-12-31`. Handy to tell what the stick wrote.

### What was done (squashfs patch)

> Partition `p4` is read-only: you must extract, edit, rebuild and re-flash the image. An earlier note said the system "cannot be edited"; this procedure supersedes that.

1. Backup: `dd if=/dev/sdX4 of=~/sdb4_original.img` (68157440 bytes, checked against the partition size). **Do not delete this file.**
2. Extract: `unsquashfs -d ~/sqfs_root /dev/sdX4`.
3. In `usr/local/share/minigui/gbx66.cfg` and `gbx66_ko.cfg`:
   ```
   savefile_directory = "/sdcard/saves"
   savestate_directory = "/sdcard/states"
   savefiles_in_content_dir = "false"
   savestates_in_content_dir = "false"
   ```
4. Rebuild with the same parameters: `mksquashfs ~/sqfs_root ~/sdb4_novo.img -comp gzip -b 131072 -noappend` (19 MB, fits in 65 MB). The file list was compared with the original: identical.
5. Write to `/dev/sdX4` and verify with `cmp` ("GRAVACAO OK"); mount it and read the two cfg lines.
6. Existing saves were copied to `saves/` and `states/` before the change; the exFAT cfgs were restored from `.bak`.

> No script automates the `dd` on purpose: writing to the wrong device wipes a disk. Always check with `lsblk`.

### Verified [measured]

After playing, files dated 1979 showed up in `saves/` (`Resident Evil 2 Leon.srm`, `PK GS Chronicles 2.7.4.srm`, `Stone Dragon 3.srm`) and in `states/` (`Resident Evil 2 Leon.state1`). No `.srm` was left loose in `game/`.

### How to undo

```bash
lsblk                                   # make sure it is the card (65 MB squashfs)
sudo dd if=$HOME/sdb4_original.img of=/dev/sdX4 bs=4M conv=fsync
```
Never write to the computer's SSD.

### Incidents

| Incident | Cause | Fix |
|---|---|---|
| `lsblk: /dev/sda: not a block device` | Card reappeared as `sdb` | Always `lsblk` before writing |
| `OSError: Input/output error` in Python | Terminal was inside a card folder before the card was reconnected | `cd ~` and retry |
| Firmware reverted right after flashing | The restore `dd` was run right after, by mistake | Flash again and do **not** run the restore |
| `eject: unable to eject` | Partition mounted/in use | `sync`, unmount, `udisksctl power-off` (see `scripts/config/eject.sh`) |

### Careful with future backups

Since the clock is wrong, dates do not say which copy is newer. When copying saves back, use `cp -n` so a more recent progress is not overwritten.

### Pending

Old progress (Stone Dragon 3, PK GS) loading after the folder change was **not confirmed** [pending]. Old saves are in `saves/` and also in `game/gba/`.

## Part B: covers

### How the menu seems to find covers [hypothesis]

`tbl_game` in `games.db` has no image column and the `picture/` folder is empty. But `game/md/` and `game/ps1/` already had images named like the game. Hypothesis: **the cover is the `.png`/`.jpg` with the same name as the game, in the same folder.** **Not yet confirmed on the device.**

### What was done

- Covers from the `libretro-thumbnails` repo (`Named_Boxarts`), preferring USA, at 400x400 (the most common size in GBA and PS1), saved as `<game name>.png`.
- PS1: A Bug's Life and Alundra got covers; two loose images with no game were deleted; the BIOS image was kept.
- All folders: `capas_gamestick.py` (**to be added**) checked each game and downloaded **48 covers** (mostly GBA). 47 already existed; 3 were left.
- The remaining 3 (Mega Man & Bass, Mother 1 & 2, `3wonders`) were fetched by hand: `scripts/covers/missing_covers_manual.py`.
- Final check: `scripts/covers/check_covers.py`.

### Limitations

- The repo replaces `&` with `_`; the first version of the script compared asymmetrically and missed 2 games (fixed).
- Hacks and translations (e.g. "Super Mario World 3 - Hack") are **left without a cover on purpose**, to avoid a wrong image. Add it by hand with the exact name `<game>.png`.
- Arcade (`cps`) uses short `.zip` names; automatic matching fails for most.
- GitHub allows 60 requests/hour without login; the script caches in `~/.cache/capas_gamestick`.
- Some European ROMs got the US art of the same game.

### Pending

On the device, open the PS1 menu (Chrono Cross, Crash Bandicoot) and the GBA menu (Golden Sun, Metroid Fusion). If no cover shows, the menu uses another mechanism and the downloaded covers have no effect.
