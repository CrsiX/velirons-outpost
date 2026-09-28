#!/bin/bash
# Two-process LAN co-op test: a headless host and a headless client on this machine.
# Usage: tests/run_net_test.sh [godot binary]
GODOT="${1:-godot}"
PORT="${2:-$((47200 + RANDOM % 500 * 2))}"  # own ports per run (discovery on PORT - 1)
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . res://tests/net_bot.tscn -- --role=host --port=$PORT > "${TMPDIR:-/tmp}/net_host.log" 2>&1 &
HOST=$!
sleep 2
"$GODOT" --headless --path . res://tests/net_bot.tscn -- --role=client --port=$PORT > "${TMPDIR:-/tmp}/net_client.log" 2>&1
CLIENT_RC=$?
wait $HOST
HOST_RC=$?
grep -E "ok|FAIL|SCRIPT ERROR|CHECKS" "${TMPDIR:-/tmp}/net_host.log"
grep -E "ok|FAIL|SCRIPT ERROR|CHECKS" "${TMPDIR:-/tmp}/net_client.log"
[ $HOST_RC -eq 0 ] && [ $CLIENT_RC -eq 0 ]
