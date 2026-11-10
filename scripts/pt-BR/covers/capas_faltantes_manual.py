#!/usr/bin/env python3
"""Baixa algumas capas à mão do libretro-thumbnails (Named_Boxarts).

Depende do cache gravado pelo capas_gamestick.py (~/.cache/capas_gamestick/<lib>.json,
uma lista JSON de nomes por repositório do libretro-thumbnails). Esse script AINDA NÃO está neste repositório.

Uso: SD=/run/media/user/<LABEL> python3 capas_faltantes_manual.py
Edite TASKS abaixo: (repositórios, destino sem extensão, palavras que devem aparecer no nome).
Nunca sobrescreve uma capa existente. Prefere USA > World > Europe, depois nomes mais curtos.
"""
import os, io, sys, json, urllib.request, urllib.parse
from PIL import Image

SD = os.environ.get('SD')
if not SD:
    sys.exit('Defina SD=/run/media/user/<LABEL>')
R = os.path.join(SD, 'game')
C = os.path.expanduser('~/.cache/capas_gamestick')
TASKS = [
    (['Nintendo_-_Game_Boy_Advance'], 'gba/Mega Man & Bass', ['mega man', 'bass']),
    (['Nintendo_-_Game_Boy_Advance'], 'gba/Mother 1 & 2', ['mother 1']),
    (['MAME', 'FBNeo_-_Arcade_Games'], 'cps/PACOTES CPS/cps1/3wonders', ['three wonders']),
]
pref = lambda n: (0 if '(USA' in n else 1 if '(World' in n else 2 if '(Europe' in n else 3, len(n))

for libs, dest, words in TASKS:
    print('\n==', dest)
    out = os.path.join(R, dest + '.png')
    if os.path.exists(out):
        print('   [já existe]'); continue
    cand = []
    for lib in libs:
        f = os.path.join(C, lib + '.json')
        if os.path.exists(f):
            cand += [(lib, n) for n in json.load(open(f)) if all(w in n.lower() for w in words)]
    for lib, n in cand[:8]:
        print('   candidato:', n)
    if not cand:
        print('   [sem candidato]'); continue
    lib, name = min(cand, key=lambda x: pref(x[1]))
    url = (f'https://raw.githubusercontent.com/libretro-thumbnails/{lib}/master/Named_Boxarts/'
           + urllib.parse.quote(name + '.png'))
    raw = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}),
                                 timeout=60).read()
    im = Image.open(io.BytesIO(raw)).convert('RGBA'); im.thumbnail((400, 400), Image.LANCZOS)
    t = Image.new('RGBA', (400, 400), (0, 0, 0, 255))
    t.paste(im, ((400 - im.width) // 2, (400 - im.height) // 2), im)
    t.convert('RGB').save(out, 'PNG')
    print('   [ok] usado:', name)
