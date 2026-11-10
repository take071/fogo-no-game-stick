#!/bin/sh

LOG="/sdcard/timer/diag_swap.txt"
PID=""
MAX=180
COUNT=0

echo "========================================" > "$LOG"
echo "DIAGNOSTICO DE MEMORIA - GAME STICK" >> "$LOG"
echo "INICIO: $(date)" >> "$LOG"
echo "========================================" >> "$LOG"

# O marcador torna o teste de uma unica execucao.
rm -f /sdcard/timer/diag_swap.on

log_memoria() {
    echo "" >> "$LOG"
    echo "===== AMOSTRA $COUNT =====" >> "$LOG"
    echo "HORA: $(date)" >> "$LOG"
    echo "UPTIME:" >> "$LOG"
    cat /proc/uptime >> "$LOG"

    echo "--- MEMORIA GLOBAL ---" >> "$LOG"
    grep -E 'MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|AnonPages' /proc/meminfo >> "$LOG"

    echo "--- SWAP ---" >> "$LOG"
    cat /proc/swaps >> "$LOG"

    echo "--- PRESSAO DE MEMORIA ---" >> "$LOG"
    grep -E 'pgscan|allocstall|oom_kill|pswpin|pswpout' /proc/vmstat >> "$LOG"

    if [ -n "$PID" ] && [ -r "/proc/$PID/status" ]; then
        echo "--- RETROARCH PID $PID ---" >> "$LOG"
        grep -E 'Name|State|VmPeak|VmSize|VmRSS|VmData|VmSwap|Threads' "/proc/$PID/status" >> "$LOG"

        if [ -r "/proc/$PID/smaps_rollup" ]; then
            echo "--- SMAPS ROLLUP ---" >> "$LOG"
            cat "/proc/$PID/smaps_rollup" >> "$LOG"
        fi
    else
        echo "RETROARCH: processo nao encontrado nesta amostra" >> "$LOG"
    fi
}

echo "Aguardando o RetroArch iniciar..." >> "$LOG"

# Aguarda ate 120 segundos pelo processo.
WAIT=0
while [ "$WAIT" -lt 120 ]; do
    PID="$(pidof retroarch 2>/dev/null | awk '{print $1}')"
    [ -n "$PID" ] && break
    sleep 2
    WAIT=$((WAIT + 2))
done

if [ -z "$PID" ]; then
    echo "ERRO: RetroArch nao foi encontrado." >> "$LOG"
else
    echo "RETROARCH DETECTADO: PID $PID" >> "$LOG"

    # Registra enquanto o processo existir.
    while [ "$COUNT" -lt "$MAX" ] && kill -0 "$PID" 2>/dev/null; do
        COUNT=$((COUNT + 1))
        log_memoria
        sleep 5
    done

    if [ -d "/proc/$PID" ]; then
        echo "LIMITE DE TEMPO ATINGIDO." >> "$LOG"
    else
        echo "RETROARCH ENCERRADO." >> "$LOG"
        echo "O processo terminou durante o monitoramento." >> "$LOG"
    fi
fi

echo "" >> "$LOG"
echo "===== DIAGNOSTICO FINAL =====" >> "$LOG"
echo "FIM: $(date)" >> "$LOG"
grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree|AnonPages' /proc/meminfo >> "$LOG"
cat /proc/swaps >> "$LOG"
echo "===== FIM DO ARQUIVO =====" >> "$LOG"
