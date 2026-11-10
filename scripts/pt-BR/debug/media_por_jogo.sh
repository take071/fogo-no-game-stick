#!/usr/bin/env bash
# Média de RAM/CPU por jogo a partir do timer/hook.log (amostras a cada 5 s).
# dtick em 5 s: ~500 = um núcleo inteiro, então CPU% = dtick/5. Amostras com rss < 30 MB são ignoradas.
# ATENÇÃO: as amostras são atribuídas ao último "hook" lido; isso atribui errado
# algumas amostras do PK GS (veja os docs, "problema de atribuição").
# Uso: SD=/run/media/user/<LABEL> ./media_por_jogo.sh
set -u
: "${SD:?defina SD}"
cd "$SD/timer" || exit 1
awk '
function v(k,   m){ if (match($0, k"=[0-9]+")) return substr($0, RSTART+length(k)+1, RLENGTH-length(k)-1)+0; return -1 }
/^hook /{ if ($0 ~ /Timer/) g=""; else { g=$0; sub(/.*\/sdcard\/game\//,"",g) } next }
/^\[(ps1 )?amostra\]/ && g!="" {
  r=v("rss"); l=v("livre"); d=v("dtick"); p=v("pico")
  if (r < 30000) next
  n[g]++; sr[g]+=r; if (r>mr[g]) mr[g]=r
  if (p>mp[g]) mp[g]=p
  if (!(g in ml) || l<ml[g]) ml[g]=l
  if (d>0) { nd[g]++; sd[g]+=d }
}
END { for (g in n) printf "%-45s amostras=%d  rss_med=%.0f MB  rss_max=%.0f MB  pico=%.0f MB  livre_min=%.1f MB  cpu_med=%.0f%%\n", g, n[g], sr[g]/n[g]/1024, mr[g]/1024, mp[g]/1024, ml[g]/1024, (nd[g]? sd[g]/nd[g]/5 : 0) }
' hook.log | sort
