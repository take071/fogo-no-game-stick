# 04 · Faster Pokémon battles

[← previous](03-graphics-and-consumption.md) · [← back](../../README.md) · [next: diagnosis →](05-diagnosis-black-screen-ram.md)

## Result

**It worked.** Here "battles" means the turn-based **Pokémon battles** of the GBA hacks. They are faster; the map, menus and out-of-battle text stay at normal speed and smooth.

- `fastforward_ratio` in use: **3.0**. **2.5 was also tested and felt "perfect"**: it is the reference value if you want something more moderate.
- Where to change it: `timer/gbx_mod.cfg`, or `scripts/config/set_fastforward.sh 2.5`.

## How the stick works (discovered)

- Mount point on the PC: `/run/media/user/<LABEL>`. Emulator **RetroArch**; GBA runs on the **mGBA** core (slot 7).
- **The stick does NOT use the card's `gbx66.cfg` or `start_game.sh`.** It uses the internal ones in `/usr/local/share/minigui/`. All early `gbx66.cfg` tweaks on the card had no effect.
- The internal `start_game.sh` calls `/sdcard/timer/hook.sh` (on the card) before launching RetroArch. **`hook.sh` is our entry point.**
- "00 Timer" and "zz Timer calibrar" are fake games handled separately by `hook.sh` (ch. 06).
- Controller: **ShanWan Twin USB Joystick**, which sends **keyboard keys** (Start = `KEY_ENTER`, Select = `KEY_RIGHTSHIFT`, A = `KEY_A`, B = `KEY_B`, Y = `KEY_Y`).

## Pokémon games (`game/gba/`)

| Game | Base | Note |
|---|---|---|
| PK GS Chronicles 2.7.4 | FireRed (`BPRE`) | has battles |
| Stone Dragon 3 | FireRed (`BPRE`) | has battles |
| Pokémon Mystery Dungeon | n/a | no turn-based battles |

## How it works

1. `hook.sh` detects slot-7 (GBA) games that are not "Timer".
2. It launches RetroArch (through `ra_wrap.sh`) with `-c /sdcard/timer/gbx_mod.cfg`, a copy of the internal config with `fastforward_ratio` changed.
3. Errors go to `timer/ra.err`; the exit code goes to `hook.log`.

`gbx_mod.cfg` and `ra_wrap.sh` **will be added to the repo later**.

## What we learned

- The initial hypothesis was that the setting would speed up the whole game. **It was wrong**: the effect only shows in battles. **We cannot explain why**; it works, but the cause was not investigated.
- GBA is locked at 60 fps by the emulator and animations last a fixed number of frames; a faster stick would not speed anything up.

## Abandoned

| Idea | Reason |
|---|---|
| Root `gbx66.cfg` on the card | The stick uses the internal one |
| `tools_diag.sh` called from the card's `start_game.sh` | That `start_game.sh` never runs |
| Fast-forward button (L, Start/Enter, `_btn` codes) | L has a battle function; Start did not speed anything; `_btn` codes do not fit a pad that sends keys |
| Fast-forward on by timer (`FAST_FORWARD` via stdin) | Refused, never applied |
| Automatic acceleration by reading game memory | Would need a RetroArch build with memory reading and the battle-flag address per hack |
| More "performance" | GBA is capped at 60 fps |
| On-screen FPS counter (`fps_show`) | This build does not draw it; perceived speed was what counted |

## In-game options (emulator independent)

Text Speed: Fast · Battle Scene: Off · Battle Style: Set.

## Files and backups on the card

| File | Purpose |
|---|---|
| `timer/hook.sh` | entry point; launches RetroArch with `gbx_mod.cfg` |
| `timer/hook.sh.bak_diag2` | original `hook.sh`, before the RetroArch block |
| `timer/hook.sh.bak_ev` / `bak_dbg` / `bak_auto` | intermediate versions |
| `timer/gbx_mod.cfg` | config used by GBA games (tune speed here) |
| `timer/gbx_mod.cfg.bak_20` | config with speed 2.0 |
| `timer/cfg_interno.cfg` | copy of the original internal config (`fastforward_ratio = 0.0`) |
| `gbx66.cfg.bak_ff`, `start_game.sh.bak_diag` | backups of ineffective root tweaks |

## Undo everything

```bash
S=/run/media/user/<LABEL>
cp "$S/timer/hook.sh.bak_diag2" "$S/timer/hook.sh"   # original hook, no modified RetroArch
cp "$S/start_game.sh.bak_diag" "$S/start_game.sh"    # removes the tools_diag.sh line
sync
```

## Optional cleanup (pending)

1. Remove `tools_diag.sh` and the `sh /sdcard/tools_diag.sh` line from the card's `start_game.sh`; `timer/diag2.sh`, `timer/ff.cfg`, `timer/snippet*.txt`, `timer/ev.event*`, `timer/ra.err`.
2. Confirm `hook.sh` is clean: `sed -n 4,6p timer/hook.sh` (the `evtest` line and `-v` must be gone; the `-c /sdcard/timer/gbx_mod.cfg` line must remain).
3. `input_hold_fast_forward = "enter"` in `gbx_mod.cfg` does nothing useful; keep it or set it back to `"l"`.
4. Restrict the tweak to Pokémon only (today it applies to all of slot 7 except Timer). Nobody reported a problem.
