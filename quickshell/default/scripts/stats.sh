#!/bin/bash
# Emits pipe-separated system stats for the Quickshell StatsWidget:
# cpu|memPct|memUsedGB|memTotalGB|diskPct|diskTotalGB|diskUsedGB|diskAvailGB|load1|load5|load15|tempC|core0,core1,...|gpuUtil|gpuTemp|gpuMemUsed|gpuMemTotal|mounts
# mounts is "path,pct,totalGiB,usedGiB,availGiB,device,readKBps,writeKBps" per real mounted
# filesystem, separated by ";", root (/) always first

snap1=$(mktemp)
snap2=$(mktemp)
grep '^cpu' /proc/stat > "$snap1"
io1=$(cat /proc/diskstats)
t1=$(date +%s%N)
sleep 0.2
grep '^cpu' /proc/stat > "$snap2"
io2=$(cat /proc/diskstats)
t2=$(date +%s%N)

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

# Read/write throughput per block device, from the same 0.2s window as the CPU sample
# above (/proc/diskstats sector counts are in 512-byte units regardless of the device's
# real sector size).
io_result=$(awk -v dt="$(awk -v a="$t1" -v b="$t2" 'BEGIN{print (b-a)/1000000000}')" '
NR==FNR { rs[$3] = $6; ws[$3] = $10; next }
$3 in rs {
    dr = $6 - rs[$3]; dw = $10 - ws[$3]
    printf "%s|%.0f|%.0f\n", $3, dr*512/1024/dt, dw*512/1024/dt
}' <(echo "$io1") <(echo "$io2"))

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

# Every real mounted filesystem (skips virtual/pseudo ones), root first so the
# disk pill's default mount is stable regardless of mount order. --output (not -P)
# so the source device is right there instead of a second df call per mount.
real_mounts=$(df --output=source,pcent,size,used,avail,target \
    -x tmpfs -x devtmpfs -x squashfs -x proc -x sysfs -x overlay -x efivarfs \
    -x devpts -x cgroup -x cgroup2 -x pstore -x bpf -x tracefs -x mqueue \
    -x hugetlbfs -x fusectl -x configfs -x debugfs -x autofs -x binfmt_misc -x ramfs \
    2>/dev/null | tail -n +2)
ordered_mounts=$(printf '%s\n' "$real_mounts" | awk '$6=="/"'; printf '%s\n' "$real_mounts" | awk '$6!="/"')
mounts=$(awk -v OFS=',' '
NR==FNR { split($0, a, "|"); io_r[a[1]] = a[2]; io_w[a[1]] = a[3]; next }
NF {
    gsub("%", "", $2)
    dev = $1
    sub("^/dev/", "", dev)
    r = (dev in io_r) ? io_r[dev] : 0
    w = (dev in io_w) ? io_w[dev] : 0
    printf "%s,%s,%.0f,%.0f,%.0f,%s,%s,%s;", $6, $2, $3/1024/1024, $4/1024/1024, $5/1024/1024, dev, r, w
}' <(echo "$io_result") <(printf '%s\n' "$ordered_mounts"))
mounts=${mounts%;}

echo "${cpu}|${mem_line}|${disk_line}|${load}|${temp}|${percore}|${gpu_line}|${mounts}"
