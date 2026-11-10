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
GP=$!
sleep 1
for d in /dev/input/event*; do
  ( evtest $d 2>/dev/null | while read l; do
      case "$l" in *"type 1 (EV_KEY)"*"value 1"*) kill $GP 2>/dev/null; break ;; esac
    done ) &
done
aplay -q /sdcard/timer/v/acabou.wav
sleep 4
aplay -q /sdcard/timer/v/acabou.wav
sleep 26
killall evtest 2>/dev/null
