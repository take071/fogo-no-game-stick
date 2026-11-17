#!/bin/sh
O=/sdcard/tools.log
{
echo "=== $(date)"
for t in nc busybox python3 python socat timeout od xxd hexdump awk; do echo "$t: $(which $t 2>&1)"; done
echo "READ_CORE_MEMORY: $(grep -c READ_CORE_MEMORY /usr/bin/retroarch)"
echo "FAST_FORWARD: $(grep -c FAST_FORWARD /usr/bin/retroarch)"
echo "stdin_cmd: $(grep -c stdin_cmd /usr/bin/retroarch)"
/usr/bin/retroarch --version 2>&1 | head -3
busybox 2>&1 | head -30
ls /usr/bin | tr '\n' ' '
} >> $O 2>&1
sync
