#!/usr/bin/env python3
"""Generate a tiny synthetic PS1 disc (BIN MODE2/2352 + CUE) for tests. No copyrighted data.

Usage: make_fake_disc.py "<output base name>" SLUS_000.01
Needs: pip install pycdlib
"""
import sys, io, pycdlib
out_base, gid = sys.argv[1], sys.argv[2]          # ex.: "Jogo (Disc 1)" SLUS_000.01
iso = pycdlib.PyCdlib(); iso.new(interchange_level=1, sys_ident='PLAYSTATION', vol_ident=gid.replace('.', '')[:8])
cnf = f'BOOT = cdrom:\\{gid};1\r\nTCB = 4\r\nEVENT = 10\r\nSTACK = 801FFF00\r\n'.encode()
iso.add_fp(io.BytesIO(cnf), len(cnf), '/SYSTEM.CNF;1')
exe = b'PS-X EXE' + b'\0' * 2040 + b'\xAA' * 4096
iso.add_fp(io.BytesIO(exe), len(exe), f'/{gid.replace(".", "_")[:8]}.;1')
buf = io.BytesIO(); iso.write_fp(buf); iso.close()
data = buf.getvalue()
data += b'\0' * ((-len(data)) % 2048)
sync = bytes([0]) + bytes([0xFF]) * 10 + bytes([0])
raw = bytearray()
n = len(data) // 2048
total = max(n, 300)                                  # >= ~4 s
for lba in range(total):
    sec = data[lba*2048:(lba+1)*2048] if lba < n else b'\0' * 2048
    m, s, f = ((lba + 150) // 75 // 60, (lba + 150) // 75 % 60, (lba + 150) % 75)
    bcd = lambda x: ((x // 10) << 4) | (x % 10)
    hdr = sync + bytes([bcd(m), bcd(s), bcd(f), 2])
    sub = bytes([0, 0, 8, 0]) * 2
    body = sub + sec
    raw += hdr + body + b'\0' * 280                  # EDC/ECC fake
open(out_base + '.bin', 'wb').write(raw)
import os
open(out_base + '.cue', 'w', encoding='utf-8').write(
    f'FILE "{os.path.basename(out_base)}.bin" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n')
print('ok', out_base, len(raw))
