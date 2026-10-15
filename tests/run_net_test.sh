#!/bin/bash
# Two-process LAN co-op test: a headless host and a headless client on this machine,
# twice: a generated map, then a map file with a village nobody plays (--custom).
# Usage: tests/run_net_test.sh [godot binary]
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
RC=0
for MODE in "" "--custom"; do
	PORT="$((47200 + RANDOM % 500 * 2))"  # own ports per run (discovery on PORT - 1)
	"$GODOT" --headless --path . res://tests/net_bot.tscn -- --role=host --port=$PORT $MODE > "${TMPDIR:-/tmp}/net_host.log" 2>&1 &
	HOST=$!
	sleep 2
	"$GODOT" --headless --path . res://tests/net_bot.tscn -- --role=client --port=$PORT $MODE > "${TMPDIR:-/tmp}/net_client.log" 2>&1
	CLIENT_RC=$?
	wait $HOST
	HOST_RC=$?
	grep -E "ok|FAIL|SCRIPT ERROR|CHECKS" "${TMPDIR:-/tmp}/net_host.log"
	grep -E "ok|FAIL|SCRIPT ERROR|CHECKS" "${TMPDIR:-/tmp}/net_client.log"
	if [ $HOST_RC -ne 0 ] || [ $CLIENT_RC -ne 0 ]; then RC=1; fi
done
exit $RC
