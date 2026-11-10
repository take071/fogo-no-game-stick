# 06 – The "00 Timer": fixed alert, paused game and full screen

Here I record what I changed on the card (a Linux system running RetroArch) to:

1. Show the **"TEMPO ACABOU"** ("time's up") alert fixed for **15 s**, without flicker.
2. **Pause the game** while the alert shows and **resume** it on its own afterwards.
3. Let the player **dismiss the alert with any button**.
4. Make games run **full screen**.

Everything was done by editing scripts and configs on the card. **I did not modify the `gtimer` binary.**

> ⚠️ Tested on my device. On another device, RetroArch version or card, paths and behavior may differ. Back up first.

---

## 1. Conventions

Commands run **on the PC** with the card mounted. Define once in the terminal:

```bash
CARTAO=/path/to/card      # e.g. /run/media/YOUR_USER/CARD_NAME
T=$CARTAO/timer
[ -d "$T" ] || echo "WARNING: timer folder not found, check the path"
```

Inside the device the card appears as `/sdcard`, which is why the scripts use `/sdcard/timer/...`.

---

## 2. How the timer works

| File (`timer/`) | Purpose |
|---|---|
| `gtimer` | Compiled program (32-bit ARM). Draws the screens straight to the display and speaks the numbers |
| `hook.sh` | Called by the system when a game opens. If it's the "Timer", runs `gtimer` |
| `run.sh` | Waits for the time to end and fires the alert (`gtimer alarm`) and the sound. **This is the one I changed** |
| `ra_wrap.sh` | Wraps RetroArch for GBA games (diagnostics). Not changed |
| `v/acabou.wav` | Voice clip saying time is up |
| `gtimer.log` | Log from `gtimer` and `run.sh` |
| `aviso.txt` | Alert duration in seconds (created by `run.sh`) |

`gtimer` modes, from reading the binary (strings and disassembly) **[inferred]**:

| Argument | What it does |
|---|---|
| *(none)* | Normal screen to set the minutes |
| `alarm` | Draws the "TEMPO ACABOU" alert |
| `cal` | Button calibration (probably the test screens in photos [10](../fotos/10-teste-tela-controle-103.jpg) and [11](../fotos/11-teste-tela-controle-48.jpg)) |
| `test` | Test mode |

That's why `alarm` must **not** be removed from `run.sh`: without it, the minutes screen shows up instead of the alert.

Flow: I schedule the time in the "Timer" game ([photo 07](../fotos/07-timer-01-10.jpg)) → `gtimer` starts `run.sh` with the end time (seconds of uptime) → `run.sh` sleeps until then → **freezes RetroArch**, opens `gtimer alarm`, plays the sound and listens for buttons → the alert ends after 15 s or on a button press → the game resumes.

---

## 3. Why the alert flickered

`gtimer` draws into the video (DRM) buffer that is on screen **at the instant it starts** and re-copies its box every 30 ms. RetroArch alternates between two buffers, so the box only showed on frames where the chosen buffer was the displayed one. That was the flicker.

The old version froze the game 1 s **after** starting `gtimer`, which was too late. The fix was to freeze RetroArch **before** starting `gtimer`: the visible buffer stays still and the box stays steady. This is a deduction from the code and log, and **I confirmed it in practice**: after the change it stopped flickering.

> **About my earlier `kill -STOP` attempt:** I had noted it "made things worse" (game frozen ~25 s, no sound). The flaw was the order (freezing after `gtimer`) and no guaranteed `kill -CONT`. The new script's `trap` handles that.

The duration comes from `/sdcard/timer/aviso.txt` (integer 1–3599). Without the file, the default is 30 s.

---

## 4. The final `run.sh`

It's ready at [`scripts/timer/run.sh`](../../scripts/timer/run.sh) (the original is kept as `run_original.sh`). Settings at the top:

- `DUR=15`: seconds the alert stays on screen.
- `PAUSAR=1`: freeze the game before drawing. **With `0` the alert flickers again.**

To install on the card:

```bash
cp "$T/run.sh" "$T/run.sh.bak"           # keep yours first
cp scripts/timer/run.sh "$T/run.sh"
sed -i 's/\r//g' "$T/run.sh"
sync
```

### What each part does

- **Wait:** sleeps in blocks of up to 20 s until the end time.
- **`RP`:** gets RetroArch's PID. If it isn't running (I'm in the Timer itself), pausing is skipped.
- **`cleanup` + `trap`:** on **any** exit (normal, error, interrupt) the game is resumed (`kill -CONT`) and `gtimer`, sound and `evtest` are stopped. This prevents leaving the game frozen by accident.
- **`kill -STOP` before `gtimer`:** the flicker fix.
- **Buttons:** one `evtest` per input device. Any `EV_KEY value 1` kills `gtimer`. The `sleep 1` beforehand stops an already-held button from closing the alert instantly.
- **`alive`:** checks that `gtimer` is still running, ignoring zombies (without it the game could stay paused a few seconds longer).
- **Safety limit:** if `gtimer` doesn't finish, the script kills it after `DUR + 3` s.

### Checking after a test

```bash
tail -5 "$T/gtimer.log"
```

It should end with something like:

```
aviso: fim do tempo, fica 15 s
fim aviso
run.sh: fim aviso
```

If you see `retroarch pid=nenhum`, pausing didn't work and the flicker may return. (The log messages are in Portuguese because the original `gtimer` logs are; `nenhum` means "none".)

---

## 5. Full screen

Games (except GBA) use `gbx66.cfg` at the card root. GBA games use `timer/gbx_mod.cfg`, and there is also `timer/cfg_interno.cfg`. In all three, `aspect_ratio_index` was `18`. The device output is 1280x720 and index `1` is 16:9 in RetroArch.

```bash
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do
  sed -i 's/^\(aspect_ratio_index = \)"[0-9]*"/\1"1"/' "$f"
  grep '^aspect_ratio_index' "$f"
done
sync
```

Undo (back to `18`): run the same loop replacing `"1"` with `"18"`.

> **A doubt of mine:** I later found out the stick uses the **internal** `gbx66.cfg` (`/usr/local/share/minigui/gbx66.cfg`) for games that don't go through `gbx_mod.cfg` (see [doc 04](04-pokemon-fastforward.md)). So the change to the card's `gbx66.cfg` may have **no effect** outside GBA. For those consoles, full screen probably needs the same squashfs patch used for saves **[pending]**. 4:3 games (PS1, NES, SNES...) end up stretched horizontally at 16:9.

---

## 6. Why the Timer opened and closed instantly (and how I fixed it)

I thought it was missing swap. **It wasn't.** Two mistakes of mine:

1. **I overwrote `hook.sh`.** While installing a memory-diagnostic script I erased the timer's `hook.sh` and put in one that only ran the diagnostic and did `exit 1`. The system read that and closed the screen at once. The restored copy is at [`scripts/timer/hook_timer_restaurado.sh`](../../scripts/timer/hook_timer_restaurado.sh).
2. **Windows line endings (`\r`).** Scripts edited on Windows get `\r`, which the stick's lean Linux doesn't understand, and the script silently aborts. Fix: `sed -i 's/\r//g' timer/hook.sh && chmod +x timer/hook.sh`.

(The stick has 0 KB of swap and drops to ~6 MB `MemFree` in heavy games, but that's a separate matter; see [doc 05](05-diagnosis-black-screen-ram.md).)

This timer `hook.sh` decides: if the game name contains "Timer", run `gtimer`; otherwise `exit 1` and let the flow open the game normally. **It is the timer-only version;** the version that also opens GBA games through `ra_wrap.sh` still has to be merged **[pending]**.

> **A doubt of mine:** the old write-up said to edit the card root's `/start_game.sh` with `sh hook.sh ... || retroarch ...`. Since the stick uses the internal `start_game.sh` (which already calls the hook), I **don't consider that step confirmed**. Only use it if your device really reads the root one.

---

## 7. Timer in arcade: tried and dropped

The Timer works on consoles where a fake file in the folder is enough (NES, GBA, etc.). In arcade the menu only shows what is in `tbl_game` of `games.db` (36 games, `gameid` 1–36).

- **Attempt 1:** row with `gameid` 900 + a fake `00 Timer.zip` in the arcade folder. The menu hung. I changed two things at once, so I don't know which caused it.
- **Attempt 2:** database only, `gameid` 37, row copied from `kof97` and names in `tbl_zh/en/tw/ko`. The menu hung again on the loading screen. An empty `00 Timer.fs` was still in the folder (unlikely to crash the menu, but not proof).
- **Decision:** I gave up. I restored `games.db` from the `.bak` (`cp "$DB.bak" "$DB"`), deleted the empty `.fs` and checked: 36 games, 0 timer rows. `games.db.bak` stays on the card.
- **Unconfirmed guess:** the menu uses `gameid` as a position in a fixed list. I also don't know what the factory `.fs` files (`kof97.fs`, `mslug.fs`) are.

**How I use the timer with arcade:** I open "00 Timer" from the NES/GBA list, pick the time, go back and open an arcade game (`mslug` or `kof97`). The alert should show on top, since it's drawn on screen. **I only tested it over GBA** (photos [08](../fotos/08-tempo-acabou-azul.jpg) and [12](../fotos/12-tempo-acabou-arroxeado.jpg)) **[pending]**.

---

## 8. Backup and restore

```bash
cp "$T/run.sh" "$T/run.sh.bak"
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do cp "$f" "$f.bak"; done
# restore:
cp "$T/run.sh.bak" "$T/run.sh"
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do cp "$f.bak" "$f"; done
sync
```

---

## 9. Read-only commands

```bash
find "$CARTAO" -type f \( -iname '*timer*' -o -iname '*.sh' \) 2>/dev/null | head -40
strings -n 4 "$T/gtimer" | grep -i -E "alarm|normal|cal|test|aviso|fica"
grep -E '^(aspect_ratio_index|video_scale_integer|video_force_aspect|custom_viewport|video_fullscreen)' "$CARTAO/gbx66.cfg"
tail -40 "$T/gtimer.log"
```

---

## 10. Known issues

- **Audio pop** when the game resumes from the pause.
- **A button pressed during the pause** may reach the game on resume.
- **`killall aplay`** in `cleanup` also stops any other `aplay` running.
- **`sleep 0.3`** may not be accepted on every device; the script falls back to 1 s.
- **4:3 games stretched** at 16:9.
- If some system still shows black bars, there may be a per-core or per-game setting inside the device (outside the card).
- If the alert flickers again, check in the log that `run.sh: retroarch pid=...` has a number (not `nenhum`).

## 11. Summary of changes

| Item | File | Change |
|---|---|---|
| 15 s alert | `timer/run.sh` + `timer/aviso.txt` | `DUR=15`, written to `aviso.txt` |
| Game pauses during alert | `timer/run.sh` | `kill -STOP` on RetroArch and `kill -CONT` at the end |
| No flicker | `timer/run.sh` | Freezes **before** starting `gtimer` |
| Button dismisses alert | `timer/run.sh` | `evtest` kept; the sound stops too |
| Guaranteed resume | `timer/run.sh` | `trap` with `cleanup` |
| Full screen | `gbx66.cfg`, `timer/gbx_mod.cfg`, `timer/cfg_interno.cfg` | `aspect_ratio_index` from `18` to `1` |
