extends Node
## TBB-EXPERIENCE-REBUILD-05 G7：日常落壳不再喊「好接！」的验收探针。
##
## 背景：普通跳跃落回壳上走的是 _apply_carry_result("pickup")，于是每次落地都弹
## 2 s 的「好接！」横幅。这条只改“报不报”，不改计数：pickup_count 仍然 +1。
##
## 验：
##   1) 普通跳跃：整段滞空结束、真正落回壳上，pickup_success 0 次、横幅不是「好接！」、
##      pickup_count 仍 +1；
##   2) 真正的接住（兔子离壳 200 px 的抬升完成）：pickup_success 1 次、横幅是「好接！」；
##   3) 救回横幅不受影响。
##
## 输出：docs/reports/longrun/rebuild05-g7-banner.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g7_banner.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g7-banner.json"
const STEP := 1.0 / 60.0
const CARRY_AWAY := Vector2(-200.0, 60.0)

var is_runner := false
var race: Node = null
var banner: Node = null
var out := {}
var failures: Array = []
var pickup_events := 0
var rescue_events := 0


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G7BannerRunner"
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
		push_error("G7 BANNER: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	banner = race.get_node_or_null("Banner")
	GameManager.pickup_success.connect(_on_pickup)
	GameManager.rescue_done.connect(_on_rescue)

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["plain_jump"] = _plain_jump()
	out["real_catch"] = _real_catch()
	out["rescue_banner"] = _rescue_banner()
	_evaluate()
	_write()
	print("G7 BANNER: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## 普通跳跃：空地起跳，跑满整段滞空直到落回壳上，落地那一帧读横幅。
func _plain_jump() -> Dictionary:
	_reset(200.0)
	var count0: int = GameManager.pickup_count
	pickup_events = 0
	Input.action_press("up")
	race._note_up_input()
	var jumped := false
	var landed := false
	var text_at_landing := ""
	var events_at_landing := -1
	for i in 150:
		race._physics_process(STEP)
		if i == 2:
			Input.action_release("up")
		var st := String(race.mount.state)
		if st == "AIRBORNE":
			jumped = true
		elif jumped and st == "RIDING" and not landed:
			landed = true
			text_at_landing = _banner_text()
			events_at_landing = pickup_events
			break
	return {
		"jumped": jumped,
		"landed": landed,
		"banner_at_landing": text_at_landing,
		"pickup_events": events_at_landing,
		"pickup_events_total": pickup_events,
		"pickup_count_delta": GameManager.pickup_count - count0,
		"expected_banner": Locale.t("banner.pickup"),
	}


## 真正的接住：兔子离壳 200 px，走真实抬升，落地那一帧读横幅。
func _real_catch() -> Dictionary:
	_reset(200.0)
	var count0: int = GameManager.pickup_count
	pickup_events = 0
	var mp: Vector2 = race.turtle.get_mount_point()
	race.rabbit.position = mp + CARRY_AWAY
	race._begin_carry("pickup", mp)
	var got := false
	var text := ""
	for i in 300:
		race._physics_process(STEP)
		if String(race.carry_kind) == "" and pickup_events > 0:
			got = true
			text = _banner_text()
			break
	return {
		"caught": got,
		"banner": text,
		"pickup_events": pickup_events,
		"pickup_count_delta": GameManager.pickup_count - count0,
	}


## 救回：旧行为还要在；只确认 rescue_done 仍会写横幅。
func _rescue_banner() -> Dictionary:
	_reset(200.0)
	rescue_events = 0
	var mp: Vector2 = race.turtle.get_mount_point()
	race.rabbit.position = mp + CARRY_AWAY
	GameManager.accident_state = "RABBIT_WATER"
	race._begin_carry("rescue", mp)
	for i in 300:
		race._physics_process(STEP)
		if String(race.carry_kind) == "" and rescue_events > 0:
			break
	return {"rescue_events": rescue_events, "banner": _banner_text()}


func _evaluate() -> void:
	var j: Dictionary = out["plain_jump"]
	_expect("plain jump: actually jumps and lands (%s/%s)"
		% [str(j.get("jumped", false)), str(j.get("landed", false))],
		bool(j.get("jumped", false)) and bool(j.get("landed", false)))
	_expect("plain jump: no NICE SAVE banner at landing (%s)"
		% String(j.get("banner_at_landing", "")),
		String(j.get("banner_at_landing", "")) != String(j.get("expected_banner", "?")))
	_expect("plain jump: pickup_success not emitted (%s)"
		% str(j.get("pickup_events", -1)),
		int(j.get("pickup_events", -1)) == 0)
	_expect("plain jump: pickup_count still +1 (%s)"
		% str(j.get("pickup_count_delta", 0)),
		int(j.get("pickup_count_delta", 0)) == 1)
	var c: Dictionary = out["real_catch"]
	_expect("real catch: pickup_success emitted once (%s)" % str(c.get("pickup_events", -1)),
		int(c.get("pickup_events", -1)) == 1)
	_expect("real catch: banner says NICE SAVE (%s)" % String(c.get("banner", "")),
		String(c.get("banner", "")) == Locale.t("banner.pickup"))
	_expect("real catch: pickup_count +1 (%s)" % str(c.get("pickup_count_delta", 0)),
		int(c.get("pickup_count_delta", 0)) == 1)
	_expect("rescue: still announces (%s)" % str(out["rescue_banner"].get("rescue_events", -1)),
		int(out["rescue_banner"].get("rescue_events", -1)) == 1)


func _banner_text() -> String:
	if banner == null or banner.label == null:
		return ""
	return String(banner.label.text)


func _on_pickup() -> void:
	pickup_events += 1


func _on_rescue() -> void:
	rescue_events += 1


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _reset(x: float, zone: Dictionary = {}) -> void:
	if zone.is_empty():
		zone = LevelData.zone_at(x)
	Input.action_release("up")
	Input.action_release("down")
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.oxygen_phase = "SAFE"
	GameManager.accident_count = 0
	GameManager.pickup_count = 0
	GameManager.showtime_active = false
	GameManager.clear_bro_meter()
	GameManager.current_control = "rabbit"
	GameManager.has_shifted = false
	GameManager.combo = 0
	race.showtime_active = false
	race.showtime_t = 0.0
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
	race._accident_t = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.combo = 0
	race.combo_max = 0
	race.celebrate_t = -1.0
	race.celebrate_kind = ""
	race.carry_kind = ""
	race.carry_dur = 0.0
	race.carry_t = 0.0
	race.motion_lesson_zone = -1
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.input_buffer_log.clear()
	race.reset_brains()
	race.current_zone = zone
	race.world_end = 1.0e9
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = float(zone["base_speed"])
	race.turtle.speed = float(zone["base_speed"])
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.drift = 0.0
	race.turtle.dunk_timer = 0.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"
	race._buf_action = ""
	race._buf_age = 0.0
	if banner != null and banner.label != null:
		banner.label.text = ""
		banner.timer = 0.0


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("G7 BANNER: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
