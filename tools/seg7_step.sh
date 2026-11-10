#!/usr/bin/env bash
# 128 号 第 7 段: one run of at most ~9.5 min from snapshot FROM to snapshot TO (test saves only).
# A hulk that takes longer is simply carried on from TO in the next run.
from="$1"; to="$2"
cd "$(dirname "$0")/.."
d="$APPDATA/Godot/app_userdata/零压拆船厂 ZERO PRESSURE"
tools/seg7_restore.sh "$from" || exit 1
timeout 590 tools/run_test.sh tests/seg7_flow.gd --fixed-fps 60 -- budget=530 $SEG7_ARGS > "tests/out/seg7_run_$to.txt" 2>&1
mkdir -p "$d/seg7_snap_$to"
rm -f "$d/seg7_snap_$to"/zp_test_seg7_*
cp "$d"/zp_test_seg7_* "$d/seg7_snap_$to/" 2>/dev/null
cp tests/out/seg7_events.jsonl "$d/seg7_snap_$to/"
grep "^\[seg7\|^SEG7\|SCRIPT ERROR" "tests/out/seg7_run_$to.txt" | grep -v "\"look\"\|progress\|\"beat\"" | cut -c1-240 | tail -40
