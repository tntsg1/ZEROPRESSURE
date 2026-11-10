#!/usr/bin/env bash
# 128 号 第 7 段: one hulk per run — from the snapshot after hulk N-1 to the one after hulk N (test saves only)
n="$1"; prev=$((n-1))
cd "$(dirname "$0")/.."
d="$APPDATA/Godot/app_userdata/零压拆船厂 ZERO PRESSURE"
tools/seg7_restore.sh "after$prev" || exit 1
timeout 600 tools/run_test.sh tests/seg7_flow.gd --fixed-fps 60 -- budget=560 > tests/out/seg7_ship$n.txt 2>&1
mkdir -p "$d/seg7_snap_after$n"
cp "$d"/zp_test_seg7_* "$d/seg7_snap_after$n/" 2>/dev/null
cp tests/out/seg7_events.jsonl "$d/seg7_snap_after$n/"
grep "^\[seg7\|^SEG7\|SCRIPT ERROR" tests/out/seg7_ship$n.txt | grep -v "\"look\"\|progress" | cut -c1-260
