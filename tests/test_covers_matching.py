#!/usr/bin/env python3
"""Offline tests for the title matching of scripts/covers/capas_gamestick.py (no network).
Usage: python3 tests/test_covers_matching.py
"""
import collections, importlib.util, os, sys

here = os.path.dirname(os.path.abspath(__file__))
sub = os.path.join('pt-BR', 'covers') if os.environ.get('IMPL') == 'pt' else 'covers'   # IMPL=pt tests the pt-BR twin
spec = importlib.util.spec_from_file_location('capas', os.path.join(here, '..', 'scripts', sub, 'capas_gamestick.py'))
capas = importlib.util.module_from_spec(spec); spec.loader.exec_module(capas)

# libretro-thumbnails writes '&' as '_' in file names
NAMES = ['Mega Man _ Bass (USA)', 'Mother 1 _ 2 (Japan)', 'Legend of Zelda, The - A Link to the Past (USA)',
         'Pokemon - Fire Red Version (USA, Europe) (Rev 1)', 'Metroid Fusion (USA) (Beta)', 'Metroid Fusion (USA)',
         'Metroid Fusion (Europe)', "A Bug's Life (USA)", 'Final Fantasy VII (USA) (Disc 1)']
idx = collections.defaultdict(list)
for n in NAMES:
    idx[capas.norm(n)].append(n)
capas._idx['LIB'] = idx
find = lambda t: (capas.achar(t, ['LIB']) or (None, None))[1]

PASS = FAIL = 0
def ok(desc, cond):
    global PASS, FAIL
    if cond: PASS += 1; print('  ok   -', desc)
    else: FAIL += 1; print('  FAIL -', desc)

ok('"Mega Man & Bass" finds the "_" name (old bug lost it)', find('Mega Man & Bass') == 'Mega Man _ Bass (USA)')
ok('"Mother 1 & 2" finds the "_" name (old bug lost it)', find('Mother 1 & 2') == 'Mother 1 _ 2 (Japan)')
ok('"The Legend of Zelda - A Link..." finds the "Zelda, The - A Link..." name', find('The Legend of Zelda - A Link to the Past') == 'Legend of Zelda, The - A Link to the Past (USA)')
ok('"Legend of Zelda, The - A Link to the Past" exact', find('Legend of Zelda, The - A Link to the Past (USA)') == 'Legend of Zelda, The - A Link to the Past (USA)')
ok('prefers USA over Europe and avoids Beta', find('Metroid Fusion') == 'Metroid Fusion (USA)')
ok('tags/region in the game name are ignored', find("A Bug's Life (Dublado)") == "A Bug's Life (USA)")
ok('disc tag ignored for PS1 multi-disc names', find('Final Fantasy VII (USA) (Disc 2)') == 'Final Fantasy VII (USA) (Disc 1)')
ok('unknown game -> None', find('Totally Unknown Game') is None)
ok('norm drops "and"', capas.norm('Rock and Roll') == capas.norm('Rock & Roll') == capas.norm('Rock _ Roll'))
# --- git symlinks: server returns only the target path (measured: 27 bytes for the FF VII disc 1 name)
PNG = b'\x89PNG\r\n\x1a\n' + b'x' * 50
served = {'Named_Boxarts/Final%20Fantasy%20VII%20%28USA%29%20%28Disc%201%29.png': b'Final Fantasy VII (USA).png',
          'Named_Boxarts/Final%20Fantasy%20VII%20%28USA%29.png': PNG,
          'Named_Boxarts/Loop%20A.png': b'Loop B.png', 'Named_Boxarts/Loop%20B.png': b'Loop A.png'}
capas.get = lambda url, tries=4: served[url.split('/master/')[1]]
ok('symlink (text with target path) is followed to the real image', capas.baixar_boxart('Sony_-_PlayStation', 'Final Fantasy VII (USA) (Disc 1)') == PNG)
ok('a normal PNG is returned as is', capas.baixar_boxart('Sony_-_PlayStation', 'Final Fantasy VII (USA)') == PNG)
try: capas.baixar_boxart('X', 'Loop A'); ok('symlink loop is rejected', False)
except ValueError: ok('symlink loop is rejected (no infinite loop)', True)
print(f'\nRESULT: {PASS} passed, {FAIL} failed'); sys.exit(1 if FAIL else 0)
