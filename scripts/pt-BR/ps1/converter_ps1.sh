#!/usr/bin/env bash
# Converte jogos de PS1 em CUE/BIN para .PBP para o Game Stick (o .chd precisa ser extraído antes).
#
# Uso:
#   SD=/run/media/user/<LABEL> PSX=/caminho/do/psxpackager ./converter_ps1.sh [--dry-run] [--delete]
#
#   --dry-run  só mostra o que faria, não altera nada
#   --delete   depois que existir um .PBP VÁLIDO, apaga o .cue/.bin/.chd original
#              (definitivo! teste os PBPs no stick antes). Padrão: manter os originais.
#
# Etapas: 1) corrige as linhas FILE do .cue  2) converte  3) padroniza a extensão para .PBP
#         4) (opcional) apaga os originais. BIOS (scph*/bios*) nunca é apagada.
set -u
DRY=0; DELETE=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --delete)  DELETE=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "opção desconhecida: $a"; exit 1 ;;
  esac
done
: "${SD:?Defina SD com o ponto de montagem da partição de dados, ex.: SD=/run/media/user/<LABEL>}"
: "${PSX:?Defina PSX com o binário do psxpackager, ex.: PSX=\$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager}"
D="$SD/game/ps1"
[ -d "$D" ] || { echo "[erro] $D não encontrado"; exit 1; }
[ -x "$PSX" ] || { echo "[erro] $PSX não é executável"; exit 1; }
cd "$D" || exit 1

# 1) corrige as referências a .bin dentro dos .cue (nome diferente era a causa de
#    "Could not find file '...bin'" no PSXPackager). Casamento conservador e
#    seguro para UTF-8: um .cue correto com acentos nunca é regravado.
python3 - "$D" "$DRY" <<'EOF'
import os, re, sys
D, DRY = sys.argv[1], sys.argv[2] == '1'
# Lê/grava o .cue como UTF-8 com surrogateescape: os bytes são preservados exatamente
# e os nomes batem com os nomes reais no disco (acentos como "Pokémon" ficam intactos).
ENC = dict(encoding='utf-8', errors='surrogateescape', newline='')
pat = re.compile(r'^(\s*FILE\s+)"([^"]+)"(.*)$', re.M)
for root, _, files in os.walk(D):
    bins = [f for f in files if f.lower().endswith('.bin')]
    for cue in [f for f in files if f.lower().endswith('.cue')]:
        p = os.path.join(root, cue)
        txt = open(p, **ENC).read()
        n_files = len(pat.findall(txt))
        changed = False
        def fix(m):
            global changed
            name = m.group(2)
            if os.path.exists(os.path.join(root, name)):
                return m.group(0)
            # conservador: mesmo nome ignorando maiúsculas ...
            cand = [b for b in bins if b.lower() == name.lower()]
            # ... ou, só num .cue com um único FILE: o .bin com o nome-base do .cue
            # ou o único .bin da pasta (sem casamento por similaridade: poderia ligar
            # vários FILE ao mesmo .bin)
            if not cand and n_files == 1:
                base = os.path.splitext(cue)[0].lower()
                cand = [b for b in bins if os.path.splitext(b)[0].lower() == base]
                if not cand and len(bins) == 1:
                    cand = bins
            if len(cand) == 1:
                print(f'[corrigido] {cue}: {name} -> {cand[0]}')
                changed = True
                return f'{m.group(1)}"{cand[0]}"{m.group(3)}'
            print(f'[SEM BIN] {cue}')
            return m.group(0)
        new = pat.sub(fix, txt)
        if changed and not DRY:
            open(p, 'w', **ENC).write(new)
EOF

# 2) converte tudo que ainda não tem PBP
find . -type f \( -iname '*.cue' -o -iname '*.chd' \) -print0 | while IFS= read -r -d '' f; do
  b="${f%.*}"
  if [ -f "$b.PBP" ] || [ -f "$b.pbp" ]; then echo "[pular] $f"; continue; fi
  case "$f" in
    *.[cC][hH][dD])
      # O PSXPackager 1.6.2 NÃO lê .chd (medido): extraia para .cue/.bin antes
      echo "[chd] $f: o PSXPackager não suporta; rode: chdman extractcd -i \"$f\" -o \"$b.cue\" -ob \"$b.bin\""
      continue ;;
  esac
  echo "[converter] $f"
  [ "$DRY" = 1 ] && continue
  "$PSX" -i "$f" -o "$(dirname "$f")" || echo "[ERRO] $f"
done

# 3) padroniza a extensão para .PBP (o exFAT ignora maiúsculas, então passa por um nome temporário)
if [ "$DRY" = 0 ]; then
  find . -type f -name '*.pbp' -print0 | while IFS= read -r -d '' f; do
    b="${f%.pbp}"; mv -- "$f" "$b.tmp_ren" && mv -- "$b.tmp_ren" "$b.PBP"
  done
fi

# 4) apaga os originais SÓ de jogos que têm um PBP não vazio (opcional)
if [ "$DELETE" = 1 ]; then
python3 - "$D" "$DRY" <<'EOF'
import os, re, sys
D, DRY = sys.argv[1], sys.argv[2] == '1'
def protected(n):
    n = n.lower(); return 'scph' in n or 'bios' in n
def rm(p):
    print('[apagar]' if not DRY else '[apagaria]', os.path.basename(p))
    if not DRY: os.remove(p)
for root, _, files in os.walk(D):
    for f in files:
        if not f.lower().endswith(('.cue', '.chd')): continue
        base = os.path.join(root, f.rsplit('.', 1)[0])
        if not (os.path.isfile(base + '.PBP') and os.path.getsize(base + '.PBP') > 0):
            print('[manter, sem PBP]', f); continue
        p = os.path.join(root, f)
        if f.lower().endswith('.cue'):
            txt = open(p, encoding='utf-8', errors='surrogateescape').read()
            for n in re.findall(r'^\s*FILE\s+"([^"]+)"', txt, re.M | re.I):
                b = os.path.join(root, n)
                if os.path.isfile(b) and not protected(n): rm(b)
        rm(p)
EOF
else
  echo "[info] originais mantidos (use --delete para removê-los depois de testar os PBPs)"
fi
sync
ls -lh "$D"
