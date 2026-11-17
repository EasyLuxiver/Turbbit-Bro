# Godot Editor MCP 接入

- 服务：`godot-editor-mcp` 2026.10.20.1（stable，PyPI）
- 插件：`addons/godot_mcp` 2026.10.20.1
- 配置：Claude Code user 作用域 `godot`，命令 `godot-editor-mcp`
- 桥接端口：**9081**（默认 9080 被 NahimicService 占用；插件 `mcp_bridge.gd` 与 MCP 环境变量都已改）

## 在游戏里启用的东西

- `project.godot` → `[editor_plugins]`：`res://addons/godot_mcp/plugin.cfg`
- `project.godot` → autoload：`MCPRuntimeProbe="*res://addons/godot_mcp/mcp_runtime_probe.gd"`
  - 只在 `EngineDebugger.is_active()` 时注册；导出的正式包/headless 测试里 no-op。
  - 删掉这行会失去运行时截图/输入/性能监控，但编辑器里的场景检查仍可用。

## 使用前提

1. Godot 编辑器打开 `D:\GAMESTUDIO\TURBBIT`，插件 dock 显示 connected。
2. Claude Code 重启后加载 `godot_*` 工具（当前会话没有，需重启或 `/mcp` reconnect）。
3. 用 `godot_runtime_play_scene` 启动游戏，然后：
   - `godot_runtime_capture_game_screenshot`
   - `godot_input_simulate_key / mouse / action`
   - `godot_profiling_get_performance_monitors`
   - `godot_runtime_get_game_scene_tree`
   - `godot_testing_run_test_scenario`

## 已验证

- 编辑器桥接：`bridge_connected=true`，addon 2026.10.20.1
- 通过 MCP 启动 `res://scenes/race.tscn`
- 截图：`docs/reports/longrun/mcp/race-start-0.png`、`race-play-0.png`
- 输入：Right / Space 注入返回 `sent=true`
- 性能：FPS 165、draw_calls 759、primitives 26973、node_count 78（编辑器 play 窗口，非 Web）

## 注意

- 交付/导出前如果不想带测试探针：删除 autoload `MCPRuntimeProbe`、移除 `[editor_plugins]`，或整个 `addons/godot_mcp` 不进包。
- 本轮没有改 best.json，没有导出 EXE。
