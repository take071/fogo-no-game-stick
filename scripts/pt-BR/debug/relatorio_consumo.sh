#!/usr/bin/env bash
# Gera o relatório de consumo (docs/pt-BR/08-consumo-medido.md e docs/en/08-measured-consumption.md)
# a partir do timer/hook.log do cartão. Também confere a integridade do arquivo de opções
# do core e mostra o estado atual da Enhanced Resolution (NEON). SÓ LEITURA no cartão.
#
# Uso:
#   SD=/run/media/user/<LABEL> ./relatorio_consumo.sh [--lang pt|en|both]    (padrão: pt)
# Opcional: OUT=/outra/pasta (padrão: a raiz do repositório, onde fica docs/)
#
# Mesmos cuidados do media_por_jogo.sh: as amostras são atribuídas ao último "hook" lido,
# e dtick em 5 s ~500 = um núcleo inteiro (CPU% = dtick/5). Amostras com rss < 30 MB são ignoradas.
set -u
: "${SD:?defina SD com o ponto de montagem do cartão}"
LANG_OUT=pt
[ "${1:-}" = "--lang" ] && LANG_OUT="${2:?pt|en|both}"
case "$LANG_OUT" in pt|en|both) ;; *) echo "use --lang pt|en|both"; exit 1 ;; esac

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:-}"
if [ -z "$OUT" ]; then
  OUT="$HERE"; while [ "$OUT" != "/" ] && [ ! -d "$OUT/docs" ]; do OUT="$(dirname "$OUT")"; done
  [ -d "$OUT/docs" ] || { echo "[erro] não achei a raiz do repositório (docs/); defina OUT="; exit 1; }
fi
LOG="$SD/timer/hook.log"
OPT="$SD/retro_lib/retroarch-core-options.cfg"
[ -f "$LOG" ] || { echo "[erro] $LOG não encontrado (os medidores precisam ter rodado no stick antes)"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ---------- 1) lê o hook.log ----------
parse() { # $1 = pt|en
awk -v L="$1" '
function v(k,   m){ if (match($0, k"=[0-9]+")) return substr($0, RSTART+length(k)+1, RLENGTH-length(k)-1)+0; return -1 }
function flush(  i){ if (g != "" && n > 0) { ns++; sg[ns]=g; sn[ns]=n; sa[ns]=sr/n/1024; sm[ns]=mr/1024; sp[ns]=mp/1024; sl[ns]=ml/1024; sc[ns]=(nd? sd/nd/5 : 0) } }
/^hook /{ flush(); g=$0; sub(/.*\/sdcard\/game\//,"",g); if ($0 ~ /Timer/) g="";
          n=0; sr=0; mr=0; mp=0; ml=1e12; nd=0; sd=0; next }
/^\[(ps1 )?amostra\]/ && g!="" {
  r=v("rss"); l=v("livre"); d=v("dtick"); p=v("pico")
  if (r < 30000) next
  n++; sr+=r; if (r>mr) mr=r; if (p>mp) mp=p; if (l>=0 && l<ml) ml=l
  if (d>0) { nd++; sd+=d }
}
END {
  flush()
  if (L=="pt") { h1="Jogo"; h2="Sessões"; h3="Amostras"; h4="RAM média"; h5="RAM máx"; h6="Pico"; h7="Menor folga"; h8="CPU média"; h9="Aviso"
                 hs1="Sessão"; hs2="Jogo"; hs3="Amostras"; hs4="RAM máx"; hs5="CPU média"; w="⚠ RAM máx varia >25% entre sessões (possível atribuição errada)"; ok="ok" }
  else           { h1="Game"; h2="Sessions"; h3="Samples"; h4="RAM avg"; h5="RAM max"; h6="Peak"; h7="Min free"; h8="CPU avg"; h9="Note"
                 hs1="Session"; hs2="Game"; hs3="Samples"; hs4="RAM max"; hs5="CPU avg"; w="⚠ RAM max varies >25% across sessions (possible mis-attribution)"; ok="ok" }
  # per game
  for (i=1;i<=ns;i++){ k=sg[i]; if(!(k in gs)){ order[++ng]=k }
    gs[k]++; gn[k]+=sn[i]; gsum[k]+=sa[i]*sn[i]; gcpu[k]+=sc[i]*sn[i]
    if (sm[i]>gmax[k]) gmax[k]=sm[i]; if (sp[i]>gpk[k]) gpk[k]=sp[i]
    if (!(k in gmin) || sm[i]<gmin[k]) gmin[k]=sm[i]
    if (!(k in gfree) || sl[i]<gfree[k]) gfree[k]=sl[i] }
  print "@@GAMES"
  printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n|---|---|---|---|---|---|---|---|---|\n", h1,h2,h3,h4,h5,h6,h7,h8,h9
  for (j=1;j<=ng;j++){ k=order[j]; note=ok
    if (gs[k]>1 && gmax[k] > 1.25*gmin[k]) note=w
    pk = (gpk[k]>0)? sprintf("%.0f MB", gpk[k]) : "n/d"
    printf "| %s | %d | %d | %.0f MB | %.0f MB | %s | %.1f MB | %.0f%% | %s |\n", k, gs[k], gn[k], gsum[k]/gn[k], gmax[k], pk, gfree[k], gcpu[k]/gn[k], note }
  print "@@SESSIONS"
  printf "| %s | %s | %s | %s | %s |\n|---|---|---|---|---|\n", hs1,hs2,hs3,hs4,hs5
  for (i=1;i<=ns;i++) printf "| %d | %s | %d | %.0f MB | %.0f%% |\n", i, sg[i], sn[i], sm[i], sc[i]
  print "@@COUNT " ns " " ng
}' "$LOG"
}

# ---------- 2) arquivo de opções: integridade + NEON ----------
neon_block() { # $1 = pt|en
  local L="$1" f
  if [ ! -f "$OPT" ]; then
    [ "$L" = pt ] && echo "Arquivo \`retro_lib/retroarch-core-options.cfg\` não encontrado no cartão." || echo "File \`retro_lib/retroarch-core-options.cfg\` not found on the card."
    return
  fi
  [ "$L" = pt ] && echo "Estado atual (\`grep neon\`):" || echo "Current state (\`grep neon\`):"
  echo; echo '```'; grep -n 'neon' "$OPT"; echo '```'; echo
  for f in "$OPT.bak_original" "$OPT.bak_pre_neon"; do
    [ -f "$f" ] || continue
    [ "$L" = pt ] && echo "Backup \`$(basename "$f")\`:" || echo "Backup \`$(basename "$f")\`:"
    echo; echo '```'; grep -n 'neon' "$f"; echo '```'; echo
  done
  local bad; bad=$(awk '/^[[:space:]]*$/ || /^[[:space:]]*#/ {next} !/^[A-Za-z0-9_.]+ = ".*"[[:space:]]*$/ {printf "%d: %s\n", NR, $0}' "$OPT")
  if [ -z "$bad" ]; then
    [ "$L" = pt ] && echo "**Integridade [medido]:** todas as linhas seguem o formato \`chave = \"valor\"\` (aspas fechadas)." || echo "**Integrity [measured]:** every line follows the \`key = \"value\"\` format (quotes closed)."
  else
    [ "$L" = pt ] && echo "**Integridade: ⚠ linhas fora do formato \`chave = \"valor\"\`** (linha: conteúdo):" || echo "**Integrity: ⚠ lines outside the \`key = \"value\"\` format** (line: content):"
    echo; echo '```'; echo "$bad"; echo '```'
  fi
}

emit() { # $1 = pt|en ; $2 = output file
  local L="$1" F="$2" P="$TMP/parsed_$1.txt"
  parse "$L" > "$P"
  sed -n '/^@@GAMES/,/^@@SESSIONS/p' "$P" | sed '1d;$d' > "$TMP/games_$L.md"
  [ "$L" = pt ] && sed -i 's/\([0-9]\)\.\([0-9] MB\)/\1,\2/g' "$TMP/games_$L.md"
  sed -n '/^@@SESSIONS/,/^@@COUNT/p' "$P" | sed '1d;$d' > "$TMP/sess_$L.md"
  local CNT; CNT=$(grep '^@@COUNT' "$P")
  neon_block "$L" > "$TMP/neon_$L.md"
  mkdir -p "$(dirname "$F")"
  if [ "$L" = pt ]; then cat > "$F" <<EOT
# 08 · Consumo medido (RAM e CPU por jogo)

[← voltar](../../README.pt-BR.md)

> **Arquivo gerado automaticamente** por \`scripts/debug/consumption_report.sh\` (ou \`scripts/pt-BR/debug/relatorio_consumo.sh\`) a partir do \`timer/hook.log\` do cartão, em $(date +%F). Rode de novo depois de jogar para atualizar. Os números abaixo vêm do log; nada foi escrito à mão.

Como ler: \`RAM\` é o \`rss\` do RetroArch; \`Pico\` é o \`VmHWM\` (só existe nas amostras de PS1); \`Menor folga\` é o menor \`MemFree\` visto; \`CPU média\` é \`dtick/5\` (~100% = um núcleo inteiro). Amostras com \`rss\` < 30 MB são ignoradas. Total: $(echo "$CNT" | awk '{print $2" sessões em "$3" jogos"}').

## Por jogo

$(cat "$TMP/games_$L.md")

## Por sessão (na ordem do log)

$(cat "$TMP/sess_$L.md")

> O log não tem data/hora (o relógio do aparelho está errado), então a ordem é só a da sequência de \`hook\`. Para comparar **Enhanced Resolution ligada × desligada** no mesmo jogo (ex.: Castlevania), anote ao lado de cada sessão de PS1 qual era o estado da opção na hora de jogar.

## Enhanced Resolution do PS1 e integridade do arquivo de opções

$(cat "$TMP/neon_$L.md")

## Limites desta medição

- **Atribuição de amostras:** cada amostra vai para o último \`hook\` lido. Uma sessão marcada com ⚠ pode ter amostras de outro jogo (caso do PK GS, veja o [03](03-graficos-e-consumo.md)). Conferir: abrir **só** o jogo suspeito por ~2 min, sair pelo menu e gerar o relatório de novo.
- \`rss\` pode incluir cache de arquivo mapeado (descartável); só o medidor \`smaps\` separa isso ([05](05-diagnostico-tela-preta-ram.md)).
- Um aparelho, um cartão: não generalize para outros.
EOT
  else cat > "$F" <<EOT
# 08 · Measured consumption (RAM and CPU per game)

[← back](../../README.md)

> **Automatically generated file** by \`scripts/debug/consumption_report.sh\` from the card's \`timer/hook.log\`, on $(date +%F). Run it again after playing to refresh it. The numbers below come from the log; nothing was written by hand.

How to read: \`RAM\` is RetroArch's \`rss\`; \`Peak\` is \`VmHWM\` (only present in PS1 samples); \`Min free\` is the lowest \`MemFree\` seen; \`CPU avg\` is \`dtick/5\` (~100% = one full core). Samples with \`rss\` < 30 MB are ignored. Total: $(echo "$CNT" | awk '{print $2" sessions in "$3" games"}').

## Per game

$(cat "$TMP/games_$L.md")

## Per session (log order)

$(cat "$TMP/sess_$L.md")

> The log has no date/time (the device clock is wrong), so the order is just the \`hook\` sequence. To compare **Enhanced Resolution on × off** on the same game (e.g. Castlevania), write down next to each PS1 session what the option was set to while playing.

## PS1 Enhanced Resolution and option-file integrity

$(cat "$TMP/neon_$L.md")

## Limits of this measurement

- **Sample attribution:** each sample goes to the last \`hook\` line read. A session flagged ⚠ may hold samples from another game (the PK GS case, see [03](03-graphics-and-consumption.md)). To check: open **only** the suspect game for ~2 min, quit through the menu and generate the report again.
- \`rss\` may include mapped-file cache (discardable); only the \`smaps\` meter separates that ([05](05-diagnosis-black-screen-ram.md)).
- One device, one card: do not generalize to others.
EOT
  fi
  echo "[ok] $F"
}

[ "$LANG_OUT" != en ] && emit pt "$OUT/docs/pt-BR/08-consumo-medido.md"
[ "$LANG_OUT" != pt ] && emit en "$OUT/docs/en/08-measured-consumption.md"
echo "Revise o(s) arquivo(s) gerado(s) e depois faça o commit."
