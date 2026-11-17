#!/bin/sh
L=/sdcard/timer/hook.log
C=/sys/devices/system/cpu/cpu0/cpufreq
echo "[cpu antes] gov=$(cat $C/scaling_governor 2>&1) cur=$(cat $C/scaling_cur_freq 2>&1) min=$(cat $C/scaling_min_freq 2>&1) max=$(cat $C/scaling_max_freq 2>&1) hwmax=$(cat $C/cpuinfo_max_freq 2>&1) disp=$(cat $C/scaling_available_frequencies 2>&1) govs=$(cat $C/scaling_available_governors 2>&1)" >> $L
MAX=$(cat $C/scaling_max_freq 2>/dev/null)
echo "[cpu depois] gov=$(cat $C/scaling_governor 2>&1) cur=$(cat $C/scaling_cur_freq 2>&1) min=$(cat $C/scaling_min_freq 2>&1) max=$(cat $C/scaling_max_freq 2>&1)" >> $L
for d in /sys/class/devfreq/*; do
  [ -d "$d" ] || continue
  echo "[devfreq antes] $d gov=$(cat $d/governor 2>&1) cur=$(cat $d/cur_freq 2>&1) avail=$(cat $d/available_frequencies 2>&1)" >> $L
  echo "[devfreq depois] $d gov=$(cat $d/governor 2>&1) cur=$(cat $d/cur_freq 2>&1)" >> $L
done
echo "[inicio] nucleos=$(grep -c ^processor /proc/cpuinfo) jogo=$(for a in "$@"; do :; done; echo "$a")" >> $L
(
  sleep 3
  PREV=0
  while P=$(pidof retroarch) && [ -n "$P" ]; do
    set -- $(cut -d' ' -f14,15 /proc/$P/stat 2>/dev/null)
    T=$(( ${1:-0} + ${2:-0} ))
    D=$(( T - PREV )); PREV=$T
    echo "[amostra] up=$(cut -d' ' -f1 /proc/uptime) dtick=$D freq=$(cat $C/scaling_cur_freq 2>&1) livre=$(grep MemFree /proc/meminfo | tr -s ' ' | cut -d' ' -f2) rss=$(grep VmRSS /proc/$P/status 2>/dev/null | tr -s ' ' | cut -d' ' -f2)" >> $L
    sleep 5
  done
  echo "[fim amostras]" >> $L
) &
for p in /proc/[0-9]*; do r=$(grep VmRSS $p/status 2>/dev/null | tr -s " " | cut -d" " -f2); [ -n "$r" ] && echo "[proc] $r kB $(cat $p/comm 2>/dev/null)" >> $L; done
# smaps_ini
(
  G=$(for a in "$@"; do :; done; echo "$a")
  for t in 1 2 3 4 5 6 7 8; do
    sleep 15
    PID=$(pidof retroarch | awk '{print $1}')
    [ -z "$PID" ] && break
    {
      echo "=== $G amostra $t (up=$(cut -d' ' -f1 /proc/uptime)) ==="
      grep -E "^(MemFree|MemAvailable|Cached|AnonPages|Mapped):" /proc/meminfo
      grep -E "^(VmRSS|RssAnon|RssFile):" /proc/$PID/status
      awk '/^[0-9a-f]+-[0-9a-f]+ /{n=$6; if(n=="")n="[anon]"} /^Rss:/{a[n]+=$2} END{for(k in a) print a[k], k}' /proc/$PID/smaps | sort -rn | head -8
    } >> /sdcard/timer/smaps_log.txt
  done
) &
# smaps_fim
/usr/bin/retroarch "$@"
rc=$?
echo "[retroarch saiu rc=$rc]" >> $L
exit $rc
