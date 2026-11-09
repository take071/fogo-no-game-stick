# Console timer: fixed "TEMPO ACABOU" alert for 15 s + full-screen games

This document records what was changed on the console's SD card (a Linux-based system running RetroArch) to:

1. Show the **"TEMPO ACABOU"** ("time's up") alert fixed on screen for **15 seconds**, without flickering.
2. **Pause the game** while the alert is shown and **resume** it automatically afterwards.
3. Let the player **dismiss the alert with any controller button**.
4. Make games run **full screen**.

Everything was done by editing scripts and configuration files on the card. The `gtimer` binary was **not modified**.

> **Warning:** these changes were made and tested on the author's device. On another device, RetroArch version or card, paths and behavior may differ. Back up before applying anything.

---

## 1. Conventions used in this document

Commands run **on the PC**, with the card mounted. Define this once in your terminal:

```bash
CARTAO=/path/to/card      # card mount point (e.g. /run/media/YOUR_USER/CARD_NAME)
T=$CARTAO/timer
[ -d "$T" ] || echo "WARNING: timer folder not found, check the card path"
```

Inside the device, the card appears as `/sdcard`. That is why the scripts use `/sdcard/timer/...`.

---

## 2. How the system works

### Layout (`timer/` folder)

| File | Purpose |
|---|---|
| `gtimer` | Compiled program (32-bit ARM). Draws the timer screens directly on the display and speaks the numbers. |
| `hook.sh` | Called by the system when a game is opened. If the game is the "Timer", it runs `gtimer` in normal mode. |
| `run.sh` | Waits for the timer to end and triggers the alert (`gtimer alarm`) and the sound. **This is the file that was changed.** |
| `ra_wrap.sh` | Wraps RetroArch on some systems (diagnostic collection). Not changed. |
| `v/acabou.wav` | Voice clip saying that time is up. |
| `gtimer.log` | Log from `gtimer` and `run.sh`. Useful for debugging. |
| `aviso.txt` | Alert duration in seconds. Created by `run.sh`. |

At the card root, `start_game.sh` picks the RetroArch core per system, and `gbx66.cfg` holds the video settings for games.

### Alert flow

1. You schedule the timer in the "Timer" game. `gtimer` starts `run.sh`, passing the end time (in seconds of system uptime).
2. `run.sh` sleeps until that time.
3. At the end, it **freezes RetroArch**, opens `gtimer alarm`, plays the sound and listens for button presses.
4. The alert ends when 15 s pass **or** a button is pressed. Then the game is resumed.

### `gtimer` modes

From reading the binary (strings and disassembly), `gtimer` accepts these arguments:

| Argument | What it does |
|---|---|
| *(none)* | Normal screen for setting the minutes. |
| `alarm` | Draws the "TEMPO ACABOU" alert. |
| `cal` | Button calibration. |
| `test` | Test mode. |

This is why `alarm` must **not** be removed from `run.sh`: without it, the minutes screen appears instead of the alert.

---

## 3. Why the alert was flickering

`gtimer` draws into the video (DRM) buffer that is on screen **at the moment it starts**, and re-copies its box every 30 ms. RetroArch alternates between two buffers. The box was only visible on frames where the buffer `gtimer` had picked was the one being displayed, and that was the flicker.

The earlier version froze the game 1 s **after** starting `gtimer`, which was too late. The fix was to freeze RetroArch **before** starting `gtimer`. That way the visible buffer stays still and the box appears steady.

> This is an inference from the code and the log, and it was confirmed in practice: after the change, the alert stopped flickering.

The alert duration comes from `/sdcard/timer/aviso.txt`: a whole number of seconds from 1 to 3599. Without the file, the default is 30 s.

---

## 4. The final `run.sh`

This replaces the `run.sh` on the card. Settings at the top:

- `DUR=15`: seconds the alert stays on screen.
- `PAUSAR=1`: freeze the game before drawing. **With `0` the alert flickers again.**

```bash
cat > "$T/run.sh" <<'EOF'
#!/bin/sh
END=$1
DUR=15      # seconds the alert stays on screen
PAUSAR=1    # 1 = freeze the game before drawing the alert (prevents flicker)
LOG=/sdcard/timer/gtimer.log
echo $$ > /tmp/gtimer.pid
while :; do
  read UP _ < /proc/uptime; UP=${UP%.*}
  LEFT=$((END - UP))
  [ "$LEFT" -le 0 ] && break
  [ "$LEFT" -gt 20 ] && sleep 20 || sleep "$LEFT"
done
rm -f /tmp/gtimer.pid
[ -x /tmp/gtimer ] || { cp /sdcard/timer/gtimer /tmp/gtimer; chmod +x /tmp/gtimer; }

RP=$(pidof retroarch | awk '{print $1}')
GP=; AP=
cleanup() {
  [ -n "$RP" ] && kill -CONT $RP 2>/dev/null
  [ -n "$GP" ] && kill $GP 2>/dev/null
  [ -n "$AP" ] && kill $AP 2>/dev/null
  killall aplay 2>/dev/null
  killall evtest 2>/dev/null
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

# 1) freeze the game BEFORE starting gtimer
if [ "$PAUSAR" = 1 ] && [ -n "$RP" ]; then
  kill -STOP $RP 2>/dev/null
  sleep 0.3 2>/dev/null || sleep 1
fi
echo "run.sh: retroarch pid=${RP:-nenhum} pausar=$PAUSAR dur=$DUR" >> $LOG

# 2) alert duration (gtimer reads this file)
echo "$DUR" > /sdcard/timer/aviso.txt

/tmp/gtimer alarm >/dev/null 2>&1 &
GP=$!
( aplay -q /sdcard/timer/v/acabou.wav; sleep 4; aplay -q /sdcard/timer/v/acabou.wav ) &
AP=$!
read T0 _ < /proc/uptime; T0=${T0%.*}
sleep 1
for d in /dev/input/event*; do
  ( evtest $d 2>/dev/null | while read l; do
      case "$l" in *"type 1 (EV_KEY)"*"value 1"*) kill $GP 2>/dev/null; break ;; esac
    done ) &
done

alive() { ST=$(cut -d' ' -f3 /proc/$GP/stat 2>/dev/null); [ -n "$ST" ] && [ "$ST" != Z ] && [ "$ST" != X ]; }
while alive; do
  read T1 _ < /proc/uptime; T1=${T1%.*}
  [ $((T1 - T0)) -ge $((DUR + 3)) ] && break
  sleep 0.5 2>/dev/null || sleep 1
done
echo "run.sh: fim aviso" >> $LOG
exit 0
EOF
sync
```

Note: the log messages (`retroarch pid=`, `nenhum`, `fim aviso`) are in Portuguese because the original `gtimer` logs are in Portuguese. `nenhum` means "none".

### What each part does

- **Wait:** the first loop sleeps in blocks of up to 20 s until the end time.
- **`RP`:** gets the RetroArch PID. If RetroArch is not running (you are in the Timer itself), pausing is skipped.
- **`cleanup` + `trap`:** on **any** exit (normal end, error, interruption) the game is resumed (`kill -CONT`), and `gtimer`, the sound and `evtest` are stopped. This prevents the game from being left frozen by accident.
- **`kill -STOP` before `gtimer`:** this is the flicker fix.
- **Buttons:** one `evtest` per input device. When any button press is detected (`EV_KEY value 1`), it stops `gtimer`. The `sleep 1` beforehand prevents a button that is already held down from closing the alert immediately.
- **`alive`:** checks whether `gtimer` is still running, ignoring zombie processes. Without it, the game could stay paused a few seconds longer.
- **Safety limit:** if `gtimer` does not finish, the script kills it after `DUR + 3` seconds.

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

If you see `retroarch pid=nenhum`, pausing did not work, and the flicker may return.

---

## 5. Full screen

Games (except GBA) use `gbx66.cfg` at the card root. GBA games use `timer/gbx_mod.cfg`, and there is also `timer/cfg_interno.cfg`. In all three, `aspect_ratio_index` was `18`. The device output is 1280x720, and index `1` is 16:9 in RetroArch.

### Apply

```bash
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do
  sed -i 's/^\(aspect_ratio_index = \)"[0-9]*"/\1"1"/' "$f"
  grep '^aspect_ratio_index' "$f"
done
sync
```

The `grep` should show `aspect_ratio_index = "1"` in all three files.

### Undo (back to the original value, 18)

```bash
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do
  sed -i 's/^\(aspect_ratio_index = \)"[0-9]*"/\1"18"/' "$f"
done
sync
```

> **Note:** 4:3 games (PS1, NES, SNES, etc.) end up stretched horizontally, because 16:9 fills the whole screen.

---

## 6. Backup and restore

Before changing anything, it is best to copy the files:

```bash
cp "$T/run.sh" "$T/run.sh.bak"
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do cp "$f" "$f.bak"; done
```

To restore:

```bash
cp "$T/run.sh.bak" "$T/run.sh"
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do cp "$f.bak" "$f"; done
sync
```

### Original `run.sh` (the version before the changes)

```bash
cat > "$T/run.sh" <<'EOF'
#!/bin/sh
END=$1
echo $$ > /tmp/gtimer.pid
while :; do
  read UP _ < /proc/uptime; UP=${UP%.*}
  LEFT=$((END - UP))
  [ "$LEFT" -le 0 ] && break
  [ "$LEFT" -gt 20 ] && sleep 20 || sleep "$LEFT"
done
rm -f /tmp/gtimer.pid
[ -x /tmp/gtimer ] || { cp /sdcard/timer/gtimer /tmp/gtimer; chmod +x /tmp/gtimer; }
/tmp/gtimer alarm >/dev/null 2>&1 &
GP=$!
sleep 1
for d in /dev/input/event*; do
  ( evtest $d 2>/dev/null | while read l; do
      case "$l" in *"type 1 (EV_KEY)"*"value 1"*) kill $GP 2>/dev/null; break ;; esac
    done ) &
done
aplay -q /sdcard/timer/v/acabou.wav
sleep 4
aplay -q /sdcard/timer/v/acabou.wav
sleep 26
killall evtest 2>/dev/null
EOF
rm -f "$T/aviso.txt"
sync
```

---

## 7. Diagnostic commands (read-only)

Find the timer files:

```bash
find "$CARTAO" -type f \( -iname '*timer*' -o -iname '*.sh' \) 2>/dev/null | head -40
```

See the `gtimer` modes and texts:

```bash
strings -n 4 "$T/gtimer" | grep -i -E "alarm|normal|cal|test|aviso|fica"
```

See the video settings:

```bash
grep -E '^(aspect_ratio_index|video_scale_integer|video_force_aspect|custom_viewport|video_fullscreen)' "$CARTAO/gbx66.cfg"
```

See the end of the log:

```bash
tail -40 "$T/gtimer.log"
```

---

## 8. Known issues

- **Audio pop** when the game resumes after the pause.
- **A button pressed during the pause** may reach the game when it resumes.
- **`killall aplay`** in `cleanup` also stops any other `aplay` running at that moment.
- **`sleep 0.3`** may not be accepted on every device; the script falls back to 1 s.
- **4:3 games stretched** in full screen at 16:9.
- If some system still shows black bars, there may be a per-core or per-game setting stored inside the device (outside the card).
- If the alert starts flickering again, check in the log whether the `run.sh: retroarch pid=...` line shows a number (and not `nenhum`).

---

## 9. Summary of changes

| Item | File | Change |
|---|---|---|
| 15 s alert | `timer/run.sh` + `timer/aviso.txt` | `DUR=15`, written to `aviso.txt` |
| Game pauses during the alert | `timer/run.sh` | `kill -STOP` on RetroArch and `kill -CONT` at the end |
| No flicker | `timer/run.sh` | Freezes the game **before** starting `gtimer` |
| Button dismisses the alert | `timer/run.sh` | `evtest` kept; the sound now stops too |
| Guaranteed resume | `timer/run.sh` | `trap` with `cleanup` |
| Full screen | `gbx66.cfg`, `timer/gbx_mod.cfg`, `timer/cfg_interno.cfg` | `aspect_ratio_index` from `18` to `1` |
