#!/bin/sh
END=$1
echo $$ > /tmp/gtimer.pid
while :; do
  read UP _ < /proc/uptime; UP=${UP%.*}
  LEFT=$((END - UP))
  [ "$LEFT" -le 0 ] && break
  [ "$LEFT" -gt 20 ] && sleep 20 || sleep "$LEFT"
done
rm -f /tmp/gtimer.pid
[ -x /tmp/gtimer ] || { cp /sdcard/timer/gtimer /tmp/gtimer; chmod +x /tmp/gtimer; }
/tmp/gtimer alarm >/dev/null 2>&1 &
aplay -q /sdcard/timer/v/acabou.wav
sleep 4
aplay -q /sdcard/timer/v/acabou.wav
