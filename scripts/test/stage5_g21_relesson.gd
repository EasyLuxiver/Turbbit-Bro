extends Node
## REBUILD-05 G21：撞过的障碍类型，下一组再教一次。
##
## 问题（玩家视角）：首次教学一局只发一次。第一组海鸟没躲过去，后面三组同类型
## 就再也没人提醒——玩家已经知道“这里会撞”，却不知道“该怎么办”，只能靠猜。
##
## 做法（只改 `race.gd` 的记账分支）：一次碰撞真的记了账（`applied`）就把这一类
## 从 `lesson_seen` 里拿掉；下一组同类型进入提示范围时，`_update_lessons()` 会按
## 同样的 locale 文案再说一遍。干净通过不拿掉（看懂了的人不被打扰），冷却/事故
## 期间被挡下的碰撞也不算数（没有真实失误就不补课）。
##
## 用法：在正式 race 场景里用 `_physics_process(STEP)` 驱动（不是直接调判定），
## 输入只用来按住 ↓ 让兔子趴低。不改判定参数、不改赛道。
##
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g21_relesson.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g21-relesson.json"
const STEP := 1.0 / 60.0
const ALL_KINDS := ["SURFACE_ROCK", "LOW_BEAM", "LOW_BIRD", "SHARK",
	"DIVE_GATE", "FLOATING_LOG", "HIGH_WALL"]

var is_runner := false
var race: Node = null
var failures: Array = []
var prompts: Array = []
var rows: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G21ReLessonRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "zh"
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("G21: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = false
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	GameManager.prompt.connect(_on_prompt)

	# 窗口化取证：撞完 beam3、摆到 beam4 前，截一张“补教确实出现在正式 HUD 上”的图。
	if "--capture-relesson" in OS.get_cmdline_user_args():
		await _capture()
		return

	_case_beam_rearm()
	_case_clean_pass()
	_case_blocked_contact()
	_case_other_kind()
	_case_turtle_same_group()
	_case_reteach_cap()
	_report()
	print("G21 RELESSON: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## A：beam3 撞出真实硬直 → 重新武装 → beam4 前补教一次。
func _case_beam_rearm() -> void:
	var beam3 := _group("beam3")
	var beam4 := _group("beam4")
	var s3: float = LevelData.group_start(beam3)
	var e3: float = LevelData.group_end(beam3)
	var s4: float = LevelData.group_start(beam4)

	_reset(s3 - 900.0)
	_seed_except(["LOW_BEAM"])
	prompts.clear()
	_step_to(s3 - 700.0, 600)
	var first := _with_text(Locale.t("prompt.crouch"))
	_expect("A1 LOW_BEAM 首次教学在接近时发出一次", first.size() == 1)
	_expect("A2 首次教学文本与 locale 一致",
		first.size() == 1 and String(first[0]["text"]) == Locale.t("prompt.crouch"))
	_expect("A3 教学后 LOW_BEAM 标记为已教",
		race.lesson_seen.has(race._lesson_key(beam3)))

	# 不趴低，直接开进 beam3：真实碰撞、真实记账。
	var before: int = GameManager.accident_count
	_step_to(e3 + 40.0, 6000)
	var reasons := _reasons()
	_expect("A4 beam3 上真的记了一笔 RABBIT_STUN",
		GameManager.accident_count > before and reasons.has("RABBIT_STUN"))
	_expect("A5 撞完 LOW_BEAM 重新武装",
		not race.lesson_seen.has(race._lesson_key(beam3)))
	var only_low := true
	for g in race.hazard_groups:
		if String(g["kind"]) == "LOW_BEAM":
			continue
		if not race.lesson_seen.has(race._lesson_key(g)):
			only_low = false
	_expect("A6 其他类型仍保持已教（只有这一类型被拿掉）", only_low)
	rows.append({"case": "A", "accidents": GameManager.accident_count,
		"reasons": reasons, "seen_after_hit": race.lesson_seen.keys()})

	# 硬直自己解开，把乌龟摆到 beam4 前 700 px：同一类型应再教一次。
	_step_until(func() -> bool: return GameManager.accident_state == "NONE", 600)
	_teleport(s4 - 700.0)
	prompts.clear()
	_frames(3)
	var again := _with_text(Locale.t("prompt.crouch"))
	_expect("A7 下一组同类型（beam4）前重新发教学", again.size() == 1)
	_expect("A8 补教文本与首次一致",
		again.size() == 1 and String(again[0]["text"]) == Locale.t("prompt.crouch"))
	_expect("A9 补教后再次标记为已教",
		race.lesson_seen.has(race._lesson_key(beam4)))
	_teleport(s4 - 660.0)
	prompts.clear()
	_frames(3)
	_expect("A10 同一组不会连教两次", prompts.is_empty())


## F（REBUILD-05 G22）：同一类型补教只给一次。
## 撞 beam3 → beam4 前补教一次；再撞 beam4 → beam5 前不再复读，
## 而且撞第二组时不再重新武装（lesson_seen 仍保留）。
func _case_reteach_cap() -> void:
	var beam3 := _group("beam3")
	var beam4 := _group("beam4")
	var beam5 := _group("beam5")
	var s3: float = LevelData.group_start(beam3)
	var e3: float = LevelData.group_end(beam3)
	var s4: float = LevelData.group_start(beam4)
	var e4: float = LevelData.group_end(beam4)
	var s5: float = LevelData.group_start(beam5)

	_reset(s3 - 900.0)
	_seed_except(["LOW_BEAM"])
	prompts.clear()
	_step_to(s3 - 700.0, 600)
	_expect("F1 首次教学只发一次", _with_text(Locale.t("prompt.crouch")).size() == 1)

	var before1: int = GameManager.accident_count
	_step_to(e3 + 40.0, 6000)
	_expect("F2 beam3 记了一笔真实失误",
		GameManager.accident_count > before1 and _reasons().has("RABBIT_STUN"))
	_expect("F3 第一次撞完重新武装",
		not race.lesson_seen.has(race._lesson_key(_group("beam5"))))

	_step_until(func() -> bool: return GameManager.accident_state == "NONE", 600)
	_teleport(s4 - 700.0)
	prompts.clear()
	_frames(3)
	_expect("F4 beam4 前补教一次",
		_with_text(Locale.t("prompt.crouch")).size() == 1)

	# 第二次撞同一类型：开了 G21 会再清一次标记；G22 的上限不该清。
	var before2: int = GameManager.accident_count
	_step_to(e4 + 40.0, 6000)
	_expect("F5 beam4 上又记了一笔真实失误", GameManager.accident_count > before2)
	_expect("F6 补教用过一次后不再重新武装",
		race.lesson_seen.has(race._lesson_key(_group("beam5"))))

	_step_until(func() -> bool: return GameManager.accident_state == "NONE", 600)
	_teleport(s5 - 700.0)
	prompts.clear()
	_frames(5)
	_expect("F7 beam5 前不再复读同一类型", prompts.is_empty())
	rows.append({"case": "F", "accidents": GameManager.accident_count,
		"seen_after_second_hit": race.lesson_seen.keys(),
		"retaught": race.lesson_retaught.keys(),
		"prompts_at_beam5": prompts.duplicate(true)})


## B：LOW_BIRD 趴低干净通过 → 不重新武装 → bird4 前不再重复。
func _case_clean_pass() -> void:
	var bird3 := _group("bird3")
	var bird4 := _group("bird4")
	var s3: float = LevelData.group_start(bird3)
	var e3: float = LevelData.group_end(bird3)
	var s4: float = LevelData.group_start(bird4)

	_reset(s3 - 900.0)
	_seed_except(["LOW_BIRD"])
	prompts.clear()
	_step_to(s3 - 700.0, 600)
	var first := _with_text(Locale.t("prompt.net"))
	_expect("B1 LOW_BIRD 首次教学发出一次", first.size() == 1)
	var before: int = GameManager.accident_count
	Input.action_press("down")
	_step_to(e3 + 60.0, 4000)
	Input.action_release("down")
	_expect("B2 趴低干净通过、没有记账", GameManager.accident_count == before)
	_expect("B3 干净通过不重新武装", race.lesson_seen.has(race._lesson_key(bird3)))
	_teleport(s4 - 700.0)
	prompts.clear()
	_frames(3)
	_expect("B4 下一组同类型不再重复教学", prompts.is_empty())
	rows.append({"case": "B", "accidents": GameManager.accident_count,
		"seen_after_clean": race.lesson_seen.keys(),
		"prompts_at_bird4": prompts.duplicate(true)})


## C：冷却期被挡下的碰撞没有记账 → 不重新武装。
func _case_blocked_contact() -> void:
	var beam5 := _group("beam5")
	var s5: float = LevelData.group_start(beam5)
	_reset(s5 - 40.0)
	_seed_except([])
	race.lesson_seen["LOW_BEAM"] = true
	race.hazard_cooldown = 5.0
	var before: int = GameManager.accident_count
	_frames(60)
	_expect("C1 冷却期撞上不记账", GameManager.accident_count == before)
	_expect("C2 被冷却挡下的碰撞不重新武装",
		race.lesson_seen.has(race._lesson_key(_group("beam5"))))
	rows.append({"case": "C", "accidents": GameManager.accident_count,
		"seen_after_blocked": race.lesson_seen.keys()})


## D：别的类型不受影响——DIVE_GATE 仍然只教一次。
func _case_other_kind() -> void:
	var gate4 := _group("gate4")
	var s4: float = LevelData.group_start(gate4)
	_reset(s4 - 900.0)
	_seed_except(["DIVE_GATE"])
	prompts.clear()
	_step_to(s4 - 700.0, 600)
	var d1 := _with_text(Locale.t("prompt.sluice"))
	_frames(5)
	var d2 := _with_text(Locale.t("prompt.sluice"))
	_expect("D1 DIVE_GATE 教学仍只出现一次",
		d1.size() == 1 and d2.size() == 1)
	_expect("D2 没有别的类型被顺带重新发一遍", prompts.size() == 1)
	rows.append({"case": "D", "prompts": prompts.duplicate(true)})


## E：乌龟碰撞没有事故状态（只记一笔 TURTLE_WAVE），重新武装后同一帧就会轮到
## 教学循环——补教必须落在“下一组”，不能在刚撞上的这一组原地复读。
func _case_turtle_same_group() -> void:
	var shark3 := _group("shark3")
	var shark5 := _group("shark5")
	var s3: float = LevelData.group_start(shark3)
	var s5: float = LevelData.group_start(shark5)

	_reset(s3 - 900.0)
	_seed_except(["SHARK"])
	prompts.clear()
	_step_to(s3 - 700.0, 600)
	var first := _with_text(Locale.t("prompt.eel"))
	_expect("E1 SHARK 首次教学发出一次", first.size() == 1)
	# 不跃起，用壳直接开进 shark3：乌龟记账，但没有事故状态。
	# 巡逻鲨会往回巡 30 px，接触点可能落在组起点之前——正是“同一帧复读”的入口。
	var before_hit := prompts.size()
	var n := 0
	while not race.hit_roles.has("shark3") and n < 3000:
		race._physics_process(STEP)
		n += 1
	_expect("E2 shark3 真的撞了（TURTLE_WAVE）", race.hit_roles.has("shark3")
		and _reasons().has("TURTLE_WAVE"))
	_expect("E3 撞完 SHARK 重新武装",
		not race.lesson_seen.has(race._lesson_key(shark3)))
	_frames(5)
	_expect("E4 刚撞的这一组不会原地复读", prompts.size() == before_hit)
	_teleport(s5 - 700.0)
	_frames(3)
	var again := _with_text(Locale.t("prompt.eel"))
	_expect("E5 下一组同类型（shark5）前补教一次，位置在 shark5 前",
		again.size() == 2 and float(again[1]["x"]) >= s5 - 1200.0)
	rows.append({"case": "E", "prompts": prompts.duplicate(true),
		"seen_after_hit": race.lesson_seen.keys()})


# ---- 驱动 ----

func _reset(x: float) -> void:
	Input.action_release("down")
	Input.action_release("up")
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.rabbit_casualties = 0
	GameManager.turtle_failures = 0
	GameManager.rescue_success_count = 0
	GameManager.pickup_count = 0
	GameManager.showtime_active = false
	GameManager.set_control("rabbit")
	race.showtime_active = false
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
	race.rabbit_stun = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.emergency_timer = 0.0
	race.turtle_repair = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race._wrong_role_hinted = false
	race.reset_brains()
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.drift = 0.0
	race.turtle.dunk_timer = 0.0
	race.rabbit.reset()
	race.mount.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"


## 除了 `except` 里的类型，其余都算“已经教过”，隔离被观察的那一类。
func _seed_except(except: Array) -> void:
	race.lesson_seen.clear()
	race.lesson_retaught.clear()
	# FEEL-09 P0-A：Z2 新身份用 kind|identity 作课键；这里按实际组播种，
	# 不能再只播种 kind，否则 Z2 的同类组会被误判成“没教过”。
	for g in race.hazard_groups:
		if String(g["kind"]) in except:
			continue
		race.lesson_seen[race._lesson_key(g)] = true


func _step_to(x: float, limit: int) -> void:
	var n := 0
	while race.turtle.position.x < x and n < limit:
		race._physics_process(STEP)
		n += 1


func _step_until(pred: Callable, limit: int) -> void:
	var n := 0
	while not bool(pred.call()) and n < limit:
		race._physics_process(STEP)
		n += 1


func _frames(n: int) -> void:
	for i in n:
		race._physics_process(STEP)


func _teleport(x: float) -> void:
	race.turtle.position = Vector2(x, Tuning.NEUTRAL_DEPTH)
	race.rabbit.attach(race.turtle.get_mount_point())
	race.rabbit.position = race.turtle.get_mount_point()
	race.turtle.speed = 220.0
	race.hazard_cooldown = 0.0


# ---- 取证 ----

func _capture() -> void:
	var beam3 := _group("beam3")
	var beam4 := _group("beam4")
	_reset(LevelData.group_start(beam3) - 900.0)
	_seed_except(["LOW_BEAM"])
	_step_to(LevelData.group_start(beam3) - 700.0, 600)
	_step_to(LevelData.group_end(beam3) + 40.0, 6000)
	_step_until(func() -> bool: return GameManager.accident_state == "NONE", 600)
	_teleport(LevelData.group_start(beam4) - 700.0)
	_frame_and_wait()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://screenshots/rebuild05-g21-relesson.png"
	img.save_png(ProjectSettings.globalize_path(path))
	print("G21 CAPTURE: %s prompts=%d %s" % [path, prompts.size(),
		String(prompts[-1]["text"]) if prompts.size() > 0 else "-"])
	get_tree().quit(0)


## `_frames` 的 await 版本：捕捉分支要等真实帧（截图在窗口化下才有效）。
func _frame_and_wait() -> void:
	race._physics_process(STEP)


# ---- 记录 ----

func _on_prompt(text: String) -> void:
	prompts.append({
		"x": snappedf(race.turtle.position.x, 0.1),
		"text": text,
		"control": GameManager.current_control,
	})


func _with_text(text: String) -> Array:
	var out := []
	for p in prompts:
		if String(p["text"]) == text:
			out.append(p)
	return out


func _reasons() -> Array:
	# score_log 里的原因带 "mistake:" 前缀（note_mistake 记账口径），这里只取标签。
	var out := []
	for e in GameManager.score_log:
		out.append(String(e["reason"]).trim_prefix("mistake:"))
	return out


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _report() -> void:
	var payload := {
		"note": "正式 race 场景内用 _physics_process 驱动，不是真人试玩。",
		"cases": rows,
		"failures": failures,
	}
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("G21: cannot write %s" % OUT_PATH)
		return
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	print("G21: wrote %s" % OUT_PATH)
