#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/run_single_test.sh"

echo "SERVER_KEY=[$SERVER_KEY]"

RESULTS_DIR="${RESULTS_BASE}/main_test"
mkdir -p "${RESULTS_DIR}"/{logs,raw,dmesg}

run_single_test nolim nodelay 90 1
