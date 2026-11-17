extends Node
## FEEL-09 P1-A — 教学时间线与文案长度（headless，真实 race.gd）。
##
## 关掉障碍判定，让乌龟按基础速度自然前进，记录底栏 prompt/hint 的第一次出现：
##   bird1（≈5.3 s）→ 趴低
##   gate1（≈15.5 s）→ 第一次必须 SHIFT
##   log1（≈27.3 s）→ BRO DIVE 连招
## 同时检查：没有三行以上的提示、没有空提示、SHIFT 提示确实带“为什么”。
##
## 输出：docs/reports/longrun/core-feel-09-p1a-tutorial-timeline.json

const OUT_PATH := "res://docs/reports/longrun/core-feel-09-p1a-tutorial-timeline.json"
const STEP := 1.0 / 60.0

var is_runner := false
var race: Node = null
var checks: Array = []
var sim := 0.0
var prompts: Array = []
var hints: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.set_language("zh")
	GameManager.start_race()
	for i in 10:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("tutorial: no race")
		_finish(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	GameManager.prompt.connect(_on_prompt)
	GameManager.hint.connect(_on_hint)
	while sim < 175.0 and race.turtle.position.x < 39000.0:
		race._physics_process(STEP)
		sim += STEP
	var first_crouch := _first_containing("趴低")
	var first_shift := _first_with("SHIFT")
	var first_combo := _first_containing("浮木")
	# 教学在 group_start - PROMPT_RANGE(1100) 触发：
	# bird1 460 / gate1 2700 / log1 5300。检查“在障碍之前、且不太早”。
	_check("prompt_bird1", not first_crouch.is_empty()
		and float(first_crouch["x"]) >= 400.0
		and float(first_crouch["x"]) <= 1560.0,
		"第一组趴低提示 @x=%.0f" % (float(first_crouch.get("x", -1))))
	_check("prompt_gate1_shift", not first_shift.is_empty()
		and float(first_shift["x"]) >= 2500.0
		and float(first_shift["x"]) <= 3800.0,
		"第一次 SHIFT 提示 @x=%.0f" % (float(first_shift.get("x", -1))))
	_check("prompt_log1_combo", not first_combo.is_empty()
		and float(first_combo["x"]) >= 5100.0
		and float(first_combo["x"]) <= 6400.0,
		"第一次连招提示 @x=%.0f" % (float(first_combo.get("x", -1))))
	var too_long := []
	for p in prompts:
		var text := String(p["text"])
		if text.count("\n") > 1:
			too_long.append(text.substr(0, 24))
		if text.strip_edges() == "":
			too_long.append("(empty)")
	_check("prompt_max_two_lines", too_long.is_empty(),
		"%d 条 prompt，全部 ≤2 行%s" % [prompts.size(), "" if too_long.is_empty()
			else "，异常：" + str(too_long)])
	var shift_has_why := false
	for p in prompts:
		var t := String(p["text"])
		if t.contains("SHIFT") and (t.contains("只有") or t.contains("水渠")
				or t.contains("浮木") or t.contains("高墙") or t.contains("船闸")
				or t.contains("礁拱") or t.contains("鲨鱼") or t.contains("吊网")
				or t.contains("鳗鱼")):
			shift_has_why = true
	_check("shift_prompt_explains_why", shift_has_why,
		"SHIFT 提示带原因=%s" % str(shift_has_why))
	_check("hints_present", hints.size() >= 2, "hint 条数=%d" % hints.size())
	# Z2 三个新身份各自有独立教学文案，且不是 Z1 的旧文本。
	var z2_ok := _any_containing("吊网") and _any_containing("水渠鳗鱼") \
		and _any_containing("船闸")
	_check("z2_identity_prompts", z2_ok,
		"Z2 吊网/鳗鱼/船闸文案都出现=%s" % str(z2_ok))
	var data := {
		"task": "TBB-CORE-FEEL-09 P1-A",
		"generated_at": Time.get_datetime_string_from_system(),
		"sim_s": snappedf(sim, 0.01),
		"prompts": prompts, "hints": hints, "checks": checks,
	}
	_write_json(OUT_PATH, data)
	var failed := 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
			print("FAIL  %s  %s" % [c["name"], c["detail"]])
		else:
			print("ok    %s  %s" % [c["name"], c["detail"]])
	print("P1A TUTORIAL: %d/%d checks pass" % [checks.size() - failed, checks.size()])
	print("P1A RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)


func _on_prompt(text: String) -> void:
	# 记录 HUD 实际会显示的文本（超过 40 字会在语义分隔处断成两行）。
	var shown := text
	if race != null and race.hud != null \
			and race.hud.has_method("_at_most_two_lines"):
		shown = race.hud._at_most_two_lines(text)
	prompts.append({"t": snappedf(sim, 0.01),
		"x": snappedf(race.turtle.position.x, 1.0), "text": shown})


func _on_hint(text: String) -> void:
	hints.append({"t": snappedf(sim, 0.01),
		"x": snappedf(race.turtle.position.x, 1.0), "text": text})


func _first_containing(needle: String) -> Dictionary:
	for p in prompts:
		if String(p["text"]).contains(needle):
			return p
	return {}


func _first_with(needle: String) -> Dictionary:
	for p in prompts:
		if String(p["text"]).contains(needle):
			return p
	return {}


func _any_containing(needle: String) -> bool:
	for p in prompts:
		if String(p["text"]).contains(needle):
			return true
	return false


func _near(x_text: String) -> Dictionary:
	var x := float(x_text)
	var best := {}
	var bd := 1.0e9
	for p in prompts:
		var d := absf(float(p["x"]) - x)
		if d < bd:
			bd = d
			best = p
	return best


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})


func _finish(code: int) -> void:
	get_tree().quit(code)


func _write_json(path: String, data: Dictionary) -> void:
	var abs := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
