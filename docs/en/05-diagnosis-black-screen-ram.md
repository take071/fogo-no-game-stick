# 05 – Black screen in the bag during battle, and RAM use in the hacks

Legend: **[measured]** seen in a log/command · **[inferred]** deduced · **[hypothesis]** no proof · **[pending]** not tested

## What bothers me

1. In Stone Dragon 3 (SD3), opening the bag **during a battle** turns the screen black at once. Sound continues but stutters. Outside battle the bag works.
2. PK GS was slow after leaving SD3.
3. SD3 uses ~33 MB more RAM than PK GS, with ROMs of the same size (32 MB).

## Ruled out

| Hypothesis | Result |
|---|---|
| Bad card | `fsck.exfat` clean, 4.4 GB read with no errors. The "I/O errors" came from **USB drops** (the device kept moving from `sda` to `sdb`) |
| Something "stuck" between games | `procs` empty after each game, same config checksum, free memory returns to ~163 MB |
| Corrupted ROM | SD3 header intact and same save type (`FLASH1M_V103`) in both. Doesn't prove the hack has no bug |
| `mgba_idle_optimization` | Changed to `Remove Known`. Black screen persisted |
| Newer mGBA (buildbot) | Menu worked; black screen and speed identical |
| gpSP | No GBA game opened (it wants `gba_bios.bin`, which isn't on the card). Reverted |
| CPU/GPU frequency | Only one exists; `performance` had nothing to unlock |
| Runtime patch, compressed ROM, rewind, auto savestate, save difference, core options | Checked on the card: none explains the RAM |
| `performance` still written in `ra_wrap.sh` | Not anymore; the script only reads governor/devfreq |

## New measurement: `smaps` of Stone Dragon 3 **[measured]**

I ran the diagnostic with SD3 open (samples every 10 s, kernel 4.4.194, no swap, no zram).

| Moment (uptime) | RetroArch RSS | Anonymous memory | MemFree | MemAvailable |
|---|---|---|---|---|
| 306 s (opening) | ~2 MB | 0.3 MB | 160 MB | 168 MB |
| 316 s | ~55 MB | ~51 MB | 75 MB | 120 MB |
| 326 s | ~112 MB | ~104.5 MB | 6.5 MB | 49.9 MB |
| 337–377 s | ~112 MB (fixed) | ~104.9 MB | ~6 MB | ~49.5 MB |

What it shows:

- **The RAM is real, not cache.** Of ~112 MB RSS, about **105 MB is anonymous memory** (`Anonymous` = `Private_Dirty`); only ~5.6 MB is clean file pages. This **knocks down** my earlier hypothesis that the 33 MB gap was just mapped file pages.
- **"3–6 MB free" was misleading.** `MemFree` sits at ~6 MB, but `MemAvailable` sits at ~49 MB. `Cached` (~72 MB) includes ~28 MB of `Shmem`, which can't be released without swap.
- **Memory pressure happened only during loading.** Between 316 s and 326 s there were `allocstall` = 10 and ~2800 pages scanned in *direct reclaim* (`pgscan_direct_normal`). After that the counters stayed still. `pswpin/pswpout` = 0 (no swap).
- **I still don't know** why SD3 uses 33 MB more than PK GS. I need the same `smaps` on PK GS **[pending]**.
- **Limit of this measurement:** none of the samples caught a battle or the open bag, so it **doesn't explain the black screen**. It only shows that, idle, there's no sustained memory squeeze **[inferred]**.

## Hypotheses still open

1. **[hypothesis]** A memory spike when opening the bag in battle (like the loading spike) makes the kernel reclaim pages and stall video. Fits the sound continuing, not proven.
2. **[hypothesis]** CPU overload in the battle bag (sound stutters). At ~93% of a core there's no slack.
3. **[hypothesis]** `fastforward_ratio` makes it worse: it only acts in battle, and the black screen only happens in battle. **Test A was not done.**
4. **[hypothesis]** Something in the SD3 remap (`input_libretro_device_p1 = "5"`, which PK GS lacks). I already renamed `Stone Dragon 3.rmp` to `.rmp.off`, but **I didn't record whether I repeated the bag afterwards**.
5. **[hypothesis]** The hack itself behaves this way on the stick's hardware.
6. **[hypothesis]** `performance` caused the `rc=139` (menu crash). The crashes vanished when I reverted several tweaks at once; the exact cause wasn't isolated.

## Next tests (one variable at a time)

1. **Test A:** `fastforward_ratio = "0.000000"` and open the bag in battle on SD3.
2. **Test B:** repeat with the `.rmp` disabled and **write down the result**.
3. **Note the second** the screen goes black (since opening the game) to cross it with the samples.
4. **`smaps` for PK GS** (~2 min on the map) and for SD3 **inside a battle**.
5. In-game options that cut work: Battle Scene: Off, Text Speed: Fast, Battle Style: Set.

## The mistake I made while measuring

To run the diagnostic I created a new `hook.sh` that only called `diag_swap.sh` and ended with `exit 1`. **That wiped the real timer `hook.sh`**, and the Timer started opening and closing instantly (see [doc 06](06-timer.md)). Hence the rule: never overwrite `hook.sh` without keeping the original. Swap had nothing to do with that problem.

## Cleaning up the meters at the end

```bash
cd /run/media/take/CD6F-EC8D
sed -i '/# smaps_ini/,/# smaps_fim/d' timer/ra_wrap.sh
sed -i 's#sh /sdcard/timer/ra_wrap.sh -y#/usr/bin/retroarch -y#' timer/hook.sh
sed -i '/amostra_ps1/d' timer/hook.sh
sync
```

## Ejecting safely

Check the name with `lsblk` (it has changed from `sda` to `sdb`):

```bash
cd ~
sync
udisksctl unmount -b /dev/sdb5
udisksctl power-off -b /dev/sdb
```

The `saves/` folder is the only irreplaceable thing on the card.
