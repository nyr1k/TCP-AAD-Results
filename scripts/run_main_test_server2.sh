#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/run_single_test2.sh"

SETUP_DONE=0
START_TIME=$(date +%s)

KERNEL_TYPE=${1:-"tcpaad"}
validate_kernel_type "$KERNEL_TYPE"

DURATION=90
ITERATIONS=5
if [ "$KERNEL_TYPE" = "tcpaad" ]; then
    ALPHAS=(50)
else
    ALPHAS=(0)  # single dummy iteration for default kernel
    RESULTS_DIR="${RESULTS_BASE}/multi_test_server2/${KERNEL_TYPE}"
    mkdir -p "${RESULTS_DIR}"/{logs,raw,dmesg}
fi
SESSION_LOG="${RESULTS_BASE}/multi_test_server2/session.log"
mkdir -p "${RESULTS_BASE}/multi_test_server2"

teardown() {
    if [ "$SETUP_DONE" = "0" ]; then
        return
    fi

    log_info "Restoring server settings..." "$SESSION_LOG"

    local server_cmds="sudo sysctl -w net.ipv4.tcp_sack=1"

    if [ "$KERNEL_TYPE" = "tcpaad" ]; then
        server_cmds+="; sudo sysctl -w net.ipv4.tcp_aad=0"
    fi

    local output
    if ! output=$(server_ssh "${server_cmds}" 2>&1); then
        log_error "Failed to restore server settings: ${output}" "$SESSION_LOG"
    fi

    log_info "Resetting router rate to auto..." "$SESSION_LOG"
    if ! output=$(set_router_rate 2>&1); then
        log_error "Failed to reset router rate: ${output}" "$SESSION_LOG"
    fi

    log_success "Teardown complete" "$SESSION_LOG"
}

trap teardown EXIT

log_info "Verifying dependencies..." "$SESSION_LOG"
missing=()
command_exists iperf3 || missing+=("iperf3")
command_exists ssh    || missing+=("ssh")
if [ ${#missing[@]} -ne 0 ]; then
    log_error "Missing: ${missing[*]}" "$SESSION_LOG"
    exit 1
fi

log_info "Checking SSH to Router (${ROUTER_USER}@${ROUTER_IP})..." "$SESSION_LOG"
if ! output=$(router_ssh "exit" 2>&1); then
    log_error "Cannot SSH to Router: ${output}" "$SESSION_LOG"
    exit 1
fi
log_success "SSH to Router OK" "$SESSION_LOG"

log_info "Checking SSH to Server2 (${SERVER2_USER}@${SERVER2_IP})..." "$SESSION_LOG"
if ! output=$(server2_ssh "exit" 2>&1); then
    log_error "Cannot SSH to Server2: ${output}" "$SESSION_LOG"
    exit 1
fi
log_success "SSH to Server2 OK" "$SESSION_LOG"

if ! SERVER2_KERNEL=$(server2_ssh "uname -r" 2>&1); then
    log_error "Failed to get server2 kernel: ${SERVER2_KERNEL}" "$SESSION_LOG"
    exit 1
fi
log_info "Server2 kernel: ${SERVER2_KERNEL}" "$SESSION_LOG"

echo "================================================================================"
echo "  Main Test Plan"
echo "  Kernel       : ${KERNEL_TYPE} (${SERVER2_KERNEL})"
echo "  Results      : ${RESULTS_BASE}/multi_test_server2/"
echo "  Duration     : ${DURATION}s   Iterations: ${ITERATIONS}"
if [ "$KERNEL_TYPE" = "tcpaad" ]; then
    echo "  Alphas       : ${ALPHAS[*]} (α=$(for a in "${ALPHAS[@]}"; do awk "BEGIN{printf \"%.1f \", ${a}/10}"; done))"
fi
echo "================================================================================"
#read -p "Press Enter to start or Ctrl+C to cancel..."
echo ""

# --- Server setup (remote) ---
log_info "Disabling SACK on server2..." "$SESSION_LOG"
if ! output=$(server2_ssh "sudo sysctl -w net.ipv4.tcp_sack=0" 2>&1); then
    log_error "Failed to disable SACK: ${output}" "$SESSION_LOG"
fi

# --- TCP-AAD setup ---
if [ "$KERNEL_TYPE" = "tcpaad" ]; then
    log_info "Enabling TCP-AAD on server2..." "$SESSION_LOG"
    if ! output=$(server2_ssh "sudo sysctl -w net.ipv4.tcp_aad=1" 2>&1); then
        log_error "Failed to enable tcp_aad: ${output}" "$SESSION_LOG"
        exit 1
    fi
fi

SETUP_DONE=1

# ==============================================================================
#  Test plan
# ==============================================================================

for ALPHA in "${ALPHAS[@]}"; do

if [ "$KERNEL_TYPE" = "tcpaad" ]; then
    RESULTS_DIR="${RESULTS_BASE}/multi_test_server2/${KERNEL_TYPE}_${ALPHA}"
    mkdir -p "${RESULTS_DIR}"/{logs,raw,dmesg}
fi
SESSION_LOG="${RESULTS_DIR}/session.log"

if [ "$KERNEL_TYPE" = "tcpaad" ]; then
    log_info "=== Alpha ${ALPHA} (α=$(awk "BEGIN{printf \"%.1f\", ${ALPHA}/10}")) ===" "$SESSION_LOG"
    if ! output=$(set_tcpaad_alpha2 "${ALPHA}" 2>&1); then
        log_error "Failed to set tcp_aad_alpha: ${output}" "$SESSION_LOG"
        exit 1
    fi
fi

# --- Rate 67 (HT20-SGI-MCS3) ---
log_info "Setting WiFi rate to 67 (${RATE_MAP[67]:-unknown})..." "$SESSION_LOG"
if ! output=$(set_router_rate 67 2>&1); then
    log_error "Failed to set router rate 67: ${output}" "$SESSION_LOG"
    exit 1
fi

run_single_test2 nolim nodelay "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim nodelay" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 10 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 10" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 50 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 50" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 100 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 100" "$SESSION_LOG"; exit 1; }
run_single_test2 12 nodelay "$DURATION" "$ITERATIONS" || { log_error "Test failed: 12 nodelay" "$SESSION_LOG"; exit 1; }

# --- Rate 71 (HT20-SGI-MCS7) ---
log_info "Setting WiFi rate to 71 (${RATE_MAP[71]:-unknown})..." "$SESSION_LOG"
if ! output=$(set_router_rate 71 2>&1); then
    log_error "Failed to set router rate 71: ${output}" "$SESSION_LOG"
    exit 1
fi

run_single_test2 nolim nodelay "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim nodelay" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 10 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 10" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 50 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 50" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 100 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 100" "$SESSION_LOG"; exit 1; }
run_single_test2 30 nodelay "$DURATION" "$ITERATIONS" || { log_error "Test failed: 30 nodelay" "$SESSION_LOG"; exit 1; }

# --- Rate 199 (HT40-SGI-MCS7) ---
log_info "Setting WiFi rate to 195 (${RATE_MAP[195]:-unknown})..." "$SESSION_LOG"
if ! output=$(set_router_rate 195 2>&1); then
    log_error "Failed to set router rate 195: ${output}" "$SESSION_LOG"
    exit 1
fi

run_single_test2 nolim nodelay "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim nodelay" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 10 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 10" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 50 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 50" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 100 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 100" "$SESSION_LOG"; exit 1; }
run_single_test2 26 nodelay "$DURATION" "$ITERATIONS" || { log_error "Test failed: 26 nodelay" "$SESSION_LOG"; exit 1; }

# --- Rate 199 (HT40-SGI-MCS7) ---
log_info "Setting WiFi rate to 199 (${RATE_MAP[199]:-unknown})..." "$SESSION_LOG"
if ! output=$(set_router_rate 199 2>&1); then
    log_error "Failed to set router rate 199: ${output}" "$SESSION_LOG"
    exit 1
fi

run_single_test2 nolim nodelay "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim nodelay" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 10 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 10" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 50 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 50" "$SESSION_LOG"; exit 1; }
run_single_test2 nolim 100 "$DURATION" "$ITERATIONS" || { log_error "Test failed: nolim 100" "$SESSION_LOG"; exit 1; }
run_single_test2 70 nodelay "$DURATION" "$ITERATIONS" || { log_error "Test failed: 70 nodelay" "$SESSION_LOG"; exit 1; }

log_success "Alpha ${ALPHA} complete" "$SESSION_LOG"
done

# ==============================================================================
#  Done — teardown runs automatically via trap
# ==============================================================================

echo "================================================================================"
echo "  Main Test Complete"
echo "  Kernel       : ${KERNEL_TYPE} (${SERVER2    _KERNEL})"
echo "  Results      : ${RESULTS_BASE}/main_test/"
echo "  Elapsed      : $(format_duration $(( $(date +%s) - START_TIME )))"
echo "================================================================================"