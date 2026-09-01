#!usr/bin/env bash

run_single_test2() {
  local bw=$1 delay=$2 duration=$3 iterations=$4
  
  if [[ -z "$bw" || -z "$delay" || -z "$duration" || -z "$iterations" ]]
  then
    log_error "Usage: run_single_test <bw> <delay> <duration> <iterations>" "$SESSION_LOG"
    return 1
  fi
  
  # Verify current rate from router
  local actual_rate output
  if ! actual_rate=$(get_router_rate 2>&1)
  then
    log_error "Cannot read router rate: ${actual_rate}" "$SESSION_LOG"
    return 1
  fi
  CURRENT_RATE="$actual_rate"

  local test_base="rate${CURRENT_RATE}_bw${bw}_delay${delay}"
  local test_log="${RESULTS_DIR}/logs/${test_base}.log"


  # Write test header
  {
      echo "================================================================================"
      echo "Test: ${test_base} | Kernel: ${KERNEL_TYPE} | $(date -Iseconds)"
      echo "Server kernel: ${SERVER2_KERNEL}"
      echo "rate=${CURRENT_RATE}  bw=${bw}  delay=${delay}  duration=${duration}s  iterations=${iterations}"
      echo "================================================================================"
  } > "${test_log}"

  local -a iperf_opts=(-c "${SERVER2_IP}" -p "${IPERF_PORT}" -t "${duration}" -i 1 -J --get-server-output -N)


  for ((i = 1; i <= iterations; i++)); do
    log_info "[${test_base}] Iteration ${i}/${iterations}" "$test_log"

    local test_name="${test_base}_iter${i}"
    local pcap_file="${test_name}.pcap"
    local result_file="${RESULTS_DIR}/raw/${test_name}.json"
    local ftrace_local_file="${RESULTS_DIR}/ftrace/${test_name}_ftrace.txt"

     # Create the local ftrace output directory if it doesn't exist
    mkdir -p "${RESULTS_DIR}/ftrace"

    # ---  PRE-TEST FTRACE SETUP ---
    log_info "Preparing and clearing remote Ftrace buffer..." "$test_log"
    server2_ssh "sudo sh -c 'echo 0 > /sys/kernel/debug/tracing/tracing_on && echo > /sys/kernel/debug/tracing/trace && echo 1 > /sys/kernel/debug/tracing/tracing_on'"

    echo "${pcap_file}"

    # Start pcap
    if ! output=$(server2_ssh "$(pcap_start_cmd "$pcap_file" "$SERVER2_IFACE" "$SERVER2_IP" "$CLIENT_IP")" 2>&1); then
      log_error "  Failed to start tcpdump: ${output}" "$test_log"
      return 1
    fi

    echo "--- Iteration ${i} | $(date -Iseconds) ---" >> "${test_log}"
    echo "" >> "${test_log}"
    collect_rc_stats "${test_log}" || return 1
    echo "================================================================================" >> "${test_log}"

    sleep 5

    touch /tmp/server2.ready

    while [[ ! -f /tmp/start ]]; do
        sleep 0.05
    done



    # start iperf here
    log_info "  Running iperf3 for ${duration}s..." "$test_log"
    if ! iperf3 "${iperf_opts[@]}" > "${result_file}" 2>>"${test_log}"
    then
      log_error "  iperf3 failed (see above)" "$test_log"
      return 1
    else
      log_success "  iperf3 complete" "$test_log"
    fi

    collect_rc_stats "${test_log}" || return 1

    # --- POST-TEST FTRACE COLLECTION ---
    log_info "Freezing Ftrace and extracting iteration log..." "$test_log"
    server2_ssh "sudo sh -c 'echo 0 > /sys/kernel/debug/tracing/tracing_on'"
    
    # Safely pull the trace stream over SSH, extracting only your active research tokens
    server2_ssh "sudo cat /sys/kernel/debug/tracing/trace" | grep -i "iperf" > "${ftrace_local_file}"


    # Stop pcap, count ACKs, cleanup (single SSH call)
    local ack_count
    if ! ack_count=$(pcap_stop_count_cleanup2 "$pcap_file" 2>&1)
    then
      log_error "  Failed to stop/count/cleanup pcap: ${ack_count}" "$test_log"
      ack_count="error"
    fi
    log_info "  ACK count: ${ack_count}" "$test_log"

    echo "" >> "${test_log}"
    {
      echo "  ACK count   : ${ack_count}"
        echo ""
    } | tee -a "${test_log}"

      [[ $i -lt $iterations ]] && sleep "${SETTLE_TIME:-2}"
    done

    log_success "Done: ${test_base}" "$test_log"
}
