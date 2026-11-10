#!/usr/bin/env python3
"""Gerencia o histórico do game stick pelo PC, direto no cartão SD.

Uso:
  python3 hist.py show          lista o histórico (mais recente primeiro)
  python3 hist.py trim [N]      mantém só os N mais recentes (padrão 15), um por jogo
  python3 hist.py del GAMEID    remove um jogo do histórico
  python3 hist.py clear         apaga tudo

O caminho do cartão é detectado sozinho (/run/media/$USER/*).
Se houver mais de um cartão, indique à mão:  SD=/run/media/$USER/MEUCARTAO python3 hist.py show
Os comandos diferentes de "show" ESCREVEM no cartão. Ejete com segurança antes de colocá-lo no aparelho.
"""
import glob, os, sqlite3, sys

LIMIT = 15
SD = os.environ.get("SD")
if not SD:
    user = os.environ.get("USER", "")
    found = glob.glob("/run/media/%s/*/game/database.sqlite3" % user)
    if not found:
        sys.exit("Cartão SD não encontrado. Monte-o ou defina SD=/caminho/do/cartao")
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
        print("%2d. %04d  %s  [ID %d]" % (i, gid, names.get(gid, "(nome não encontrado)"), id_))
    print(len(rows), "jogos no histórico")

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
