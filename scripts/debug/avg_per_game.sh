#!/usr/bin/env bash
# Average RAM/CPU per game from timer/hook.log (samples every 5 s).
# dtick in 5 s: ~500 = one full core, so CPU% = dtick/5. Samples with rss < 30 MB are ignored.
# CAVEAT: samples are attributed to the last "hook" line read; this mis-attributes
# some PK GS samples (see docs, "attribution problem").
# Usage: SD=/run/media/user/<LABEL> ./avg_per_game.sh
set -u
: "${SD:?set SD}"
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
END { for (g in n) printf "%-45s samples=%d  rss_avg=%.0f MB  rss_max=%.0f MB  peak=%.0f MB  free_min=%.1f MB  cpu_avg=%.0f%%\n", g, n[g], sr[g]/n[g]/1024, mr[g]/1024, mp[g]/1024, ml[g]/1024, (nd[g]? sd[g]/nd[g]/5 : 0) }
' hook.log | sort
