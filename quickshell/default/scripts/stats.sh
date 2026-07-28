#!/bin/bash
# Emits pipe-separated system stats for the Quickshell StatsWidget:
# cpu|memPct|memUsedGB|memTotalGB|diskPct|diskTotalGB|diskUsedGB|diskAvailGB|load1|load5|load15|tempC|core0,core1,...|gpuUtil|gpuTemp|gpuMemUsed|gpuMemTotal

snap1=$(mktemp)
snap2=$(mktemp)
grep '^cpu' /proc/stat > "$snap1"
sleep 0.2
grep '^cpu' /proc/stat > "$snap2"

cpu_result=$(awk '
NR==FNR {
    idle1[$1] = $5+$6
    total1[$1] = $2+$3+$4+$5+$6+$7+$8+$9
    next
}
{
    idle2 = $5+$6
    total2 = $2+$3+$4+$5+$6+$7+$8+$9
    dt = total2 - total1[$1]
    di = idle2 - idle1[$1]
    pct = (dt > 0) ? int((dt-di)*100/dt) : 0
    print $1, pct
}' "$snap1" "$snap2")
rm -f "$snap1" "$snap2"

cpu=$(echo "$cpu_result" | awk '$1=="cpu"{print $2}')
percore=$(echo "$cpu_result" | awk '$1!="cpu"{printf "%s,", $2}' | sed 's/,$//')

mem_line=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%d|%.1f|%.1f", (t-a)*100/t, (t-a)/1024/1024, t/1024/1024}' /proc/meminfo)

disk_line=$(df -P / | awk 'NR==2{gsub("%","",$5); printf "%s|%.0f|%.0f|%.0f", $5, $2/1024/1024, $3/1024/1024, $4/1024/1024}')

load=$(awk '{printf "%s|%s|%s", $1, $2, $3}' /proc/loadavg)

temp=$(sensors -j 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(round(d['k10temp-pci-00c3']['Tctl']['temp1_input']))
except Exception:
    print('NA')
" 2>/dev/null)
[ -z "$temp" ] && temp="NA"

gpu_line=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | tr -d ' ' | tr ',' '|')
[ -z "$gpu_line" ] && gpu_line="NA|NA|NA|NA"

echo "${cpu}|${mem_line}|${disk_line}|${load}|${temp}|${percore}|${gpu_line}"
