#!/usr/bin/env bash
# The GPU half of the bar's sysmon (CPU and memory are read from /proc by
# Bar/SysMon.qml itself):
#   sysmon.sh gpu-source   once: a sysfs gpu_busy_percent file, "nvidia", or "none"
#   sysmon.sh gpu          NVIDIA only: the busy percent, or nothing while the
#                          card sleeps (polling a suspended laptop dGPU wakes it
#                          up and costs battery; the widget then hides its GPU half)
#                          prints "<busy> <temp °C>"
#   sysmon.sh cpu-temp-source   once: the hwmon temp file of the CPU package, or "none"
set -u
case "${1:-}" in
    gpu-source)
        for f in /sys/class/drm/card*/device/gpu_busy_percent; do
            [[ -r "$f" ]] && { echo "$f"; exit 0; }
        done
        if command -v nvidia-smi >/dev/null 2>&1; then
            for d in /sys/class/drm/card*/device; do
                [[ "$(cat "$d/vendor" 2>/dev/null)" == "0x10de" ]] && { echo nvidia; exit 0; }
            done
        fi
        echo none ;;
    gpu)
        for d in /sys/class/drm/card*/device; do
            [[ "$(cat "$d/vendor" 2>/dev/null)" == "0x10de" ]] || continue     # NVIDIA
            [[ "$(cat "$d/power_state" 2>/dev/null)" == "D0" ]] || exit 0      # asleep: leave it alone
            g="$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)"
            g="${g//,/}"
            [[ "$g" =~ ^[0-9]+\ [0-9]+$ ]] && echo "$g"
            exit 0
        done ;;
    cpu-temp-source)
        # Intel coretemp "Package id 0", AMD k10temp/zenpower Tctl, else the first one
        for h in /sys/class/hwmon/hwmon*; do
            case "$(cat "$h/name" 2>/dev/null)" in
                coretemp|k10temp|zenpower)
                    for l in "$h"/temp*_label; do
                        case "$(cat "$l")" in "Package id 0"|Tctl|Tdie) echo "${l%_label}_input"; exit 0 ;; esac
                    done
                    [[ -r "$h/temp1_input" ]] && { echo "$h/temp1_input"; exit 0; } ;;
            esac
        done
        echo none ;;
    *) echo "usage: sysmon.sh gpu-source|gpu|cpu-temp-source" >&2; exit 1 ;;
esac
