#!/usr/bin/env python3
"""Converte jogos de PS1 (.cue/.bin ou .chd) para .PBP no Game Stick, juntando jogos de
vários discos em UM único PBP multidisco.  Gêmeo em Python do converter_ps1.sh (mesmas opções, mesmo comportamento).

Uso:
  python3 scripts/pt-BR/ps1/ps1_pbp.py [PASTA] [opções]
    PASTA = pasta com os jogos de PS1 (busca recursiva). Se omitida, usa $SD/game/ps1.
  O PSX é achado sozinho (~/Downloads/psxpackager/psxpackager-linux-x64/psxpackager ou
  `psxpackager` no PATH); senão, defina PSX=/caminho/do/psxpackager (ou --psx).

  --dry-run        só mostra o que aconteceria, não altera nada
  --delete         depois de existir um .PBP VÁLIDO, apaga os originais (.cue/.bin/.chd e os
                   PBPs de disco único que foram juntados). PERMANENTE: teste os PBPs antes.
  --no-merge       não junta discos; converte cada disco no seu próprio PBP
  --force-partial  junta mesmo com numeração de discos não contígua (ex.: só os discos 1 e 3)
  --level N        nível de compressão do PBP 0-9 (padrão 5)
  --sd / --psx / --chdman / --tmp   substituem SD / PSX / CHDMAN / PSX_TMP

Fontes .chd precisam do `chdman` (Fedora: sudo dnf install mame-tools) porque o PSXPackager
1.6.x não lê CHD.  Usa só a biblioteca padrão do Python.

NOTA (PSXPackager 1.6.2, medido): "-x" significa "sobrescrever", NÃO "extrair". Extrair não
precisa de flag: um .pbp passado em -i é extraído para .bin/.cue (e "-d 1,2" escolhe os discos).
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

IMG_EXT = ('.png', '.jpg', '.jpeg')
# surrogateescape preserva cada byte de um nome de arquivo / .cue exatamente como está (UTF-8 ou não)
ENC = dict(encoding='utf-8', errors='surrogateescape', newline='')
FILE_RE = re.compile(r'^(\s*FILE\s+")([^"\r\n]+)(".*)$', re.M | re.I)
DISC_RE = re.compile(
    r'^(?P<pre>.*[^\s_-])?[\s_-]*[(\[](?:disc|disco|disk|cd)\s*(?P<n>\d+)'
    r'(?:\s*(?:of|de)\s*\d+)?[)\]](?P<post>.*)$', re.I)


class Ctx:
    """Configurações e contadores da execução."""
    def __init__(self, a):
        self.dry, self.delete, self.merge = a.dry_run, a.delete, not a.no_merge
        self.force, self.level = a.force_partial, a.level
        self.psx, self.chdman, self.work = a.psx, a.chdman, Path(a.work)
        self.ok = self.skip = self.err = self.deleted = 0


def protected(name):
    n = name.lower()
    return 'scph' in n or 'bios' in n


def valid_pbp(p):
    """Não vazio E começa com a assinatura do PBP (00 'P' 'B' 'P')."""
    try:
        p = Path(p)
        if not p.is_file() or p.stat().st_size == 0:
            return False
        with open(p, 'rb') as fh:
            return fh.read(4) == b'\x00PBP'
    except OSError:
        return False


def existing_pbp(base):
    for ext in ('.PBP', '.pbp'):
        if Path(str(base) + ext).is_file():
            return Path(str(base) + ext)
    return None


def cue_files(cue):
    return [m.group(2) for m in FILE_RE.finditer(open(cue, **ENC).read())]


def run_psx(c, args):
    """Roda o psxpackager; devolve (rc, saída combinada)."""
    p = subprocess.run([c.psx] + args, stdin=subprocess.DEVNULL,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return p.returncode, p.stdout.decode('utf-8', 'replace')


def rm_file(c, p):
    p = Path(p)
    if c.dry:
        print(f'  [apagaria] {p.name}')
        return
    try:
        p.unlink()
        print(f'  [apagado] {p.name}')
        c.deleted += 1
    except OSError as e:
        print(f'  [ERRO] não foi possível apagar {p.name}: {e}')


# 1) corrige linhas FILE que apontam para um .bin que não existe ---------------------------
def fix_cue(c, cue):
    d, base = cue.parent, cue.stem
    txt = open(cue, **ENC).read()
    nfile = len(FILE_RE.findall(txt))
    bins = [f.name for f in d.iterdir() if f.is_file() and f.suffix.lower() == '.bin']
    changed = []

    def fix(m):
        name = m.group(2)
        if (d / name).exists():
            return m.group(0)
        cand = next((b for b in bins if b.lower() == name.lower()), None)      # (a) só maiúsculas
        if cand is None and nfile == 1:                                         # (b)/(c) .cue com um único FILE
            cand = next((b for b in bins if Path(b).stem.lower() == base.lower()), None)
            if cand is None and len(bins) == 1:
                cand = bins[0]
        if cand:
            print(f'[corrigido] {cue.name}: {name} -> {cand}')
            changed.append(1)
            return f'{m.group(1)}{cand}{m.group(3)}'
        print(f"[SEM BIN] {cue.name} (referencia '{name}')")
        return m.group(0)

    new = FILE_RE.sub(fix, txt)
    if changed and not c.dry:
        with open(cue, 'w', **ENC) as fh:
            fh.write(new)


def disc_parse(base):
    m = DISC_RE.match(base)
    if not m:
        return None
    key = ((m.group('pre') or '') + m.group('post')).strip()
    return int(m.group('n')), key


# funções que usam psxpackager / chdman ------------------------------------------------
def prep_source(c, typ, path, tag):
    """Devolve o .cue para o psxpackager (extraindo .chd / .pbp antes) ou None."""
    if typ == 'cue':
        return path
    dd = c.work / tag
    dd.mkdir(parents=True, exist_ok=True)
    if typ == 'chd':
        if not shutil.which(c.chdman):
            print(f'[chd] {path}: o PSXPackager não lê .chd e o chdman não foi encontrado; instale o mame-tools ou rode: '
                  f'chdman extractcd -i "{path}" -o "{path.with_suffix(".cue")}" -ob "{path.with_suffix(".bin")}"')
            return None
        r = subprocess.run([c.chdman, 'extractcd', '-i', str(path), '-o', str(dd / 'disc.cue'),
                            '-ob', str(dd / 'disc.bin')], stdout=subprocess.DEVNULL)
        if r.returncode != 0:
            print(f'[ERRO] chdman falhou em {path}')
            return None
        return dd / 'disc.cue'
    rc, out = run_psx(c, ['-i', str(path), '-o', str(dd), '-x', '-v', '1'])   # .pbp: não precisa de flag
    cues = sorted(dd.glob('*.cue')) + sorted(dd.glob('*.CUE'))
    if rc != 0 or not cues:
        print(f'[ERRO] falha ao extrair: {path}')
        print('    ' + out.strip().replace('\n', '\n    '))
        return None
    return cues[0]


def pack(c, inp, final):
    """psxpackager num .cue/.m3u; depois move o PBP para `final` só se for válido."""
    out = Path(tempfile.mkdtemp(prefix='out.', dir=c.work))
    rc, log = run_psx(c, ['-i', str(inp), '-o', str(out), '-l', str(c.level), '-x', '-v', '1'])
    produced = next(iter(sorted(out.glob('*.[pP][bB][pP]'))), None)
    if rc != 0 or produced is None or not valid_pbp(produced):
        print(f'[ERRO] nenhum PBP válido gerado: {final.name}')
        print('    ' + log.strip().replace('\n', '\n    '))
        shutil.rmtree(out, ignore_errors=True)
        return False
    part = final.with_name(final.name + '.part')
    try:
        shutil.copyfile(produced, part)
        os.replace(part, final)
    except OSError as e:
        print(f'[ERRO] não foi possível gravar {final}: {e}')
        part.unlink(missing_ok=True)
        shutil.rmtree(out, ignore_errors=True)
        return False
    shutil.rmtree(out, ignore_errors=True)
    return valid_pbp(final)


def verify_discs(c, final, n):
    """Verificação real antes de apagar: extrai o ÚLTIMO disco do PBP unificado.
    Medido: um PBP multidisco extrai como '<nome> - Disc N.cue'; um PBP de disco ÚNICO ignora
    '-d 2' e extrai seu único disco sem esse sufixo."""
    v = Path(tempfile.mkdtemp(prefix='verify.', dir=c.work))
    run_psx(c, ['-i', str(final), '-o', str(v), '-d', str(n), '-x', '-v', '1'])
    ok = any(f.name.lower().endswith(f' - disc {n}.cue') for f in v.iterdir())
    shutil.rmtree(v, ignore_errors=True)
    return ok


def delete_sources(c, srcs):
    for typ, path in srcs:
        if typ == 'cue':
            for f in cue_files(path):
                p = path.parent / f
                if p.is_file() and not protected(f):
                    rm_file(c, p)
        rm_file(c, path)


def delete_disc_covers(c, d, bases):
    for b in bases:
        for ext in IMG_EXT:
            for p in (d / (b + ext), d / (b + ext.upper())):
                if p.is_file():
                    rm_file(c, p)


def move_cover(c, d, key, first):
    """Mantém a capa do Disco 1 como a capa do jogo unificado."""
    if any((d / (key + e)).exists() for e in IMG_EXT):
        return
    for e in IMG_EXT:
        for ee in (e, e.upper()):
            src = d / (first + ee)
            if src.is_file():
                print(f'  [capa] {src.name} -> {key}{ee}')
                if not c.dry:
                    shutil.copyfile(src, d / (key + ee))
                return


def free_kb(path):
    st = os.statvfs(path)
    return st.f_bavail * st.f_frsize // 1024


# lógica por jogo ---------------------------------------------------------------------------
def convert_single(c, d, base, typ, path):
    final = d / (base + '.PBP')
    ex = existing_pbp(d / base)
    if ex and valid_pbp(ex):
        print(f'[pular] {base} (PBP já existe)')
        c.skip += 1
        if c.delete:
            delete_sources(c, [(typ, path)])
        return
    print(f'[converter] {base}')
    if c.dry:
        return
    cue = prep_source(c, typ, path, f's.{os.getpid()}.{base[:20]}')
    if cue is None:
        c.err += 1
        return
    if pack(c, cue, final):
        c.ok += 1
        if c.delete:
            delete_sources(c, [(typ, path)])
    else:
        c.err += 1
        print(f'[manter] originais de {base} mantidos (sem PBP válido)')


def merge_group(c, d, key, best):
    nums = sorted(best)
    total = len(nums)
    if nums != list(range(1, total + 1)) and not c.force:
        print(f'[AVISO] {key}: discos encontrados: {" ".join(map(str, nums))} (não é 1..{total}). '
              f'Não juntado. Use --force-partial para juntar mesmo assim.')
        c.skip += 1
        return
    srcs = [best[n] for n in nums]                      # (type, path)
    bases = [p.stem for _, p in srcs]
    ex = existing_pbp(d / key)
    if ex and valid_pbp(ex):
        print(f'[pular] {key} (PBP unificado já existe)')
        c.skip += 1
        if c.delete:
            if c.dry or verify_discs(c, ex, total):
                delete_sources(c, srcs)
                delete_disc_covers(c, d, bases)
            else:
                print(f'[manter] {key}.PBP não contém {total} discos; originais mantidos')
        return

    print(f'[juntar] {key} ({total} discos: {" ".join(map(str, nums))})')
    for n in nums:
        print(f'  disco {n} <- {best[n][1].name} ({best[n][0]})')
    if c.dry:
        move_cover(c, d, key, bases[0])
        return

    need = 0                                           # KB de espaço de trabalho necessário
    for typ, p in srcs:
        if typ == 'cue':
            need += sum((p.parent / f).stat().st_size // 1024 for f in cue_files(p) if (p.parent / f).is_file())
        else:
            need += p.stat().st_size // 1024 * 3
    if free_kb(c.work) < need:
        print(f'[ERRO] {key}: precisa de ~{need // 1024} MB em {c.work}, só {free_kb(c.work) // 1024} MB livres (defina --tmp)')
        c.err += 1
        return

    m3u = c.work / f'{key}.m3u'
    lines = []
    for n in nums:
        cue = prep_source(c, best[n][0], best[n][1], f'd{n}.{os.getpid()}.{abs(hash(key)) % 10**6}')
        if cue is None:
            print(f'[ERRO] {key}: disco {n} falhou')
            c.err += 1
            return
        lines.append(str(cue))
    m3u.write_text('\n'.join(lines) + '\n', encoding='utf-8', errors='surrogateescape')
    final = d / (key + '.PBP')
    if pack(c, m3u, final):
        c.ok += 1
        move_cover(c, d, key, bases[0])
        if c.delete:
            if verify_discs(c, final, total):
                delete_sources(c, srcs)
                delete_disc_covers(c, d, bases)
            else:
                print(f'[manter] {key}.PBP falhou na verificação de {total} discos; originais mantidos')
    else:
        c.err += 1
        print(f'[manter] originais de {key} mantidos (sem PBP válido)')
    m3u.unlink(missing_ok=True)


PRI = {'cue': 3, 'chd': 2, 'pbp': 1}


def process_dir(c, d):
    files = sorted(f for f in d.iterdir() if f.is_file() and not f.name.startswith('.'))
    has_cue = {f.stem for f in files if f.suffix.lower() == '.cue'}
    groups = {}                                         # chave -> {n: (tipo, caminho)}
    for f in files:
        typ = f.suffix.lower().lstrip('.')
        if typ not in PRI:
            continue
        if protected(f.stem):
            print(f'[bios] ignorado {f.name}')
            continue
        if typ == 'chd' and f.stem in has_cue:           # o .cue vence o .chd
            continue
        dp = disc_parse(f.stem)
        if dp:
            n, key = dp
        else:
            if typ == 'pbp':                              # um PBP final de disco único: nada a fazer
                continue
            key, n = f.stem, 1
        cur = groups.setdefault(key, {}).get(n)
        if cur is None or PRI[typ] > PRI[cur[0]]:
            groups[key][n] = (typ, f)
    for key in sorted(groups):
        best = groups[key]
        if len(best) >= 2 and c.merge:
            merge_group(c, d, key, best)
        else:
            for n in sorted(best):
                typ, p = best[n]
                if typ != 'pbp':
                    convert_single(c, d, p.stem, typ, p)


def main():
    ap = argparse.ArgumentParser(description='Converte jogos de PS1 para PBP, juntando jogos de vários discos.')
    ap.add_argument('folder', nargs='?', help='pasta com os jogos de PS1 (padrão: $SD/game/ps1)')
    ap.add_argument('--sd', default=os.environ.get('SD'))
    ap.add_argument('--psx', default=os.environ.get('PSX'))
    ap.add_argument('--chdman', default=os.environ.get('CHDMAN', 'chdman'))
    ap.add_argument('--tmp', default=os.environ.get('PSX_TMP') or
                    os.path.join(os.environ.get('XDG_CACHE_HOME') or os.path.expanduser('~/.cache'), 'gamestick_psx'))
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--delete', action='store_true')
    ap.add_argument('--no-merge', action='store_true')
    ap.add_argument('--force-partial', action='store_true')
    ap.add_argument('--level', type=int, default=5, choices=range(10), metavar='0-9')
    a = ap.parse_args()
    if a.folder:
        root = Path(a.folder)
    elif a.sd:
        root = Path(a.sd) / 'game' / 'ps1'
    else:
        sys.exit('Passe a PASTA dos jogos como argumento ou defina SD=/run/media/usuario/<NOME>')
    if not root.is_dir():
        sys.exit(f'[erro] pasta não encontrada: {root}')
    if not a.psx:
        for cand in (Path.home() / 'Downloads/psxpackager/psxpackager-linux-x64/psxpackager',
                     shutil.which('psxpackager')):
            if cand and os.access(cand, os.X_OK):
                a.psx = str(cand)
                break
    if not a.psx:
        sys.exit('psxpackager não encontrado: defina PSX=/caminho/do/psxpackager (ou --psx)')
    if not os.access(a.psx, os.X_OK):
        sys.exit(f'[erro] {a.psx} não é executável')
    Path(a.tmp).mkdir(parents=True, exist_ok=True)
    a.work = tempfile.mkdtemp(prefix='run.', dir=a.tmp)
    if Path(a.work).resolve().is_relative_to(root.resolve()):
        sys.exit('[erro] --tmp não pode ficar dentro da pasta dos jogos')
    c = Ctx(a)
    try:
        print(f'Pasta: {root}  [dry-run={int(c.dry)} delete={int(c.delete)} merge={int(c.merge)}]')
        dirs = [Path(r) for r, ds, _ in os.walk(root)
                if not any(p.startswith('.') for p in Path(r).relative_to(root).parts)]
        for d in sorted(dirs):                                       # etapa 1: corrige todos os .cue
            for f in sorted(d.iterdir()):
                if f.is_file() and f.suffix.lower() == '.cue' and not f.name.startswith('.'):
                    fix_cue(c, f)
        for d in sorted(dirs):                                       # etapa 2: converte / junta
            process_dir(c, d)
        if not c.dry:                                                # etapa 3: padroniza a extensão
            for d in dirs:
                for f in d.iterdir():
                    if f.is_file() and f.suffix == '.pbp' and not f.name.startswith('.'):
                        tmp = f.with_suffix('.tmp_ren')
                        f.rename(tmp)
                        tmp.rename(f.with_suffix('.PBP'))
        if not c.delete:
            print('[info] originais mantidos (use --delete para apagá-los depois de testar os PBPs)')
        print(f'== resumo: convertidos/juntados={c.ok}  ignorados={c.skip}  erros={c.err}  apagados={c.deleted}')
    finally:
        shutil.rmtree(c.work, ignore_errors=True)
    sys.exit(1 if c.err else 0)


if __name__ == '__main__':
    main()
