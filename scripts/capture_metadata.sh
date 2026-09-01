#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

if [ $# -ne 1 ]; then
    log_error "Usage: $0 <output_file>"
    exit 1
fi

OUTPUT_FILE=$1

kernel_version=$(server_ssh "uname -r" 2>/dev/null || echo "unknown")
fixed_rate=$(router_ssh "cat /sys/kernel/debug/ieee80211/phy1/rc/fixed_rate_idx" 2>/dev/null || echo "unknown")
station_info=$(router_ssh "iw dev ${ROUTER_IFACE} station dump | head -20" 2>/dev/null | sed 's/"/\\"/g' | tr '\n' ' ' | tr -d '\r')
ss_output=$(server_ssh "ss -tin dst ${CLIENT_IP}" 2>/dev/null | sed 's/"/\\"/g' | tr '\n' ' ' | tr -d '\r')

cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "kernel": "${KERNEL_TYPE}",
  "server_kernel_version": "${kernel_version}",
  "wifi_stats": {
    "rc_stats": "${fixed_rate}",
    "station_info": "${station_info}"
  },
  "tcp_stats": {
    "ss_output": "${ss_output}"
  }
}
EOF
