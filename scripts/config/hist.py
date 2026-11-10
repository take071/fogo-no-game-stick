#!/usr/bin/env python3
"""Manage the game stick history from a PC, directly on the SD card.

Usage:
  python3 hist.py show          list history (newest first)
  python3 hist.py trim [N]      keep only the N most recent (default 15), one per game
  python3 hist.py del GAMEID    remove one game from the history
  python3 hist.py clear         remove everything

The SD card path is detected automatically (/run/media/$USER/*).
If you have more than one card, set it by hand:  SD=/run/media/$USER/MYCARD python3 hist.py show
Commands other than "show" WRITE to the card. Eject it safely before putting it in the device.
"""
import glob, os, sqlite3, sys

LIMIT = 15
SD = os.environ.get("SD")
if not SD:
    user = os.environ.get("USER", "")
    found = glob.glob("/run/media/%s/*/game/database.sqlite3" % user)
    if not found:
        sys.exit("SD card not found. Mount it or set SD=/path/to/card")
    SD = found[0].rsplit("/game/", 1)[0]

c = sqlite3.connect(SD + "/game/database.sqlite3")
try:
    names = dict(sqlite3.connect("file:%s/game/games.db?mode=ro" % SD, uri=True)
                 .execute("select gameid, game from tbl_game"))
except Exception:
    names = {}

def show():
    rows = c.execute("select ID, GameID from History order by ID desc").fetchall()
    for i, (id_, gid) in enumerate(rows, 1):
        print("%2d. %04d  %s  [ID %d]" % (i, gid, names.get(gid, "(name not found)"), id_))
    print(len(rows), "games in history")

cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
if cmd == "show":
    show()
elif cmd == "trim":
    n = int(sys.argv[2]) if len(sys.argv) > 2 else LIMIT
    c.execute("delete from History where ID not in (select max(ID) from History group by GameID)")
    c.execute("delete from History where ID not in (select ID from History order by ID desc limit ?)", (n,))
    c.commit(); show()
elif cmd == "del":
    c.execute("delete from History where GameID=?", (int(sys.argv[2]),)); c.commit(); show()
elif cmd == "clear":
    c.execute("delete from History"); c.commit(); show()
else:
    print(__doc__)
