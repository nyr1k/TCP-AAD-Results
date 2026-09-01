#!/usr/bin/env bash

rm -f /tmp/server1.ready /tmp/server2.ready /tmp/start_test

./run_main_test_server.sh &
PID1=$!

./run_main_test_server2.sh &
PID2=$!

echo "Waiting for both scripts..."

while [[ ! -f /tmp/server1.ready || ! -f /tmp/server2.ready ]]; do
    sleep 0.1
done

echo "Both ready."

touch /tmp/start_test

wait "$PID1"
wait "$PID2"

rm -f /tmp/server1.ready /tmp/server2.ready /tmp/start_test