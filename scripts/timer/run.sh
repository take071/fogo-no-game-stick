#!/bin/sh
END=$1
DUR=15      # segundos que o aviso fica na tela
PAUSAR=1    # 1 = congela o jogo antes de desenhar o aviso (evita o pisca-pisca)
LOG=/sdcard/timer/gtimer.log
echo $$ > /tmp/gtimer.pid
while :; do
  read UP _ < /proc/uptime; UP=${UP%.*}
  LEFT=$((END - UP))
  [ "$LEFT" -le 0 ] && break
  [ "$LEFT" -gt 20 ] && sleep 20 || sleep "$LEFT"
done
rm -f /tmp/gtimer.pid
[ -x /tmp/gtimer ] || { cp /sdcard/timer/gtimer /tmp/gtimer; chmod +x /tmp/gtimer; }

RP=$(pidof retroarch | awk '{print $1}')
GP=; AP=
cleanup() {
  [ -n "$RP" ] && kill -CONT $RP 2>/dev/null
  [ -n "$GP" ] && kill $GP 2>/dev/null
  [ -n "$AP" ] && kill $AP 2>/dev/null
  killall aplay 2>/dev/null
  killall evtest 2>/dev/null
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

# 1) congela o jogo ANTES de iniciar o gtimer
if [ "$PAUSAR" = 1 ] && [ -n "$RP" ]; then
  kill -STOP $RP 2>/dev/null
  sleep 0.3 2>/dev/null || sleep 1
fi
echo "run.sh: retroarch pid=${RP:-nenhum} pausar=$PAUSAR dur=$DUR" >> $LOG

# 2) duração do aviso (o gtimer lê este arquivo)
echo "$DUR" > /sdcard/timer/aviso.txt

/tmp/gtimer alarm >/dev/null 2>&1 &
GP=$!
( aplay -q /sdcard/timer/v/acabou.wav; sleep 4; aplay -q /sdcard/timer/v/acabou.wav ) &
AP=$!
read T0 _ < /proc/uptime; T0=${T0%.*}
sleep 1
for d in /dev/input/event*; do
  ( evtest $d 2>/dev/null | while read l; do
      case "$l" in *"type 1 (EV_KEY)"*"value 1"*) kill $GP 2>/dev/null; break ;; esac
    done ) &
done

alive() { ST=$(cut -d' ' -f3 /proc/$GP/stat 2>/dev/null); [ -n "$ST" ] && [ "$ST" != Z ] && [ "$ST" != X ]; }
while alive; do
  read T1 _ < /proc/uptime; T1=${T1%.*}
  [ $((T1 - T0)) -ge $((DUR + 3)) ] && break
  sleep 0.5 2>/dev/null || sleep 1
done
echo "run.sh: fim aviso" >> $LOG
exit 0
