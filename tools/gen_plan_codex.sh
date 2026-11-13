#!/usr/bin/env bash
# 切割宝典: record and verify every ship type's codex plan (data/plan_codex/<ship>.json).
# Each type: tests/gen_plan_codex.gd (the salvage bot strips it, a WorkPlan records it, a fresh ship
# replays it on P and must come apart with no incident) — only a plan that replays is written.
# Off-screen, no focus, test careers only. Runs JOBS types at once; a summary table at the end.
# Usage: tools/gen_plan_codex.sh [ship ...]        (no ships: all the market's types but ARK-01/AX-40)
#        JOBS=3 LIMIT=1500 tools/gen_plan_codex.sh   (LIMIT: wall seconds per type)
cd "$(dirname "$0")/.."
JOBS=${JOBS:-3}
LIMIT=${LIMIT:-1500}
SHIPS="$*"
if [ -z "$SHIPS" ]; then
  SHIPS="gr7 s09 pod tug h22 m14 med47 fr26 pt34 jd38 tw64 hb86 cl104 es112 fl116 sv122 mf126 ro128 cv138 vt80 ps12 cf90 sa200 nr95 ih55 mt140 md160 tb180 ch110 my48 ic120 qc30 st40 ev55 dc84 ob90 fx70 bl88 lc140 dr150 hg170"
fi
LOG=${LOG:-/g/zp_logs/plan_codex}   # outside the repo
mkdir -p "$LOG" data/plan_codex
start=$(date +%s)
# the project must compile first (a half-saved script elsewhere left every run idle to its limit)
if ! timeout 120 /e/godot/godot47/Godot_v4.7-stable_win64_console.exe --path . --resolution 1280x720 --position -2600,40 --fixed-fps 60 -s tests/codex_probe.gd -- tug 2>&1 | grep -aq "^PROBE tug"; then
  echo "the project does not compile now; nothing generated"; exit 1
fi
one() {
  local s="$1" x=$((RANDOM % 400))
  timeout "$LIMIT" /e/godot/godot47/Godot_v4.7-stable_win64_console.exe --path . --resolution 1280x720 --position -2600,$((40 + x)) --fixed-fps 60 -s tests/gen_plan_codex.gd -- "$s" > "$LOG/$s.log" 2>&1
  local line
  line=$(grep -a "^CODEX $s " "$LOG/$s.log" | tail -1)
  [ -z "$line" ] && line="CODEX $s FAIL wall-clock limit ${LIMIT}s (or crashed)"
  if grep -aq "Parse Error\|Compile Error" "$LOG/$s.log"; then
    line="CODEX $s FAIL the project did not compile (another edit in progress?); its file kept"
  else
    case "$line" in *" PASS "*) ;; *) rm -f "data/plan_codex/$s.json" ;; esac   # only a verified plan stays
  fi
  echo "$line"
}
export -f one
export LIMIT LOG
printf "%s\n" $SHIPS | xargs -P "$JOBS" -I{} bash -c 'one {}' | tee "$LOG/summary.txt"
echo "total $(( $(date +%s) - start )) s; $(grep -c ' PASS ' "$LOG/summary.txt") pass, $(grep -c ' FAIL ' "$LOG/summary.txt") fail" | tee -a "$LOG/summary.txt"
