#!/bin/sh
O=/sdcard/timer/diag2.log
C=/usr/local/share/minigui/gbx66.cfg
{
echo "=== $(date) args: $*"
echo "--- cfg interno"
ls -ld /usr/local/share/minigui $C
grep -n '^fastforward_ratio\|^input_hold_fast_forward \|^video_vsync\|^fps_show' $C
md5sum $C /sdcard/gbx66.cfg
echo "--- mounts"
mount | grep -E 'sdcard|minigui| /usr| / | /data'
readlink -f /sdcard
echo "--- scripts start_game"
find /usr /etc /data /opt /bin /sbin -name 'start_game*' 2>/dev/null
grep -a -o '[A-Za-z_/.]*start[A-Za-z_]*\.sh' /usr/bin/game | sort -u
echo "--- processos"
ps 2>&1 | head -40
echo "--- ferramentas"
for t in nc busybox python3 socat timeout od xxd hexdump awk; do echo "$t: $(which $t 2>&1)"; done
echo "READ_CORE_MEMORY: $(grep -c READ_CORE_MEMORY /usr/bin/retroarch)"
echo "FAST_FORWARD: $(grep -c FAST_FORWARD /usr/bin/retroarch)"
/usr/bin/retroarch --version 2>&1 | head -3
} >> $O 2>&1
sync
