#!/usr/bin/env bash
# 128 号 第 7 段: put the seg7 test career back to a snapshot (tests only: user://zp_test_seg7_*)
d="$APPDATA/Godot/app_userdata/零压拆船厂 ZERO PRESSURE"
snap="$d/seg7_snap_$1"
[ -d "$snap" ] || { echo "no snapshot $1"; exit 1; }
rm -f "$d"/zp_test_seg7_*
cp "$snap"/zp_test_seg7_* "$d/"
# the log keeps the stages before the snapshot
[ -f "$snap/seg7_events.jsonl" ] && cp "$snap/seg7_events.jsonl" tests/out/seg7_events.jsonl
echo "restored $1"
