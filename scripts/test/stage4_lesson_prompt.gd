extends Node
## PHASE J 首次教学提示的时机测量（只读，不改玩法）
##
## 验收标准：每种障碍第一次出现都带一次教学提示，且提示出现时距障碍 >= 1.0 s。
##
## 做法：关掉碰撞（test_disable_hazards），让乌龟按区基速自动跑完 55 组，
## 每帧检查 race.lesson_seen 是否新增了种类；新增的那一帧记录乌龟 x 与该组起点 x。
## 同时监听 GameManager.prompt，确认底部提示真的发出去了（不是只改了内部标记）。
##
## 注意：这个跑法没有任何按键输入，也不是真人；它只证明“提示逻辑在这些距离上触发”。
## 输出：docs/reports/logs/phase-j/lesson-prompts.json
## 运行：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_lesson_prompt.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/logs/phase-j/lesson-prompts.json"
const MAX_SIM := 600.0          # 比赛约 300 s，600 s 足够；防死循环

var is_runner := false
var race: Node = null
var sim := 0.0
var records: Array = []
var emissions: Array = []
var seen := {}
var last_prompt := ""
var last_prompt_sim := -1.0
var out_path := OUT_PATH
var accident_episodes := 0
var accident_seconds := 0.0
var _in_accident := false


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 480
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	for i in 3:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("LESSON: no current scene")
		get_tree().quit(1)
		return
	# 默认关碰撞（纯时机测量）；加 --hazards 则保留碰撞，用零输入乱撞去压提示时机。
	var uargs := OS.get_cmdline_user_args()
	var hazards_on := "--hazards" in uargs
	if hazards_on:
		out_path = "res://docs/reports/logs/phase-j/lesson-prompts-hazards.json"
	race.test_disable_hazards = not hazards_on
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	race.lesson_seen.clear()
	GameManager.prompt.connect(_on_prompt)
	GameManager.hint.connect(_on_hint)
	await get_tree().physics_frame

	# 每种障碍的第一次出现（按赛道顺序）
	var first_of_kind := {}
	for g in race.hazard_groups:
		var k := String(g["kind"])
		if not first_of_kind.has(k):
			first_of_kind[k] = {
				"group": String(g["group"]),
				"start": race._group_start(g),
				"zone": int(LevelData.zone_at(race._group_start(g))["id"]),
			}
	print("LESSON kinds=%d groups=%d" % [first_of_kind.size(), race.hazard_groups.size()])

	var t0 := sim
	var last_x: float = race.turtle.position.x
	while sim - t0 < MAX_SIM:
		await _step()
		var x: float = race.turtle.position.x
		for k in race.lesson_seen.keys():
			if seen.has(k):
				continue
			seen[k] = true
			var info: Dictionary = first_of_kind.get(k, {})
			var start := float(info.get("start", 0.0))
			var zone: Dictionary = LevelData.zone_at(start)
			var v := float(zone["base_speed"])
			var d := start - x
			var rec := {
				"kind": String(k),
				"group": String(info.get("group", "?")),
				"zone": int(zone["id"]),
				"turtle_x": snappedf(x, 0.1),
				"group_start_x": snappedf(start, 0.1),
				"distance_px": snappedf(d, 0.1),
				"base_speed": v,
				"seconds_to_obstacle": snappedf(d / v, 0.01),
				"prompt_text": last_prompt,
				"prompt_emitted_within_0_1s": absf(last_prompt_sim - sim) <= 0.1,
				"sim": snappedf(sim, 0.01),
			}
			records.append(rec)
			print("LESSON %-13s first=%-8s Z%d x=%.0f start=%.0f d=%.0f px (%.2f s) prompt=\"%s\" emitted=%s" % [
				rec["kind"], rec["group"], rec["zone"], x, start, d,
				rec["seconds_to_obstacle"], rec["prompt_text"],
				rec["prompt_emitted_within_0_1s"]])
		var in_acc: bool = GameManager.accident_state != "NONE"
		if in_acc and not _in_accident:
			accident_episodes += 1
		if in_acc:
			accident_seconds += 1.0 / 60.0
		_in_accident = in_acc
		if x >= race.world_end:
			break
		if x < last_x - 50.0:
			break
		last_x = x

	_write(first_of_kind)
	var bad := 0
	for r in records:
		if float(r["seconds_to_obstacle"]) < 1.0:
			bad += 1
	print("LESSON: DONE kinds_taught=%d/%d under_1s=%d accidents=%d (%.2f s)" % [
		records.size(), first_of_kind.size(), bad, accident_episodes, accident_seconds])
	get_tree().quit(0 if bad == 0 and records.size() == first_of_kind.size() else 3)


func _on_prompt(text: String) -> void:
	last_prompt = text
	last_prompt_sim = sim
	emissions.append({"sim": snappedf(sim, 0.01), "kind": "prompt", "text": text})


func _on_hint(text: String) -> void:
	emissions.append({"sim": snappedf(sim, 0.01), "kind": "hint", "text": text})
	if text != "" and last_prompt_sim < 0.0:
		last_prompt = text
		last_prompt_sim = sim


func _step() -> void:
	await get_tree().physics_frame
	sim += 1.0 / 60.0


func _write(first_of_kind: Dictionary) -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": ("零输入、碰撞开启的自动跑；只证明提示触发距离，不是真人试玩。"
			if out_path != OUT_PATH else "关碰撞、零输入的自动跑；只证明提示触发距离，不是真人试玩。"),
		"first_of_kind": first_of_kind,
		"accident_episodes": accident_episodes,
		"accident_seconds": snappedf(accident_seconds, 0.01),
		"records": records,
		"emissions": emissions,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(out_path), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
	print("LESSON wrote ", out_path)
