#!/usr/bin/env python3
"""Checks the docs and the script twins (no network, no ROMs). Usage: python3 tests/check_docs.py
  1. no broken relative link in any .md file
  2. docs/pt-BR and docs/en have the same chapters (same chapter numbers, same count per number)
  3. every script listed in scripts/pt-BR/LEIA-ME.md exists in both the Portuguese and English trees
"""
import glob, os, re, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)
errors = []

for md in sorted(glob.glob('**/*.md', recursive=True)):
    txt = re.sub(r'```.*?```', '', open(md, encoding='utf-8', errors='replace').read(), flags=re.S)
    for m in re.finditer(r'\[[^\]]*\]\(([^)\s]+)\)', txt):
        t = m.group(1)
        if re.match(r'^(https?:|mailto:|#)', t):
            continue
        t = t.split('#')[0]
        if t and not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(md), t))):
            errors.append(f'broken link: {md} -> {t}')

def chapters(lang):
    out = {}
    for f in glob.glob(f'docs/{lang}/*.md'):
        m = re.match(r'(\d\d)-', os.path.basename(f))
        if m:
            out[m.group(1)] = out.get(m.group(1), 0) + 1
    return out
pt, en = chapters('pt-BR'), chapters('en')
for n in sorted(set(pt) | set(en)):
    if pt.get(n, 0) != en.get(n, 0):
        errors.append(f'chapter {n}: {pt.get(n, 0)} file(s) in pt-BR vs {en.get(n, 0)} in en')

for line in open('scripts/pt-BR/LEIA-ME.md', encoding='utf-8'):
    m = re.match(r'^\| `([\w./-]+/[\w.-]+)` \| `([\w./-]+/[\w.-]+)`', line)
    if m:
        for path in (os.path.join('scripts/pt-BR', m.group(1)), os.path.join('scripts', m.group(2))):
            if not os.path.isfile(path):
                errors.append(f'LEIA-ME lists a missing script: {path}')

for e in errors:
    print('  FAIL -', e)
print(f'RESULT: {"OK" if not errors else str(len(errors)) + " problem(s)"}')
sys.exit(1 if errors else 0)
