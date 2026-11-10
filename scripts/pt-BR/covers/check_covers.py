#!/usr/bin/env python3
"""Lista os jogos sem imagem de capa (.png/.jpg/.jpeg com o mesmo nome-base).

Uso: SD=/run/media/user/<LABEL> python3 check_covers.py
"""
import os, sys
SD = os.environ.get('SD')
if not SD:
    sys.exit('Defina SD=/run/media/user/<LABEL>')
R = os.path.join(SD, 'game')
EXT = {'.nes','.gb','.gbc','.gba','.sfc','.smc','.n64','.z64','.v64','.md','.smd','.gen',
       '.32x','.sms','.gg','.pbp','.cue','.chd','.a26','.a52','.a78','.zip','.7z'}
missing = total = 0
for d, _, files in sorted(os.walk(R)):
    low = {f.lower() for f in files}
    bases = {os.path.splitext(f)[0] for f in files
             if os.path.splitext(f)[1].lower() in EXT
             and 'bios' not in f.lower() and 'scph' not in f.lower()}
    for b in sorted(bases):
        total += 1
        if not any(b.lower() + e in low for e in ('.png', '.jpg', '.jpeg')):
            missing += 1
            print('[SEM CAPA]', os.path.relpath(os.path.join(d, b), R))
print(f'\n{total} jogos conferidos, {missing} sem capa')
