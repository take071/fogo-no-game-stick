#!/usr/bin/env python3
"""Cria histtools/hist_vazio.sqlite3 NO CARTÃO: cópia do game/database.sqlite3 atual
com a tabela History esvaziada. O banco real só é lido.
Uso: python3 make_mold.py            (ou SD=/run/media/$USER/MEUCARTAO python3 make_mold.py)
"""
import glob, os, sqlite3, sys

SD = os.environ.get("SD")
if not SD:
    user = os.environ.get("USER", "")
    found = glob.glob("/run/media/%s/*/game/database.sqlite3" % user)
    if not found:
        sys.exit("Cartão SD não encontrado. Monte-o ou defina SD=/caminho/do/cartao")
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
print("molde criado, linhas em History:", dst.execute("select count(*) from History").fetchone()[0])
dst.close(); src.close()
