#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Logging ---
# $1 = message, $2 = log file (optional)

log_info()    { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') - $1" | tee -a "${2:-/dev/null}"; }
log_success() { echo -e "${GREEN}[ OK ]${NC} $(date '+%H:%M:%S') - $1" | tee -a "${2:-/dev/null}"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') - $1" | tee -a "${2:-/dev/null}"; }
log_error()   { echo -e "${RED}[ERR ]${NC} $(date '+%H:%M:%S') - $1" | tee -a "${2:-/dev/null}"; }

# --- SSH helpers ---

server_ssh() { ssh -i "${SERVER_KEY}" -o LogLevel=ERROR "${SERVER_USER}@${SERVER_IP}" "$@"; }
server2_ssh() { ssh -i "${SERVER2_KEY}" -o LogLevel=ERROR "${SERVER2_USER}@${SERVER2_IP}" "$@"; }
router_ssh() { ssh -i "${ROUTER_KEY}" -o LogLevel=ERROR -oHostKeyAlgorithms=+ssh-rsa -oPubkeyAcceptedAlgorithms=+ssh-rsa "${ROUTER_USER}@${ROUTER_IP}" "$@"; }

# --- Validation ---

validate_kernel_type() {
    if [[ "$1" != "tcpaad" && "$1" != "default" ]]; then
        echo "Error: Kernel type must be 'tcpaad' or 'default'"
        exit 1
    fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

# --- PCAP ---

pcap_start_cmd() {
    local capture_file=$1 iface=$2 src_ip=$3 dst_ip=$4
    echo "nohup tcpdump -i ${iface} -w /tmp/${capture_file} 'tcp[tcpflags] & tcp-ack != 0 and src host ${src_ip} and dst host ${dst_ip} and (ip[2:2] - ((ip[0]&0xf)<<2) - ((tcp[12]&0xf0)>>2)) == 0' > /dev/null 2>&1 &"
}

pcap_stop_count_cleanup() {
    local capture_file=$1
    server_ssh "pkill -SIGINT tcpdump; sleep 2; tcpdump -r /tmp/${capture_file} 2>/dev/null | wc -l; rm -f /tmp/${capture_file}"
}

pcap_stop_count_cleanup2() {
    local capture_file=$1
    server2_ssh "pkill -SIGINT tcpdump; sleep 2; tcpdump -r /tmp/${capture_file} 2>/dev/null | wc -l; rm -f /tmp/${capture_file}"
}

# --- RTT ---

measure_rtt() {
    local host=$1 count=${2:-3}
    ping -c "$count" -i 0.2 -q "$host" 2>/dev/null | grep 'rtt' | awk -F'/' '{print $5}'
}

# --- tc ---
# Return 0 on success, 1 on failure. Error output on stderr.

tc_setup() {
    local bw=$1 delay=$2 iface=$3
    local netem_limit=10000

    if [ "$bw" = "nolim" ] && [ "$delay" = "nodelay" ]; then
        return 0
    elif [ "$bw" = "nolim" ]; then
        sudo tc qdisc add dev "${iface}" root netem delay "${delay}ms" limit "${netem_limit}" || return 1
    elif [ "$delay" = "nodelay" ]; then
        sudo tc qdisc add dev "${iface}" root handle 1: htb default 1 || return 1
        sudo tc class add dev "${iface}" parent 1: classid 1:1 htb rate "${bw}mbit" || return 1
    else
        sudo tc qdisc add dev "${iface}" root handle 1: htb default 1 || return 1
        sudo tc class add dev "${iface}" parent 1: classid 1:1 htb rate "${bw}mbit" || return 1
        sudo tc qdisc add dev "${iface}" parent 1:1 handle 10: netem delay "${delay}ms" limit "${netem_limit}" || return 1
    fi
}

tc_cleanup() {
    local iface=$1
    sudo tc qdisc del dev "${iface}" root 2>/dev/null
    return 0
}

# --- Progress ---

format_duration() {
    local s=$1
    printf "%02d:%02d:%02d" $((s / 3600)) $(((s % 3600) / 60)) $((s % 60))
}

# --- Router / kernel helpers ---
# Return output on stdout, errors on stderr. Caller logs.

CURRENT_RATE=""

set_router_rate() {
    local rate_index=${1:-"4294967295"}
    router_ssh "/root/fixrate1.sh ${rate_index}" || return 1
    CURRENT_RATE="$rate_index"
    sleep "${RATE_SLEEP_TIME}"
}

get_router_rate() {
    local output
    output=$(router_ssh "cat /sys/kernel/debug/ieee80211/phy1/rc/fixed_rate_idx" 2>&1) || {
        echo "$output" >&2
        return 1
    }
    if [[ -z "$output" ]]; then
        echo "Router returned empty rate index" >&2
        return 1
    fi
    echo "$output"
}

set_tcpaad_alpha() {
    local alpha=$1
    server_ssh "sudo sysctl -w net.ipv4.tcp_aad_alpha=${alpha}" || return 1
}

set_tcpaad_alpha2() {
    local alpha=$1
    server2_ssh "sudo sysctl -w net.ipv4.tcp_aad_alpha=${alpha}" || return 1
}

# --- RC stats ---

collect_rc_stats() {
    local log_file=$1
    local rc_output
    {
        echo "RC stats:"
        if ! rc_output=$(router_ssh "/root/rcstats1.sh" 2>&1); then
            echo "Failed to get RC stats: ${rc_output}"
            return 1
        fi
        echo "$rc_output"
    } >> "${log_file}"
}
