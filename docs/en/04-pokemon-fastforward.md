# 04 – Faster Pokémon battles

## Result

**It works.** Battles are faster and the rest of the game (map, menus, text outside battle) keeps normal speed.

- `fastforward_ratio` in use: **3.0**.
- **2.5 I also tested and it felt "perfect"**: it's my reference value if I want something more moderate.
- Where to change it: `timer/gbx_mod.cfg`, line `fastforward_ratio`.

## How the stick works (what I found)

- Mount point on the PC: `/run/media/take/CD6F-EC8D`.
- GBA games run on mGBA (slot 7).
- For these games the stick does **not** use the `gbx66.cfg` or `start_game.sh` from the card root. It uses the internal ones in `/usr/local/share/minigui/`. The real command line, captured during the RAM diagnosis, confirms it:

  ```
  /usr/bin/retroarch -y 12 -c /usr/local/share/minigui/gbx66.cfg -L /sdcard/retro_lib/mgba_libretro.so /sdcard/game/gba/Stone Dragon 3.gba
  ```

  So the edits I first made to the card's `gbx66.cfg` had no effect.
- The internal `start_game.sh` calls `/sdcard/timer/hook.sh` before opening RetroArch. **`hook.sh` is my entry point.**
- The "Timer" game (`00 Timer`, `zz Timer calibrar`) is a fake game that works as a stopwatch (`gtimer`). `hook.sh` handles it separately.
- Controller: ShanWan Twin USB Joystick, which sends **keyboard keys** (Start = `KEY_ENTER`, Select = `KEY_RIGHTSHIFT`, A = `KEY_A`, B = `KEY_B`, Y = `KEY_Y`).

## The games

| Game | Base | Note |
|---|---|---|
| PK GS Chronicles 2.7.4 | FireRed (`BPRE`) | has battles |
| Stone Dragon 3 | FireRed (`BPRE`) | has battles |
| Pokémon Mystery Dungeon | — | no turn-based battles |

## How the solution works

1. `hook.sh` identifies slot 7 (GBA) games that aren't "Timer".
2. For them it opens RetroArch with `-c /sdcard/timer/gbx_mod.cfg` (a copy of the internal config with a changed `fastforward_ratio`), through `ra_wrap.sh`.
3. Errors go to `timer/ra.err` and the exit code to `hook.log`.

I thought the setting would speed up the whole game and **I was wrong**: it only shows in battles. **I can't explain why**; it works, but I haven't investigated the cause.

## What I gave up on

| Idea | Why |
|---|---|
| Tweak the root `gbx66.cfg` | The stick uses the internal one |
| `tools_diag.sh` from the card's `start_game.sh` | That file never runs |
| Fast-forward button | L already has a function, Start didn't speed anything up, `_btn` codes don't fit this pad |
| Auto fast-forward by timer | I refused it |
| Acceleration by reading game memory | Would need a custom RetroArch and one address per hack |
| More "performance" | GBA is locked at 60 fps by the emulator |
| `fps_show` | This build doesn't draw it |

## Changing the speed

```bash
S=$(ls -d /run/media/take/CD6F* | head -1)
sed -i 's/^fastforward_ratio = .*/fastforward_ratio = "2.500000"/' "$S/timer/gbx_mod.cfg"
grep -n '^fastforward_ratio' "$S/timer/gbx_mod.cfg"
sync
```

## Cleanup still to do

- `tools_diag.sh` and the `sh /sdcard/tools_diag.sh` line in the card's `start_game.sh` (`cp start_game.sh.bak_diag start_game.sh`).
- `timer/diag2.sh`, `timer/ff.cfg`, `timer/snippet*.txt`, `timer/ev.event*`, `timer/ra.err`.
- Check `hook.sh` with `sed -n 4,6p timer/hook.sh`: the `evtest` line and the `-v` should be gone.
- In-game options that cut even more time: Text Speed: Fast, Battle Scene: Off, Battle Style: Set.

## Undo everything

```bash
S=$(ls -d /run/media/take/CD6F* | head -1)
cp "$S/timer/hook.sh.bak_diag2" "$S/timer/hook.sh"
cp "$S/start_game.sh.bak_diag" "$S/start_game.sh"
sync
```
