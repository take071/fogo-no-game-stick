# Game stick history: wipe it with one button and manage it from a PC

> Versão em português: [README.pt-BR.md](README.pt-BR.md)

Notes from reverse-engineering a **Linux-based retro game stick** (closed-source menu at `/usr/bin/game`, MiniGUI-based, games run through RetroArch). The goal was to control the menu's **History** tab: delete games and limit its size.

**Result:** holding **Start for 3 s** on the History tab wipes the history and restarts the menu immediately. From a PC you can list it, delete one game, clear everything, or trim it to 15.

> ⚠️ Tested on **one** device. Button codes, paths and the way the menu is started may differ on yours. Everything here changes files on the SD card and the history **without confirmation and without backup**. Use at your own risk.

---

## 1. What we found

| Question | Answer |
|---|---|
| Where is the menu's history? | `game/database.sqlite3`, table `History(ID, GameID, STATUS)` |
| What are the numbers on screen (0026, 0010...)? | The `GameID`, not the game's position in its folder |
| Where are the names? | `game/games.db`, table `tbl_game` (only for the game IDs registered there) |
| What is the list order? | By `ID`, highest first (most recent on top) |
| What about a replayed game? | The menu already moves it to the top (it gets a new `ID`, the old row disappears). No script needed |
| The 88-byte `parameter` file? | Menu settings, not history |
| `retroarch/content_history.lpl`? | RetroArch's own file. The menu does **not** use it |
| Can a new button be added to the menu? | No. The menu is a closed binary on a read-only system |
| Does the device have `sqlite3`? | We found none. So the database is edited inside the device by overwriting it with a ready-made template |
| Does the menu re-read the database after it changes? | No. It keeps the list in memory. The fix was to restart the menu |

### How the history was located
1. A read-only diagnostic script, triggered by the hook the device already runs when a game opens, listed processes and the files each one has open.
2. The menu process held `database.sqlite3` and `games.db` open, both inside the `game/` folder, which had been wrongly excluded from earlier searches.
3. Opening a copy of the databases with Python's `sqlite3` revealed the `History` table.

---

## 2. How the solution works

```
[PC]  make_mold.py  ->  creates histtools/hist_vazio.sqlite3 (database copy with History emptied)
[PC]  hist.py       ->  show / trim / del / clear directly on the card

[Device] hook (single line) ──> sel_limpa.sh (stays in the background)
    listens to the buttons with evtest
    Start held 3 s  and  RetroArch is NOT running:
        1. copies the template over database.sqlite3 (same file, using cat >)
        2. kill -9 on the menu (so it cannot rewrite the old history)
        3. starts the menu again with the same environment as at boot
        4. logs to sel.log
```

Details that matter:
- **Why `cat >` and not `mv`/`cp`?** The menu keeps the file open. Replacing the file would leave the menu looking at the old one.
- **Why restart the menu?** Otherwise the empty history only shows up after a reboot.
- **Why `kill -9`?** A normal shutdown would let the menu write the old history back on exit.
- **Menu environment at boot** (read from `/proc/<pid>/environ` and the startup script): `HOME=/`, `XDG_CONFIG_HOME=/sdcard/`, `MG_CFG_PATH=/usr/local/share/minigui/hdmicfg`, `storagemedia=sd`, working directory `/mnt`.
- **8 s lock** so one press cannot restart twice.
- **Ignores the button during a game** (when `retroarch` is running).

---

## 3. Installation

Replace `USER` with your username and `MYCARD` with your card's name under `/run/media/USER/`.

### 3.1 On the PC (card mounted)

```bash
cd /run/media/USER/MYCARD
mkdir -p histtools
# copy scripts/sel_limpa.sh from this repository into histtools/
python3 scripts/make_mold.py       # creates histtools/hist_vazio.sqlite3 (card must be mounted)
```

With more than one card, say which: `SD=/run/media/USER/MYCARD python3 scripts/make_mold.py`

### 3.2 Find your button code

Code `28` (Start) and `54` (Select) are for the tested device. On yours, check:
- the device's RetroArch config: `input_player1_start_btn` and `input_player1_select_btn`;
- or run `evtest /dev/input/event0` on the device and press the button (look for `code NN`).

Then edit the `SEL=` line of `sel_limpa.sh`.

### 3.3 Hook the script into the device

Your device needs a **hook**: a script it runs when a game opens. On the tested device it is a `hook.sh` called by `start_game.sh`. If yours has none, this method won't work, and you need another way to start `sel_limpa.sh` (for example, from a boot script).

Add **one line near the top** of the hook, before any `exit`:

```sh
[ -f /sdcard/histtools/sel_limpa.sh ] && sh /sdcard/histtools/sel_limpa.sh </dev/null >/dev/null 2>&1 &
```

Check the syntax before saving: `sh -n hook.sh`. A broken hook can stop games from launching.

### 3.4 Test

1. Put the card in the device and **open any game** (this starts the script).
2. Go back to the menu, open the History tab and **hold Start for about 3 s**.
3. The screen flickers for a few seconds and the menu returns with an empty history.
4. On the PC, open `histtools/sel.log`. Expected:
   ```
   sel_limpa started
   history wiped
   menu restarted
   ```

### 3.5 Uninstall

```bash
(
S=/run/media/USER/MYCARD
sed -i '/sel_limpa/d' "$S/path/to/your/hook.sh"    # adjust
rm -rf "$S/histtools"; sync
echo "UNDONE"
)
```

---

## 4. Using it from the PC: `hist.py`

```bash
python3 scripts/hist.py show        # list (newest first)
python3 scripts/hist.py trim        # keep only the 15 most recent (one per game)
python3 scripts/hist.py trim 10     # same, with another limit
python3 scripts/hist.py del 55      # remove one game by GameID
python3 scripts/hist.py clear       # wipe everything
```

`show` only reads. The others **write to the card**: eject it safely before using it in the device. Names only appear for `GameID`s registered in `games.db`; the rest show as `(name not found)`.

---

## 5. What is still missing

- **Automatic 15-game limit on the device.** Today it exists only from the PC (`hist.py trim`). It would need a way to edit the database on the device without `sqlite3`: compile a small `sqlite3` for its CPU, or rewrite the `.sqlite3` file from a script, which is laborious.
- **Deleting a single game from the device.** There's no way to know which menu item is highlighted. Today the button wipes everything.
- **The button only works after a game has been opened since the device powered on**, because the hook is what starts the script. A boot hook would fix this but requires changing the read-only system.
- **Names for `GameID`s outside `games.db`.** We never found where the menu gets those names. It might be another database, or the menu may build them from the folder.
- **Check whether Start does something else on other menu screens.**
- **Testing on other devices and firmwares.**
- **A confirmation step before wiping** (for example, requiring a second button).

## 6. What we tried and abandoned

| Idea | Why we dropped it |
|---|---|
| Read `content_history.lpl` (RetroArch) | The menu doesn't use that file |
| Log every opened game into the history ourselves | The menu already does it, and also moves repeats to the top |
| Add a "delete" button inside the menu | Closed binary, read-only system |
| Use **Select** as the button | Holding Select opens the device's settings menu; Start worked |
| Delete only the highlighted row | The menu doesn't expose which item is selected |
| Wait for the menu to re-read the database | It doesn't. The fix was restarting the menu |
| Replace the file with `mv` or `cp` | The menu keeps the file open |
| Insert the hook line with `awk` | If the pattern doesn't match, the hook can be overwritten. We used `sed` with a line-count check and `sh -n` |

## 7. Pitfalls we hit

- Pasting a block containing `exit` into a terminal **closes the terminal**. Run blocks inside `( ... )`.
- On some distros `xxd` is not installed. Use `od -A d -t x1z file`.
- `head -40` truncated lists and hid the most important files. Be careful with line limits in diagnostics.
- Files written by the device carry a 1979 or 1980 date, which helps tell what it writes by itself.
- The names shown on screen may come from a time when the card held other games. The numbers (`GameID`) stay, while the files change.

## 8. Warnings

- Wiping the history **asks for no confirmation** and **cannot be undone** (we make no backup).
- The menu returns to its start screen after restarting.
- If the screen stays black for more than about 10 s after Start, power-cycle the device. The card is not affected.
- This is personal reverse engineering, unrelated to the manufacturer.

## 9. Files

```
scripts/
  hist.py        manage the history from a PC
  make_mold.py   create the empty template on the card
  sel_limpa.sh   runs on the device: hold Start to wipe and restart the menu
```

To read the script code, open the files above. They are the generic version of the tested ones (`histtools/` paths instead of the originals).
