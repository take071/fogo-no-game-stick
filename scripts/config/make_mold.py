#!/usr/bin/env python3
"""Creates histtools/hist_vazio.sqlite3 ON THE CARD: a copy of the current
game/database.sqlite3 with the History table emptied. The real database is only read.
Usage: python3 make_mold.py            (or SD=/run/media/$USER/MYCARD python3 make_mold.py)
"""
import glob, os, sqlite3, sys

SD = os.environ.get("SD")
if not SD:
    user = os.environ.get("USER", "")
    found = glob.glob("/run/media/%s/*/game/database.sqlite3" % user)
    if not found:
        sys.exit("SD card not found. Mount it or set SD=/path/to/card")
    SD = found[0].rsplit("/game/", 1)[0]

os.makedirs(SD + "/histtools", exist_ok=True)
dst_path = SD + "/histtools/hist_vazio.sqlite3"
if os.path.exists(dst_path):
    os.remove(dst_path)
src = sqlite3.connect("file:%s/game/database.sqlite3?mode=ro" % SD, uri=True)
dst = sqlite3.connect(dst_path)
src.backup(dst)
dst.execute("delete from History")
dst.commit()
print("mold created, rows in History:", dst.execute("select count(*) from History").fetchone()[0])
dst.close(); src.close()
