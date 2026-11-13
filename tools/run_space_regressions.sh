#!/usr/bin/env bash
# 五类障碍空间重构后的回归闸门（2026-11-11 补充指令）。
# 逐个场景串行运行，日志落到 docs/reports/logs/space-<scene>.log。
# stage4_menu_input 需要真实窗口与焦点，单独跑（不加 --headless）。
# 已退役：stage2_playtest、stage4_driver（exit 2，见各自文件头）。
set -u

GODOT="D:/Godot_v4.7-stable_win64_console.exe"
PROJ="D:/GAMESTUDIO/TURBBIT"
OUT="$PROJ/docs/reports/logs"
mkdir -p "$OUT"

SCENES=(
  stage0_selftest
  stage1_selftest
  stage2_selftest
  stage3_selftest
  stage1_playtest
  stage4_proto
  stage4_core_experience
  stage4_metrics
  stage4_flow
  stage4_bilingual
  stage4_shift_graybox
  stage4_hud_priority
  stage4_surfboard
  stage4_experience_rework
  stage4_gear_ab
  stage4_level_audit
)

fail=0
for s in "${SCENES[@]}"; do
  log="$OUT/space-$s.log"
  timeout 360 "$GODOT" --headless --path "$PROJ" "res://scenes/$s.tscn" > "$log" 2>&1
  code=$?
  verdict=$(grep -E '(PASS|FAIL)$' "$log" | tail -1)
  echo "===== $s  exit=$code  $verdict"
  if [ "$code" -ne 0 ]; then
    fail=1
  fi
done

echo "SPACE REGRESSION RESULT: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
exit "$fail"
