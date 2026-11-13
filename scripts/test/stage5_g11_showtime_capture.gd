extends Node
## REBUILD-05 G11：Showtime 截图取证修复的配套探针。
##
## 背景：`--capture-showtime` 原来把乌龟传送到 x=5100 —— 那里是 rock2（会下沉的礁）
## 的正中间。传送后 0.2 s 内就撞上，`start_showtime()` 因事故被拒，截出来的是
## 「咚！兔子被撞晕」，和文件名说的是两回事。修法是截图工具先关判定、再挪到
## rock2 组尾之后的空档（x=5300）。
##
## 这个探针不截图（headless 没有画面），只断言三件事：
##   1. 事故状态下 `start_showtime()` 仍然拒绝启动（修截图不能顺手把门槛拆了）；
##   2. 修后的条件（无事故、关判定、x=5300）能开起来，且 0.45 s 时兔子离壳 ≥ 40 px；
##   3. 这 0.45 s 里没有产生新事故，中心横幅是 `SHOWTIME！`。
##
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g11_showtime_capture.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g11-showtime.json"

var is_runner := false
var race: Node = null
var failures: Array = []
var centers: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G11ShowtimeRunner"
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
		push_error("G11: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	GameManager.center_message.connect(_on_center)

	# ---- 1. 事故状态下必须拒绝 ----
	GameManager.accident_state = "RABBIT_STUN"
	race.start_showtime()
	var refused_in_accident: bool = not race.showtime_active
	_expect("start_showtime refuses while accident_state != NONE", refused_in_accident)

	# ---- 2. 修后的截图条件能开起来 ----
	GameManager.accident_state = "NONE"
	race.test_disable_hazards = true
	race.turtle.position = Vector2(5300.0, race.surface_ref())
	race.turtle.speed = 220.0
	centers.clear()
	race.start_showtime()
	_expect("start_showtime starts in the fixed capture setup", race.showtime_active)
	_expect("center banner is SHOWTIME", centers.size() == 1
		and String(centers[0]) == Locale.t("center.showtime"))

	# 手动推进 0.45 s（物理已关，截图工具里这段时间由真实帧驱动）。
	var mount: Vector2 = race.turtle.get_mount_point()
	var steps := 30
	for i in steps:
		race._tick_showtime(0.45 / float(steps))
	var offset: float = mount.y - race.rabbit.position.y
	_expect("rabbit is airborne during showtime (>= 40 px above shell)", offset >= 40.0)
	_expect("no accident during the capture window",
		GameManager.accident_state == "NONE")
	_expect("showtime still active after 0.45 s (banner has time to show)",
		race.showtime_active)

	var payload := {
		"note": "正式 race 场景内手动调 start_showtime/_tick_showtime；不是真人试玩。",
		"capture_x": 5300.0,
		"refused_in_accident": refused_in_accident,
		"rabbit_offset_px": snappedf(offset, 0.1),
		"centers": centers,
		"failures": failures,
	}
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "  "))
		f.close()
		print("G11: wrote %s" % OUT_PATH)
	print("G11 SHOWTIME CAPTURE: " + ("PASS" if failures.is_empty() else "FAIL"))
	for fail in failures:
		print("  - " + fail)
	get_tree().quit(0 if failures.is_empty() else 1)


func _on_center(text: String, _color: Color) -> void:
	centers.append(text)


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)
