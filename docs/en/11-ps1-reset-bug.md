# 11 – Bug: "Restart game" closes PS1 games

## Status

**Problem not solved.** The fix is left for a future project. For now, use the workaround described below.

## Summary

In PS1 games, choosing **Restart game** in the RetroArch menu does not restart the game. Instead, RetroArch closes and the device goes back to the PS1 game selection screen.

## What works normally

- Opening and playing PS1 games.
- **Save state**.
- **Load state**.
- The other RetroArch menu functions.
- **Restart game** on GBA games (`mgba` core): it restarts normally.

The problem only shows up on the reset of PS1 games.

## Environment

| Item | Value |
|---|---|
| RetroArch | 1.7.4 (built on 22/12/2021, GCC 6.5.0, 32-bit) |
| PS1 core | `pcsx_rearmed_libretro.so` (slot 9 of `start_game.sh`) |
| GBA core (reference) | `mgba_libretro.so` (slot 7) |
| Memory | 246 MB of RAM, no swap |
| PS1 game format | `.PBP` (the only PS1 format that runs on the Game Stick) |

## How to reproduce

1. Open a PS1 game from the game list.
2. Open the RetroArch menu.
3. Choose **Restart game**.
4. RetroArch closes and returns to the PS1 game list.

## Workaround (it works)

- Save a state at the start of the game and use **Load state** whenever you want to start over. It does not reset the core.
- Or use **Close content** and open the game again from the list.

## Cause

**Not confirmed yet.** What is known:

- GBA and PS1 are started by the same command. Only the core changes, so the difference comes from `pcsx_rearmed` or from how much memory it uses.
- No log records how RetroArch ends (no exit code is saved). `ra_wrap.sh` and `amostra_ps1.sh` exist in the `timer` folder, but are not called today.
- The current `hook.sh` does not interfere: for any game it exits with `exit 1`, and the script falls straight through to the RetroArch command.

Open hypotheses:

1. The `pcsx_rearmed` core crashes when it receives the reset (the games are `.PBP`, the only PS1 format that runs on the device, so there is nothing else to compare with).
2. Out of memory during the reset, because of the 246 MB of RAM and no swap.

## How to find the cause

Record RetroArch's exit code in `timer/hook.log` after it runs (for example, in `start_game_interno.sh`):

- `rc=0`: normal exit.
- `rc=139`: crash (segfault) in the core.
- `rc=137`: process killed, usually for lack of memory.

Tests that change nothing:

- Test the reset on several PS1 games and note which ones close.

## Notes

- The script the device really runs is in internal memory (`/usr/local/share/minigui/start_game.sh`). The copy on the card at `timer/start_game_interno.sh` is a reference.
- RetroArch uses the internal config (`/usr/local/share/minigui/gbx66.cfg`), not the `gbx66.cfg` at the card root.
