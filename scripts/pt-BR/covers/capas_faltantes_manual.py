#!/usr/bin/env python3
"""Busca algumas capas à mão no libretro-thumbnails (Named_Boxarts).

Depende do cache gravado pelo capas_gamestick.py (~/.cache/capas_gamestick/<lib>.json,
uma lista JSON de nomes por repositório libretro-thumbnails). Rode o capas_gamestick.py uma vez antes.

Uso: python3 scripts/pt-BR/covers/capas_faltantes_manual.py [PASTA] [--dry-run]
  PASTA = a raiz do cartão ou a pasta "game" (padrão: $SD, ou o cartão em /run/media/$USER/*/game).
Como o capas_gamestick.py ignora "&"/"_" ao comparar, "Mega Man & Bass" e "Mother 1 & 2" em geral
são achados por ele; ficam aqui só como exemplo/alternativa.
Edite TASKS abaixo: (repositórios, destino sem extensão, palavras que devem aparecer no nome).
Nunca sobrescreve uma capa existente. Prefere USA > World > Europe, depois nomes mais curtos.
Uma falha numa tarefa (404, sem rede) é relatada e a próxima tarefa continua.
"""
import glob, io, json, os, posixpath, sys, urllib.parse, urllib.request

DRY = '--dry-run' in sys.argv
ARG = next((a for a in sys.argv[1:] if not a.startswith('-')), None)

def achar_game_dir(arg):
    """Raiz do cartão, sua pasta 'game' ou nada (então $SD ou /run/media/$USER/*/game)."""
    if arg:
        cands = [os.path.join(arg, 'game'), arg]
    elif os.environ.get('SD'):
        cands = [os.path.join(os.environ['SD'], 'game')]
    else:
        cands = sorted(glob.glob('/run/media/%s/*/game' % os.environ.get('USER', '')))
        if len(cands) > 1:
            sys.exit('Mais de um cartão encontrado, passe a pasta como argumento:\n  ' + '\n  '.join(cands))
    for c in cands:
        if os.path.isdir(c):
            return c
    sys.exit('Pasta de jogos não encontrada. Passe-a como argumento, ex.: /run/media/usuario/<NOME>/game')

try:
    from PIL import Image
except ImportError:
    sys.exit('Pillow ausente: sudo dnf install python3-pillow')

R = achar_game_dir(ARG)
C = os.path.expanduser('~/.cache/capas_gamestick')
TASKS = [
    (['Nintendo_-_Game_Boy_Advance'], 'gba/Mega Man & Bass', ['mega man', 'bass']),
    (['Nintendo_-_Game_Boy_Advance'], 'gba/Mother 1 & 2', ['mother 1']),
    (['MAME', 'FBNeo_-_Arcade_Games'], 'cps/PACOTES CPS/cps1/3wonders', ['three wonders']),
]
pref = lambda n: (0 if '(USA' in n else 1 if '(World' in n else 2 if '(Europe' in n else 3, len(n))

def baixar_boxart(lib, name, hops=3):
    """Named_Boxarts/<nome>.png; segue links simbólicos do git (o servidor devolve então só o caminho
    do destino como texto, ex.: nomes "(Disc 1)" no repositório do PlayStation)."""
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
        raise ValueError('o servidor não devolveu uma imagem')
    raise ValueError('links simbólicos demais')


failed = 0
for libs, dest, words in TASKS:
    print('\n==', dest)
    out = os.path.join(R, dest + '.png')
    if os.path.exists(out):
        print('   [já existe]')
        continue
    cand = []
    for lib in libs:
        f = os.path.join(C, lib + '.json')
        if os.path.exists(f):
            cand += [(lib, n) for n in json.load(open(f)) if all(w in n.lower() for w in words)]
    for lib, n in cand[:8]:
        print('   candidata:', n)
    if not cand:
        print('   [nenhuma candidata] (o cache existe? rode o capas_gamestick.py antes)')
        continue
    lib, name = min(cand, key=lambda x: pref(x[1]))
    if DRY:
        print('   [baixaria]', name)
        continue
    try:
        raw = baixar_boxart(lib, name)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        im = Image.open(io.BytesIO(raw)).convert('RGBA')
        im.thumbnail((400, 400), Image.LANCZOS)
        t = Image.new('RGBA', (400, 400), (0, 0, 0, 255))
        t.paste(im, ((400 - im.width) // 2, (400 - im.height) // 2), im)
        t.convert('RGB').save(out, 'PNG')
        print('   [ok] usada:', name)
    except Exception as e:
        failed += 1
        print(f'   [ERRO] {name}: {e}')
sys.exit(1 if failed else 0)
