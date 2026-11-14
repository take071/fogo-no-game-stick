#!/usr/bin/env python3
"""Baixa as capas (boxarts) de todos os jogos do cartão do Game Stick (libretro-thumbnails / Named_Boxarts).

Uso:
  python3 scripts/pt-BR/covers/capas_gamestick.py [PASTA] [--dry-run] [--report ARQUIVO]
    PASTA = a raiz do cartão ou a pasta "game". Se omitida: $SD, ou o cartão montado em
    /run/media/$USER/*/game.   (SIMULAR=1 continua funcionando como apelido de --dry-run)

Como funciona
  * o console vem da extensão do arquivo (.gba, .sfc, ...) ou, para arquivos genéricos
    (.zip/.7z/.bin), do nome da pasta (gba, cps, ps1, ...);
  * a lista de nomes de capas de cada repositório libretro-thumbnails fica em cache em
    ~/.cache/capas_gamestick/<repo>.json por 7 dias (API do GitHub: 60 requisições/hora sem login);
  * os títulos são normalizados (sem (...)/[...], "Zelda, The" -> "The Zelda", "&" e "_" ignorados,
    a palavra "and" ignorada) e comparados: exato > próximo (0,9) > prefixo > sufixo;
  * prefere USA > World > Europe e evita Beta/Proto/Demo/Hack;
  * a imagem é ajustada ao tamanho mais usado pelas capas já existentes na pasta
    (padrão 400x400, fundo preto) e salva como <jogo>.png ao lado do jogo;
  * nunca sobrescreve uma capa existente; jogos sem correspondência vão para o arquivo de relatório
    (padrão ~/capas_relatorio.txt).  Hacks/traduções ficam sem capa de propósito.
Precisa do Pillow (pip install pillow / dnf install python3-pillow).
"""
import argparse, collections, difflib, glob, io, json, os, posixpath, re, sys, time
import urllib.error, urllib.parse, urllib.request

ORG = 'libretro-thumbnails'
UA = {'User-Agent': 'Mozilla/5.0'}
CACHE = os.path.expanduser('~/.cache/capas_gamestick')
DEFAULT_SIZE = (400, 400)

NES = 'Nintendo_-_Nintendo_Entertainment_System'
SNES = 'Nintendo_-_Super_Nintendo_Entertainment_System'
GB, GBC, GBA = 'Nintendo_-_Game_Boy', 'Nintendo_-_Game_Boy_Color', 'Nintendo_-_Game_Boy_Advance'
N64, MD, PS1 = 'Nintendo_-_Nintendo_64', 'Sega_-_Mega_Drive_-_Genesis', 'Sony_-_PlayStation'
EXT_LIB = {
    '.nes': NES, '.unf': NES, '.unif': NES, '.fds': 'Nintendo_-_Family_Computer_Disk_System',
    '.gb': GB, '.gbc': GBC, '.gba': GBA,
    '.sfc': SNES, '.smc': SNES, '.fig': SNES, '.swc': SNES,
    '.n64': N64, '.z64': N64, '.v64': N64,
    '.md': MD, '.smd': MD, '.gen': MD,
    '.32x': 'Sega_-_32X', '.sms': 'Sega_-_Master_System_-_Mark_III', '.gg': 'Sega_-_Game_Gear',
    '.pbp': PS1, '.cue': PS1, '.chd': PS1,
    '.a26': 'Atari_-_2600', '.a52': 'Atari_-_5200', '.a78': 'Atari_-_7800',
}
FOLDER_LIBS = {'fc': [NES], 'gb': [GB], 'gbc': [GBC], 'gba': [GBA], 'sfc': [SNES], 'n64': [N64],
               'md': [MD], 'ps1': [PS1], 'atari': ['Atari_-_2600'],
               'cps': ['MAME', 'FBNeo_-_Arcade_Games']}
GAME_EXT = set(EXT_LIB) | {'.zip', '.7z', '.bin', '.iso', '.rom'}
IMG_EXT = ('.png', '.jpg', '.jpeg')


def get(url, tries=4):
    for i in range(tries):
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()
        except urllib.error.HTTPError as e:
            if e.code in (403, 429):
                raise RuntimeError('Limite do GitHub atingido (espere ~1 hora)')
            if e.code == 404 or i == tries - 1:
                raise
        except Exception:
            if i == tries - 1:
                raise
        time.sleep(2 * (i + 1))


def baixar_boxart(lib, nome, hops=3):
    """Baixa Named_Boxarts/<nome>.png. No libretro-thumbnails muitos nomes (ex.: variantes
    "(Disc 1)") são LINKS SIMBÓLICOS do git: o raw.githubusercontent devolve então só o caminho
    do destino como texto (ex.: 'Final Fantasy VII (USA).png', 27 bytes). Segue o link em vez de falhar."""
    path = 'Named_Boxarts/' + nome + '.png'
    for _ in range(hops + 1):
        raw = get(f'https://raw.githubusercontent.com/{ORG}/{lib}/master/' + urllib.parse.quote(path))
        if raw[:4] == b'\x89PNG' or raw[:2] == b'\xff\xd8':
            return raw
        txt = raw[:400].decode('utf-8', 'replace').strip()
        if len(raw) < 400 and '\n' not in txt and txt.lower().endswith(('.png', '.jpg', '.jpeg')):
            path = posixpath.normpath(posixpath.join(posixpath.dirname(path), txt))
            continue
        raise ValueError('o servidor não devolveu uma imagem')
    raise ValueError('links simbólicos demais')


def norm(s):
    """Forma comparável de um título. O libretro-thumbnails troca '&' por '_' nos nomes de arquivo,
    então '&', '_' e a palavra 'and' são descartados nos DOIS lados (as primeiras versões só trocavam
    o '&' do título por 'and' e perdiam 'Mega Man & Bass' / 'Mother 1 & 2')."""
    s = re.sub(r'\([^)]*\)|\[[^\]]*\]', ' ', s)
    m = re.match(r'^(.*?), (the|a|an)(?= - |$| )(.*)$', s.strip(), re.I)
    if m:
        s = f'{m.group(2)} {m.group(1)}{m.group(3)}'
    s = re.sub(r'[^a-z0-9]+', ' ', s.lower()).strip()
    return ' '.join(w for w in s.split() if w != 'and')


def pref(n):
    r = 0 if '(USA' in n else 1 if '(World' in n else 2 if '(Europe' in n else 3
    bad = any(t in n for t in ('(Beta', '(Proto', '(Demo', '(Sample', '(Unl', '(Pirate', '(Hack'))
    return (bad, r, len(n))


_idx = {}


def indice(lib):
    if lib in _idx:
        return _idx[lib]
    os.makedirs(CACHE, exist_ok=True)
    cache = os.path.join(CACHE, lib + '.json')
    if os.path.exists(cache) and time.time() - os.path.getmtime(cache) < 7 * 86400:
        names = json.load(open(cache))
    else:
        try:
            base = f'https://api.github.com/repos/{ORG}/{lib}/git/trees/'
            root = json.loads(get(base + 'master'))
            sha = next(t['sha'] for t in root['tree'] if t['path'] == 'Named_Boxarts')
            sub = json.loads(get(base + sha))
            names = [t['path'][:-4] for t in sub['tree'] if t['path'].lower().endswith('.png')]
            json.dump(names, open(cache, 'w'))
        except Exception as e:
            print(f'    AVISO: sem lista de {lib} ({e})')
            names = []
    idx = collections.defaultdict(list)
    for n in names:
        idx[norm(n)].append(n)
    _idx[lib] = idx
    return idx


def achar(title, libs):
    n = norm(title)
    if not n:
        return None
    for lib in libs:
        idx = indice(lib)
        if n in idx:
            return lib, min(idx[n], key=pref)
        first = n.split()[0]
        pool = [k for k in idx if k.split()[0] == first]          # pré-filtro barato: difflib em
        c = difflib.get_close_matches(n, pool, 1, 0.9)             # milhares de nomes é lento
        if c:
            return lib, min(idx[c[0]], key=pref)
        if len(n) >= 6:
            c = sorted([k for k in pool if k.startswith(n + ' ')], key=len)[:1]
            if c:
                return lib, min(idx[c[0]], key=pref)
        if len(n) >= 10:
            c = sorted([k for k in idx if k.endswith(' ' + n)], key=len)[:1]
            if c:
                return lib, min(idx[c[0]], key=pref)
    return None


def tamanho(d, files):
    from PIL import Image
    c = collections.Counter()
    for f in files:
        if f.lower().endswith(IMG_EXT) and 'bios' not in f.lower() and 'scph' not in f.lower():
            try:
                c[Image.open(os.path.join(d, f)).size] += 1
            except Exception:
                pass
    return c.most_common(1)[0][0] if c else DEFAULT_SIZE


def salvar(raw, out, size):
    from PIL import Image
    im = Image.open(io.BytesIO(raw)).convert('RGBA')
    im.thumbnail(size, Image.LANCZOS)
    t = Image.new('RGBA', size, (0, 0, 0, 255))
    t.paste(im, ((size[0] - im.width) // 2, (size[1] - im.height) // 2), im)
    t.convert('RGB').save(out, 'PNG')


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

def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('folder', nargs='?', help='raiz do cartão ou sua pasta game')
    ap.add_argument('--dry-run', action='store_true', default=bool(os.environ.get('SIMULAR')))
    ap.add_argument('--report', default=os.path.expanduser('~/capas_relatorio.txt'))
    a = ap.parse_args()
    root_dir = achar_game_dir(a.folder)
    try:
        import PIL  # noqa: F401
    except ImportError:
        sys.exit('Pillow ausente: sudo dnf install python3-pillow  (ou pip install pillow)')

    print('Pasta:', root_dir, '[SIMULAÇÃO]' if a.dry_run else '')
    stats, faltam, parar = collections.Counter(), [], False
    for d, dirs, files in sorted(os.walk(root_dir)):
        if parar:
            break
        dirs.sort()
        rel = os.path.relpath(d, root_dir)
        top = rel.split(os.sep)[0]
        lower = {f.lower() for f in files}
        games = {}
        for f in sorted(files):
            base, ext = os.path.splitext(f)
            ext = ext.lower()
            if ext not in GAME_EXT or f.startswith('.') or 'bios' in f.lower() or 'scph' in f.lower():
                continue
            if top == 'ps1' and ext not in ('.pbp', '.cue', '.chd', '.iso'):
                continue
            games.setdefault(base, ext)
        if not games:
            continue
        size = tamanho(d, files)
        print(f'\n== {rel} ({len(games)} jogos, capa {size[0]}x{size[1]})')
        for base, ext in sorted(games.items()):
            if any(base.lower() + e in lower for e in IMG_EXT):
                stats['já tinha'] += 1
                continue
            libs = [EXT_LIB[ext]] if ext in EXT_LIB else FOLDER_LIBS.get(top, [])
            achado = achar(base, libs) if libs else None
            if not achado:
                print(f'  [sem capa] {base}')
                faltam.append(os.path.join(rel, base))
                stats['sem capa'] += 1
                continue
            lib, nome = achado
            if a.dry_run:
                print(f'  [baixaria] {base} <- {nome}')
                stats['baixaria'] += 1
                continue
            try:
                salvar(baixar_boxart(lib, nome), os.path.join(d, base + '.png'), size)
                print(f'  [ok] {base} <- {nome}')
                stats['baixadas'] += 1
                time.sleep(0.2)
            except RuntimeError as e:
                print(f'  [PARADO] {e}')
                stats['erro'] += 1
                faltam.append(os.path.join(rel, base))
                parar = True
                break
            except Exception as e:
                print(f'  [ERRO] {base}: {e}')
                stats['erro'] += 1
                faltam.append(os.path.join(rel, base))

    print('\n=== RESUMO ===')
    for k, v in stats.items():
        print(f'  {k}: {v}')
    if faltam:
        with open(a.report, 'w') as fh:
            fh.write('Jogos sem capa (coloque <nome>.png ao lado do jogo):\n' + '\n'.join(faltam) + '\n')
        print('  lista dos que faltam em', a.report)


if __name__ == '__main__':
    main()
