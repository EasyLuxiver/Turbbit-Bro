#!/bin/sh
# STAGE 0-4 回归批跑（QC 标准 5）。每个场景独立进程，串行，各自 5 分钟上限。
GODOT="D:/Godot_v4.7-stable_win64_console.exe"
cd /d/GAMESTUDIO/TURBBIT || exit 1
for s in stage0_selftest stage1_selftest stage2_selftest stage3_selftest \
         stage4_bilingual stage4_flow stage4_hud_priority stage4_shift_graybox \
         stage4_gear_ab stage4_level_audit stage4_metrics; do
  out="/tmp/reg_$s.txt"
  timeout 300 "$GODOT" --headless --path . "res://scenes/$s.tscn" > "$out" 2>&1
  code=$?
  fails=$(grep -c "FAIL" "$out" 2>/dev/null)
  pass=$(grep -c "PASS\|ok " "$out" 2>/dev/null)
  echo "$s exit=$code pass_lines=$pass fail_lines=$fails"
done
