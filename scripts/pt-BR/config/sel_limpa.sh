#!/bin/sh
# Segure o botão Start por 3 s (fora de um jogo) para apagar o histórico e reiniciar o menu.
# Roda NO APARELHO. Iniciado por uma linha no script hook (veja o README).
# Só os comentários estão em português: as mensagens do sel.log ficam iguais à versão em inglês.
SEL=28            # código do botão (28 = Start/KEY_ENTER no aparelho testado)
HOLD=300          # centésimos de segundo (300 = 3 s)
LOG=/sdcard/histtools/sel.log
DB=/sdcard/game/database.sqlite3
MOLDE=/sdcard/histtools/hist_vazio.sqlite3
[ -f /tmp/sel_limpa.pid ] && kill -0 "$(cat /tmp/sel_limpa.pid)" 2>/dev/null && exit 0
echo $$ > /tmp/sel_limpa.pid
echo "sel_limpa started" >> $LOG
for d in /dev/input/event*; do
  ( while :; do
      evtest "$d" 2>/dev/null | while read l; do
        case "$l" in
          *"code $SEL ("*"value 1"*)
            read U _ < /proc/uptime; echo "${U%.*}${U#*.}" > /tmp/sel_t0 ;;
          *"code $SEL ("*"value 0"*)
            [ -f /tmp/sel_t0 ] || continue
            read U _ < /proc/uptime; N=${U%.*}${U#*.}
            read T0 < /tmp/sel_t0; rm -f /tmp/sel_t0
            [ $((N - T0)) -ge $HOLD ] || continue
            [ -n "$(pidof retroarch)" ] && continue       # nunca dentro de um jogo
            [ -f "$MOLDE" ] || { echo "mold missing" >> $LOG; continue; }
            read U2 _ < /proc/uptime; N2=${U2%.*}
            if [ -f /tmp/sel_rst ]; then read L < /tmp/sel_rst; [ $((N2 - L)) -lt 8 ] && continue; fi
            echo "$N2" > /tmp/sel_rst
            cat "$MOLDE" > "$DB" && sync                   # sobrescreve NO MESMO ARQUIVO (o menu mantém o arquivo aberto)
            echo "history wiped" >> $LOG
            killall -9 game 2>/dev/null                     # mata o menu para ele não regravar os dados antigos
            sleep 1
            export HOME=/ XDG_CONFIG_HOME=/sdcard/ MG_CFG_PATH=/usr/local/share/minigui/hdmicfg storagemedia=sd
            cd /mnt
            setsid /usr/bin/game </dev/null >/dev/console 2>&1 &
            sleep 3
            if [ -n "$(pidof game)" ]; then echo "menu restarted" >> $LOG; else echo "menu did NOT start" >> $LOG; fi
            ;;
        esac
      done
      sleep 2
    done ) &
done
wait
