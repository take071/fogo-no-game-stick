#!/usr/bin/env python3
"""Fetch a few covers manually from libretro-thumbnails (Named_Boxarts).

Depends on the cache written by capas_gamestick.py (~/.cache/capas_gamestick/<lib>.json,
a JSON list of names per libretro-thumbnails repo). Run capas_gamestick.py once first.

Usage: python3 scripts/covers/missing_covers_manual.py [FOLDER] [--dry-run]
  FOLDER = the card root or its "game" folder (default: $SD, or the card in /run/media/$USER/*/game).
Since capas_gamestick.py ignores "&"/"_" when matching, "Mega Man & Bass" and "Mother 1 & 2" are
normally found by it; they stay here only as examples/fallback.
Edit TASKS below: (repos, destination without extension, words that must appear in the name).
Never overwrites an existing cover. Prefers USA > World > Europe, then shorter names.
A failure in one task (404, no network) is reported and the next task still runs.
"""
import glob, io, json, os, posixpath, sys, urllib.parse, urllib.request

DRY = '--dry-run' in sys.argv
ARG = next((a for a in sys.argv[1:] if not a.startswith('-')), None)

def achar_game_dir(arg):
    """Card root, its 'game' folder, or nothing (then $SD or /run/media/$USER/*/game)."""
    if arg:
        cands = [os.path.join(arg, 'game'), arg]
    elif os.environ.get('SD'):
        cands = [os.path.join(os.environ['SD'], 'game')]
    else:
        cands = sorted(glob.glob('/run/media/%s/*/game' % os.environ.get('USER', '')))
        if len(cands) > 1:
            sys.exit('More than one card found, give the folder as argument:\n  ' + '\n  '.join(cands))
    for c in cands:
        if os.path.isdir(c):
            return c
    sys.exit('Games folder not found. Give it as argument, e.g. /run/media/user/<LABEL>/game')

try:
    from PIL import Image
except ImportError:
    sys.exit('Pillow missing: sudo dnf install python3-pillow')

R = achar_game_dir(ARG)
C = os.path.expanduser('~/.cache/capas_gamestick')
TASKS = [
    (['Nintendo_-_Game_Boy_Advance'], 'gba/Mega Man & Bass', ['mega man', 'bass']),
    (['Nintendo_-_Game_Boy_Advance'], 'gba/Mother 1 & 2', ['mother 1']),
    (['MAME', 'FBNeo_-_Arcade_Games'], 'cps/PACOTES CPS/cps1/3wonders', ['three wonders']),
]
pref = lambda n: (0 if '(USA' in n else 1 if '(World' in n else 2 if '(Europe' in n else 3, len(n))

def baixar_boxart(lib, name, hops=3):
    """Named_Boxarts/<name>.png; follows git symlinks (the server then returns just the target
    path as text, e.g. for "(Disc 1)" names in the PlayStation repo)."""
    path = 'Named_Boxarts/' + name + '.png'
    for _ in range(hops + 1):
        url = f'https://raw.githubusercontent.com/libretro-thumbnails/{lib}/master/' + urllib.parse.quote(path)
        raw = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}),
                                     timeout=60).read()
        if raw[:4] == b'\x89PNG' or raw[:2] == b'\xff\xd8':
            return raw
        txt = raw[:400].decode('utf-8', 'replace').strip()
        if len(raw) < 400 and '\n' not in txt and txt.lower().endswith(('.png', '.jpg', '.jpeg')):
            path = posixpath.normpath(posixpath.join(posixpath.dirname(path), txt))
            continue
        raise ValueError('server did not return an image')
    raise ValueError('too many symlink hops')


failed = 0
for libs, dest, words in TASKS:
    print('\n==', dest)
    out = os.path.join(R, dest + '.png')
    if os.path.exists(out):
        print('   [already exists]')
        continue
    cand = []
    for lib in libs:
        f = os.path.join(C, lib + '.json')
        if os.path.exists(f):
            cand += [(lib, n) for n in json.load(open(f)) if all(w in n.lower() for w in words)]
    for lib, n in cand[:8]:
        print('   candidate:', n)
    if not cand:
        print('   [no candidate] (is the cache there? run capas_gamestick.py first)')
        continue
    lib, name = min(cand, key=lambda x: pref(x[1]))
    if DRY:
        print('   [would download]', name)
        continue
    try:
        raw = baixar_boxart(lib, name)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        im = Image.open(io.BytesIO(raw)).convert('RGBA')
        im.thumbnail((400, 400), Image.LANCZOS)
        t = Image.new('RGBA', (400, 400), (0, 0, 0, 255))
        t.paste(im, ((400 - im.width) // 2, (400 - im.height) // 2), im)
        t.convert('RGB').save(out, 'PNG')
        print('   [ok] used:', name)
    except Exception as e:
        failed += 1
        print(f'   [ERROR] {name}: {e}')
sys.exit(1 if failed else 0)
