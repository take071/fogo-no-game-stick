#!/usr/bin/env bash
# RSS máximo por sessão (uma linha "hook" = uma sessão) a partir do timer/hook.log.
# Uso: SD=/run/media/user/<LABEL> ./por_sessao.sh
set -u
: "${SD:?defina SD}"
cd "$SD/timer" || exit 1
awk '
/^hook /{ if (g!="" && n>0) printf "%-50s amostras=%d rss_max=%.0f MB\n", g, n, m/1024; g=$0; sub(/.*\/sdcard\/game\//,"",g); n=0; m=0; next }
/^\[(ps1 )?amostra\]/ && match($0,/rss=[0-9]+/) { r=substr($0,RSTART+4,RLENGTH-4)+0; if (r>=30000) { n++; if (r>m) m=r } }
END { if (n>0) printf "%-50s amostras=%d rss_max=%.0f MB\n", g, n, m/1024 }
' hook.log
