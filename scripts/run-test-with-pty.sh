#!/bin/sh
set -e

MODE=$1
TEST_FILTER=$2

tmpdir=$(mktemp -d)

cleanup() {
    pkill -P $$ 2>/dev/null || true
    rm -rf "$tmpdir"
}

trap cleanup EXIT INT TERM

case "$MODE" in
    tcp)
        diagslave -m tcp -p 5020 &
        diagslave -m enc -p 5021 &
        go test -run "$TEST_FILTER" -v .
        ;;
    rtu)
        socat -d -d pty,raw,echo=0,link="$tmpdir/pty0" pty,raw,echo=0,link="$tmpdir/pty1" &
        sleep 0.5
        diagslave -m rtu "$tmpdir/pty1" &
        go test -run "$TEST_FILTER" -v .
        ;;
    ascii)
        socat -d -d pty,raw,echo=0,link="$tmpdir/pty0" pty,raw,echo=0,link="$tmpdir/pty1" &
        sleep 0.5
        diagslave -m ascii "$tmpdir/pty1" &
        go test -run "$TEST_FILTER" -v .
        ;;
    *)
        echo "Usage: $0 {tcp|rtu|ascii} TEST_FILTER"
        exit 1
        ;;
esac
