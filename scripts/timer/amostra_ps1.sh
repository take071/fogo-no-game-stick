#!/bin/sh
L=/sdcard/timer/hook.log
J="$1"
echo "[ps1 inicio] jogo=$J livre=$(grep MemFree /proc/meminfo | tr -s ' ' | cut -d' ' -f2)" >> $L
i=0; P=
while [ $i -lt 60 ]; do P=$(pidof retroarch); [ -n "$P" ] && break; i=$((i+1)); sleep 1; done
[ -z "$P" ] && { echo "[ps1] retroarch nao apareceu em 60s" >> $L; exit 0; }
PREV=0
while P=$(pidof retroarch) && [ -n "$P" ]; do
  set -- $(cut -d' ' -f14,15 /proc/$P/stat 2>/dev/null)
  T=$(( ${1:-0} + ${2:-0} )); D=$(( T - PREV )); PREV=$T
  echo "[ps1 amostra] up=$(cut -d' ' -f1 /proc/uptime) dtick=$D livre=$(grep MemFree /proc/meminfo | tr -s ' ' | cut -d' ' -f2) rss=$(grep VmRSS /proc/$P/status 2>/dev/null | tr -s ' ' | cut -d' ' -f2) pico=$(grep VmHWM /proc/$P/status 2>/dev/null | tr -s ' ' | cut -d' ' -f2)" >> $L
  sleep 5
done
echo "[ps1 fim]" >> $L
