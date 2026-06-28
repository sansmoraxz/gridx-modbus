#!/bin/sh
set -e

MODE=$1
TEST_FILTER=$2

tmpdir=$(mktemp -d)
diagslave_pids=""
socat_pid=""

cleanup() {
    # Kill entire process group to catch any child processes
    if [ -n "$diagslave_pids" ]; then
        kill $diagslave_pids 2>/dev/null || [ $? -eq 1 ]
    fi
    if [ -n "$socat_pid" ]; then
        kill $socat_pid 2>/dev/null || [ $? -eq 1 ]
    fi
    # Fallback: kill any remaining processes in our process group
    kill -- -$$ 2>/dev/null || [ $? -eq 1 ]
    rm -rf "$tmpdir"
}

trap cleanup EXIT INT TERM

wait_for_pty() {
    local pty_path=$1
    local timeout=5
    local elapsed=0
    while [ ! -e "$pty_path" ]; do
        if [ "$elapsed" -ge "$timeout" ]; then
            echo "ERROR: Timeout waiting for $pty_path to appear" >&2
            exit 1
        fi
        sleep 0.05
        elapsed=$((elapsed + 1))
    done
}

case "$MODE" in
    tcp)
        diagslave -m tcp -p 5020 &
        diagslave_pids="$! $diagslave_pids"
        diagslave -m enc -p 5021 &
        diagslave_pids="$! $diagslave_pids"
        go test -run "$TEST_FILTER" -v .
        ;;
    rtu)
        socat -d -d pty,raw,echo=0,link="$tmpdir/pty0" pty,raw,echo=0,link="$tmpdir/pty1" &
        socat_pid=$!
        wait_for_pty "$tmpdir/pty0"
        wait_for_pty "$tmpdir/pty1"
        diagslave -m rtu "$tmpdir/pty1" &
        diagslave_pids="$! $diagslave_pids"
        go test -run "$TEST_FILTER" -v .
        ;;
    ascii)
        socat -d -d pty,raw,echo=0,link="$tmpdir/pty0" pty,raw,echo=0,link="$tmpdir/pty1" &
        socat_pid=$!
        wait_for_pty "$tmpdir/pty0"
        wait_for_pty "$tmpdir/pty1"
        diagslave -m ascii "$tmpdir/pty1" &
        diagslave_pids="$! $diagslave_pids"
        go test -run "$TEST_FILTER" -v .
        ;;
    *)
        echo "Usage: $0 {tcp|rtu|ascii} TEST_FILTER"
        exit 1
        ;;
esac
