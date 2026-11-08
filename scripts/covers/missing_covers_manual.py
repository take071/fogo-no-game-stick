#!/usr/bin/env python3
"""Fetch a few covers manually from libretro-thumbnails (Named_Boxarts).

Depends on the cache written by capas_gamestick.py (~/.cache/capas_gamestick/<lib>.json,
a JSON list of names per libretro-thumbnails repo). That script is NOT in this repo yet.

Usage: SD=/run/media/user/<LABEL> python3 missing_covers_manual.py
Edit TASKS below: (repos, destination without extension, words that must appear in the name).
Never overwrites an existing cover. Prefers USA > World > Europe, then shorter names.
"""
import os, io, sys, json, urllib.request, urllib.parse
from PIL import Image

SD = os.environ.get('SD')
if not SD:
    sys.exit('Set SD=/run/media/user/<LABEL>')
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
        print('   [already exists]'); continue
    cand = []
    for lib in libs:
        f = os.path.join(C, lib + '.json')
        if os.path.exists(f):
            cand += [(lib, n) for n in json.load(open(f)) if all(w in n.lower() for w in words)]
    for lib, n in cand[:8]:
        print('   candidate:', n)
    if not cand:
        print('   [no candidate]'); continue
    lib, name = min(cand, key=lambda x: pref(x[1]))
    url = (f'https://raw.githubusercontent.com/libretro-thumbnails/{lib}/master/Named_Boxarts/'
           + urllib.parse.quote(name + '.png'))
    raw = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}),
                                 timeout=60).read()
    im = Image.open(io.BytesIO(raw)).convert('RGBA'); im.thumbnail((400, 400), Image.LANCZOS)
    t = Image.new('RGBA', (400, 400), (0, 0, 0, 255))
    t.paste(im, ((400 - im.width) // 2, (400 - im.height) // 2), im)
    t.convert('RGB').save(out, 'PNG')
    print('   [ok] used:', name)
