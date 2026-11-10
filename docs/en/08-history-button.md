# 08 – Menu history: wipe it with one button and manage it from a PC

I reverse-engineered the stick's menu (`/usr/bin/game`, closed-source, MiniGUI-based) to control the **History** tab: delete games and limit its size.

**Result:** holding **Start for 3 s** on the History tab (photo [17](../fotos/17-aba-historico.jpg)) wipes the history and restarts the menu right away. From a PC I can list it, delete one game, clear everything or trim it to 15.

> ⚠️ Tested on **one** device. Button codes, paths and how the menu starts may differ on yours. Everything here changes files **without confirmation and without backup**.
>
> **State of the scripts:** `hist.py`, `make_mold.py` and `sel_limpa.sh` are **not in this repo yet**; I'll add them. This page documents what I found and how it works.

## 1. What I found

| Question | Answer |
|---|---|
| Where is the history? | `game/database.sqlite3`, table `History(ID, GameID, STATUS)` |
| What are the on-screen numbers (0026, 0010...)? | The `GameID`, not the game's position in its folder |
| Where are the names? | `game/games.db`, table `tbl_game` (only for IDs registered there) |
| List order? | By `ID`, highest first |
| Replayed game? | The menu already moves it to the top (new `ID`, old row disappears) |
| The 88-byte `parameter` file? | Menu settings, not history |
| `retroarch/content_history.lpl`? | RetroArch's own; the menu does **not** use it |
| Can I add a new button to the menu? | No: closed binary on a read-only system |
| Does the device have `sqlite3`? | I found none. So I replace the whole database with a template |
| Does the menu re-read the database? | No, it keeps the list in memory. The fix was restarting the menu |

How I found it: a read-only diagnostic script, fired by the hook the device already runs when a game opens, listed processes and open files. The menu held `database.sqlite3` and `games.db` open, inside `game/`, a folder I had wrongly excluded from my searches.

## 2. How the solution works

```
[PC]  make_mold.py -> creates histtools/hist_vazio.sqlite3 (database with History emptied)
[PC]  hist.py      -> show / trim / del / clear straight on the card

[Device] hook (one line) -> sel_limpa.sh (stays in the background, listens with evtest)
    Start held 3 s and RetroArch NOT running:
        1. copies the template over database.sqlite3 (same file, using cat >)
        2. kill -9 on the menu (so it can't rewrite the old history)
        3. starts the menu again with the boot environment
        4. logs to sel.log
```

- **`cat >` and not `mv`/`cp`:** the menu keeps the file open; replacing it would leave the menu looking at the old one.
- **Restarting the menu:** otherwise the empty history only shows after a reboot.
- **`kill -9`:** a normal shutdown would let the menu write the old history back.
- **Menu environment at boot** (from `/proc/<pid>/environ`): `HOME=/`, `XDG_CONFIG_HOME=/sdcard/`, `MG_CFG_PATH=/usr/local/share/minigui/hdmicfg`, `storagemedia=sd`, working dir `/mnt`.
- **8 s lock** so one press can't restart twice; **ignores the button during a game**.

## 3. Installation (summary)

Replace `USER` and `MYCARD`. Full details will come with the scripts.

1. On the PC, copy `sel_limpa.sh` into `histtools/` on the card and run `python3 scripts/make_mold.py` (card mounted; with more than one, `SD=/run/media/USER/MYCARD`).
2. **Button code:** `28` (Start) and `54` (Select) are for my device. On yours, check `input_player1_start_btn` in RetroArch's cfg or run `evtest /dev/input/event0` and press the button; then edit the `SEL=` line.
3. **Hook:** your device needs a script it runs when a game opens (on mine, `hook.sh`). Add **one line near the top**, before any `exit`:

   ```sh
   [ -f /sdcard/histtools/sel_limpa.sh ] && sh /sdcard/histtools/sel_limpa.sh </dev/null >/dev/null 2>&1 &
   ```

   Before saving: `sh -n hook.sh`. A broken hook can stop games from launching (and remember the rule: keep the original `hook.sh`).
4. **Test:** open any game (that's what starts the script), go back, open the History tab and hold Start ~3 s. Expected in `histtools/sel.log`: `sel_limpa started`, `history wiped`, `menu restarted`.
5. **Uninstall:** `sed -i '/sel_limpa/d' <your hook.sh>`, `rm -rf histtools`, `sync`.

## 4. From the PC: `hist.py`

```bash
python3 scripts/hist.py show        # list (newest first)
python3 scripts/hist.py trim        # keep the 15 most recent (one per game)
python3 scripts/hist.py trim 10
python3 scripts/hist.py del 55      # remove one game by GameID
python3 scripts/hist.py clear       # wipe everything
```

`show` only reads; the others **write to the card** (eject safely before using it in the device). Names only appear for `GameID`s in `games.db`; the rest show as `(name not found)`.

## 5. What's still missing

- **Automatic 15-game limit on the device** (today only from the PC): would need a `sqlite3` compiled for its CPU, or rewriting the `.sqlite3` by script.
- **Deleting a single game from the device:** the menu doesn't expose the highlighted item.
- **The button only works after a game has been opened since power-on** (the hook starts the script). A boot hook would fix it, but the system is read-only.
- **Names for `GameID`s outside `games.db`:** I never found where the menu gets them.
- **Check if Start does something else on other screens**, and test on other devices.
- **A confirmation step before wiping** (e.g. a second button).

## 6. What I tried and dropped

| Idea | Why |
|---|---|
| Read `content_history.lpl` | The menu doesn't use it |
| Log every opened game myself | The menu already does, and moves repeats to the top |
| A "delete" button inside the menu | Closed binary, read-only system |
| **Select** as the button | Holding Select opens the device settings (photo [18](../fotos/18-menu-configuracoes.jpg)) |
| Delete only the highlighted row | The menu doesn't expose the selected item |
| Wait for the menu to re-read the database | It doesn't |
| Replace the file with `mv` or `cp` | The menu keeps the file open |
| Insert the hook line with `awk` | If the pattern misses, the hook can be overwritten. I used `sed` with a line-count check and `sh -n` |

## 7. Pitfalls and warnings

- Pasting a block with `exit` into a terminal **closes the terminal**: run blocks inside `( ... )`.
- No `xxd`: use `od -A d -t x1z file`. Careful with `head -40` in diagnostics: it once hid important files.
- Files written by the device are dated 1979/1980, which helps tell what it writes by itself.
- On-screen names may date from when the card held other games; `GameID`s stay and files change.
- Wiping the history **asks for no confirmation** and **can't be undone**. The menu returns to its start screen after restarting.
- If the screen stays black for more than ~10 s after Start, I power-cycle the device (the card isn't affected).
- This is personal reverse engineering, unrelated to the manufacturer.
