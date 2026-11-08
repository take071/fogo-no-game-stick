#!/usr/bin/env bash
# Max RSS per session (one "hook" line = one session) from timer/hook.log.
# Usage: SD=/run/media/user/<LABEL> ./per_session.sh
set -u
: "${SD:?set SD}"
cd "$SD/timer" || exit 1
awk '
/^hook /{ if (g!="" && n>0) printf "%-50s samples=%d rss_max=%.0f MB\n", g, n, m/1024; g=$0; sub(/.*\/sdcard\/game\//,"",g); n=0; m=0; next }
/^\[(ps1 )?amostra\]/ && match($0,/rss=[0-9]+/) { r=substr($0,RSTART+4,RLENGTH-4)+0; if (r>=30000) { n++; if (r>m) m=r } }
END { if (n>0) printf "%-50s samples=%d rss_max=%.0f MB\n", g, n, m/1024 }
' hook.log
