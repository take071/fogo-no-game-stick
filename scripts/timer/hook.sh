#!/bin/sh
LOG=/sdcard/timer/hook.log
echo "hook $1 $2 $3" >> $LOG
NAME="${3##*/}"
case "$NAME" in
  *"Timer"*) echo "$1 $2" > /tmp/gtimer.self ;;
  *) echo "$1 $2" > /tmp/gtimer.game; exit 1 ;;
esac
P0=$(pidof gtimer); [ -n "$P0" ] && { kill $P0 2>/dev/null; sleep 1; }
rm -f /tmp/gtimer
cp /sdcard/timer/gtimer /tmp/gtimer 2>>$LOG
chmod +x /tmp/gtimer 2>>$LOG
echo "rodando" >> $LOG; sync
case "$NAME" in *"calibrar"*) ARG=cal ;; *) ARG= ;; esac
/tmp/gtimer $ARG 2>>$LOG &
P=$!
( sleep 150; kill -9 $P 2>/dev/null ) &
W=$!
wait $P
RC=$?
kill $W 2>/dev/null
echo "fim rc=$RC" >> $LOG; sync
exit 0
