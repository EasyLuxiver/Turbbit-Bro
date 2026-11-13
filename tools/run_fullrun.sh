#!/bin/sh
# 完整赛道自动驾驶（QC 标准 1，stage3_playtest.gd 跑两场）。
# 自动驾驶是测试，不是玩家纪录：跑前备份 best.json，跑完原样写回，
# 保证测试不会把合成成绩留在玩家纪录里。
# 用法: tools/run_fullrun.sh [日志路径]
GODOT="D:/Godot_v4.7-stable_win64_console.exe"
cd /d/GAMESTUDIO/TURBBIT || exit 1
BEST="$APPDATA/Godot/app_userdata/Turbbit Bro!/best.json"
BK="/tmp/best_before_fullrun.json"
if [ -f "$BEST" ]; then cp "$BEST" "$BK"; fi
out="${1:-/tmp/fullrun.txt}"
timeout 1500 "$GODOT" --headless --path . res://scenes/stage3_playtest.tscn > "$out" 2>&1
code=$?
if [ -f "$BK" ]; then cp "$BK" "$BEST"; fi
echo "exit=$code log=$out"
grep -E "FINISH|RESULT|SELFTEST" "$out" | tail -20
