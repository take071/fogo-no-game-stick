#!/usr/bin/env python3
"""Convert PS1 games (.cue/.bin or .chd) to .PBP for the Game Stick, merging multi-disc
games into ONE multi-disc PBP.  Python twin of convert_ps1.sh (same options, same behaviour).

Usage:
  python3 scripts/ps1/ps1_pbp.py [FOLDER] [options]
    FOLDER = folder with the PS1 games (searched recursively). If omitted, uses $SD/game/ps1.
  PSX is found automatically (~/Downloads/psxpackager/psxpackager-linux-x64/psxpackager or
  `psxpackager` in PATH); otherwise set PSX=/path/to/psxpackager (or --psx).

  --dry-run        only print what would happen, change nothing
  --delete         after a VALID .PBP exists, delete the originals (.cue/.bin/.chd and the
                   single-disc PBPs that were merged). PERMANENT: test the PBPs first.
  --no-merge       do not merge discs; convert every disc to its own PBP
  --force-partial  merge even if disc numbers are not contiguous (e.g. only discs 1 and 3)
  --level N        PBP compression level 0-9 (default 5)
  --sd / --psx / --chdman / --tmp   override SD / PSX / CHDMAN / PSX_TMP

.chd sources need `chdman` (Fedora: sudo dnf install mame-tools) because PSXPackager 1.6.x
cannot read CHD.  Needs only the Python standard library.

NOTE (PSXPackager 1.6.2, measured): "-x" means "overwrite", NOT "extract". Extraction needs no
flag: a .pbp given to -i is extracted to .bin/.cue (and "-d 1,2" picks discs).
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
# surrogateescape keeps every byte of a file name / .cue exactly as it is (UTF-8 or not)
ENC = dict(encoding='utf-8', errors='surrogateescape', newline='')
FILE_RE = re.compile(r'^(\s*FILE\s+")([^"\r\n]+)(".*)$', re.M | re.I)
DISC_RE = re.compile(
    r'^(?P<pre>.*[^\s_-])?[\s_-]*[(\[](?:disc|disco|disk|cd)\s*(?P<n>\d+)'
    r'(?:\s*(?:of|de)\s*\d+)?[)\]](?P<post>.*)$', re.I)


class Ctx:
    """Run-wide settings and counters."""
    def __init__(self, a):
        self.dry, self.delete, self.merge = a.dry_run, a.delete, not a.no_merge
        self.force, self.level = a.force_partial, a.level
        self.psx, self.chdman, self.work = a.psx, a.chdman, Path(a.work)
        self.ok = self.skip = self.err = self.deleted = 0


def protected(name):
    n = name.lower()
    return 'scph' in n or 'bios' in n


def valid_pbp(p):
    """Non-empty AND starts with the PBP magic (00 'P' 'B' 'P')."""
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
    """Run psxpackager; returns (rc, combined output)."""
    p = subprocess.run([c.psx] + args, stdin=subprocess.DEVNULL,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return p.returncode, p.stdout.decode('utf-8', 'replace')


def rm_file(c, p):
    p = Path(p)
    if c.dry:
        print(f'  [would delete] {p.name}')
        return
    try:
        p.unlink()
        print(f'  [deleted] {p.name}')
        c.deleted += 1
    except OSError as e:
        print(f'  [ERROR] cannot delete {p.name}: {e}')


# 1) fix FILE lines that point to a .bin that does not exist ---------------------------
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
        cand = next((b for b in bins if b.lower() == name.lower()), None)      # (a) case only
        if cand is None and nfile == 1:                                         # (b)/(c) single-FILE cues
            cand = next((b for b in bins if Path(b).stem.lower() == base.lower()), None)
            if cand is None and len(bins) == 1:
                cand = bins[0]
        if cand:
            print(f'[fix] {cue.name}: {name} -> {cand}')
            changed.append(1)
            return f'{m.group(1)}{cand}{m.group(3)}'
        print(f"[NO BIN] {cue.name} (references '{name}')")
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


# helpers that touch psxpackager / chdman ------------------------------------------------
def prep_source(c, typ, path, tag):
    """Returns the .cue to feed psxpackager (extracting .chd / .pbp first) or None."""
    if typ == 'cue':
        return path
    dd = c.work / tag
    dd.mkdir(parents=True, exist_ok=True)
    if typ == 'chd':
        if not shutil.which(c.chdman):
            print(f'[chd] {path}: PSXPackager cannot read .chd and chdman was not found; install mame-tools or run: '
                  f'chdman extractcd -i "{path}" -o "{path.with_suffix(".cue")}" -ob "{path.with_suffix(".bin")}"')
            return None
        r = subprocess.run([c.chdman, 'extractcd', '-i', str(path), '-o', str(dd / 'disc.cue'),
                            '-ob', str(dd / 'disc.bin')], stdout=subprocess.DEVNULL)
        if r.returncode != 0:
            print(f'[ERROR] chdman failed on {path}')
            return None
        return dd / 'disc.cue'
    rc, out = run_psx(c, ['-i', str(path), '-o', str(dd), '-x', '-v', '1'])   # .pbp: no flag needed
    cues = sorted(dd.glob('*.cue')) + sorted(dd.glob('*.CUE'))
    if rc != 0 or not cues:
        print(f'[ERROR] extraction failed: {path}')
        print('    ' + out.strip().replace('\n', '\n    '))
        return None
    return cues[0]


def pack(c, inp, final):
    """psxpackager on a .cue/.m3u, then move the PBP to `final` only if it is valid."""
    out = Path(tempfile.mkdtemp(prefix='out.', dir=c.work))
    rc, log = run_psx(c, ['-i', str(inp), '-o', str(out), '-l', str(c.level), '-x', '-v', '1'])
    produced = next(iter(sorted(out.glob('*.[pP][bB][pP]'))), None)
    if rc != 0 or produced is None or not valid_pbp(produced):
        print(f'[ERROR] no valid PBP produced: {final.name}')
        print('    ' + log.strip().replace('\n', '\n    '))
        shutil.rmtree(out, ignore_errors=True)
        return False
    part = final.with_name(final.name + '.part')
    try:
        shutil.copyfile(produced, part)
        os.replace(part, final)
    except OSError as e:
        print(f'[ERROR] cannot write {final}: {e}')
        part.unlink(missing_ok=True)
        shutil.rmtree(out, ignore_errors=True)
        return False
    shutil.rmtree(out, ignore_errors=True)
    return valid_pbp(final)


def verify_discs(c, final, n):
    """Real check before deleting: extract the LAST disc of the merged PBP.
    Measured: a multi-disc PBP extracts as '<name> - Disc N.cue'; a SINGLE-disc PBP ignores
    '-d 2' and extracts its only disc without that suffix."""
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
    """Keep the Disc 1 cover as the merged game's cover."""
    if any((d / (key + e)).exists() for e in IMG_EXT):
        return
    for e in IMG_EXT:
        for ee in (e, e.upper()):
            src = d / (first + ee)
            if src.is_file():
                print(f'  [cover] {src.name} -> {key}{ee}')
                if not c.dry:
                    shutil.copyfile(src, d / (key + ee))
                return


def free_kb(path):
    st = os.statvfs(path)
    return st.f_bavail * st.f_frsize // 1024


# per-game logic ---------------------------------------------------------------------------
def convert_single(c, d, base, typ, path):
    final = d / (base + '.PBP')
    ex = existing_pbp(d / base)
    if ex and valid_pbp(ex):
        print(f'[skip] {base} (PBP exists)')
        c.skip += 1
        if c.delete:
            delete_sources(c, [(typ, path)])
        return
    print(f'[conv] {base}')
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
        print(f'[keep] originals of {base} kept (no valid PBP)')


def merge_group(c, d, key, best):
    nums = sorted(best)
    total = len(nums)
    if nums != list(range(1, total + 1)) and not c.force:
        print(f'[WARN] {key}: discs found: {" ".join(map(str, nums))} (not 1..{total}). '
              f'Not merged. Use --force-partial to merge anyway.')
        c.skip += 1
        return
    srcs = [best[n] for n in nums]                      # (type, path)
    bases = [p.stem for _, p in srcs]
    ex = existing_pbp(d / key)
    if ex and valid_pbp(ex):
        print(f'[skip] {key} (merged PBP exists)')
        c.skip += 1
        if c.delete:
            if c.dry or verify_discs(c, ex, total):
                delete_sources(c, srcs)
                delete_disc_covers(c, d, bases)
            else:
                print(f'[keep] {key}.PBP does not contain {total} discs; originals kept')
        return

    print(f'[merge] {key} ({total} discs: {" ".join(map(str, nums))})')
    for n in nums:
        print(f'  disc {n} <- {best[n][1].name} ({best[n][0]})')
    if c.dry:
        move_cover(c, d, key, bases[0])
        return

    need = 0                                           # KB of work space needed
    for typ, p in srcs:
        if typ == 'cue':
            need += sum((p.parent / f).stat().st_size // 1024 for f in cue_files(p) if (p.parent / f).is_file())
        else:
            need += p.stat().st_size // 1024 * 3
    if free_kb(c.work) < need:
        print(f'[ERROR] {key}: needs ~{need // 1024} MB in {c.work}, only {free_kb(c.work) // 1024} MB free (set --tmp)')
        c.err += 1
        return

    m3u = c.work / f'{key}.m3u'
    lines = []
    for n in nums:
        cue = prep_source(c, best[n][0], best[n][1], f'd{n}.{os.getpid()}.{abs(hash(key)) % 10**6}')
        if cue is None:
            print(f'[ERROR] {key}: disc {n} failed')
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
                print(f'[keep] {key}.PBP failed the {total}-disc check; originals kept')
    else:
        c.err += 1
        print(f'[keep] originals of {key} kept (no valid PBP)')
    m3u.unlink(missing_ok=True)


PRI = {'cue': 3, 'chd': 2, 'pbp': 1}


def process_dir(c, d):
    files = sorted(f for f in d.iterdir() if f.is_file() and not f.name.startswith('.'))
    has_cue = {f.stem for f in files if f.suffix.lower() == '.cue'}
    groups = {}                                         # key -> {n: (type, path)}
    for f in files:
        typ = f.suffix.lower().lstrip('.')
        if typ not in PRI:
            continue
        if protected(f.stem):
            print(f'[bios] ignored {f.name}')
            continue
        if typ == 'chd' and f.stem in has_cue:           # .cue wins over .chd
            continue
        dp = disc_parse(f.stem)
        if dp:
            n, key = dp
        else:
            if typ == 'pbp':                              # a final single PBP: nothing to do
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
    ap = argparse.ArgumentParser(description='Convert PS1 games to PBP, merging multi-disc games.')
    ap.add_argument('folder', nargs='?', help='folder with the PS1 games (default: $SD/game/ps1)')
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
        sys.exit('Give the games FOLDER as argument, or set SD=/run/media/user/<LABEL>')
    if not root.is_dir():
        sys.exit(f'[error] folder not found: {root}')
    if not a.psx:
        for cand in (Path.home() / 'Downloads/psxpackager/psxpackager-linux-x64/psxpackager',
                     shutil.which('psxpackager')):
            if cand and os.access(cand, os.X_OK):
                a.psx = str(cand)
                break
    if not a.psx:
        sys.exit('psxpackager not found: set PSX=/path/to/psxpackager (or --psx)')
    if not os.access(a.psx, os.X_OK):
        sys.exit(f'[error] {a.psx} is not executable')
    Path(a.tmp).mkdir(parents=True, exist_ok=True)
    a.work = tempfile.mkdtemp(prefix='run.', dir=a.tmp)
    if Path(a.work).resolve().is_relative_to(root.resolve()):
        sys.exit('[error] --tmp must not be inside the games folder')
    c = Ctx(a)
    try:
        print(f'Folder: {root}  [dry-run={int(c.dry)} delete={int(c.delete)} merge={int(c.merge)}]')
        dirs = [Path(r) for r, ds, _ in os.walk(root)
                if not any(p.startswith('.') for p in Path(r).relative_to(root).parts)]
        for d in sorted(dirs):                                       # step 1: fix all .cue files
            for f in sorted(d.iterdir()):
                if f.is_file() and f.suffix.lower() == '.cue' and not f.name.startswith('.'):
                    fix_cue(c, f)
        for d in sorted(dirs):                                       # step 2: convert / merge
            process_dir(c, d)
        if not c.dry:                                                # step 3: normalise extension
            for d in dirs:
                for f in d.iterdir():
                    if f.is_file() and f.suffix == '.pbp' and not f.name.startswith('.'):
                        tmp = f.with_suffix('.tmp_ren')
                        f.rename(tmp)
                        tmp.rename(f.with_suffix('.PBP'))
        if not c.delete:
            print('[info] originals kept (use --delete to remove them after testing the PBPs)')
        print(f'== summary: converted/merged={c.ok}  skipped={c.skip}  errors={c.err}  deleted={c.deleted}')
    finally:
        shutil.rmtree(c.work, ignore_errors=True)
    sys.exit(1 if c.err else 0)


if __name__ == '__main__':
    main()
