extends Node
## TBB-EXPERIENCE-REFINE-06 P5：角色反馈截图取证（只做视觉取证，不改判定）。
##
## 五张：
##   1) rabbit-splash   兔子穿水那一帧的水花；
##   2) rabbit-approach 兔子在水里，乌龟正下潜靠近（看得见“去接”）；
##   3) rabbit-catch    接住后抬回壳上的过程（在水里/壳之间）；
##   4) turtle-flip     乌龟被浪掀翻：肚皮朝天、四肢乱蹬；
##   5) turtle-recovered 掀翻 + 入水结束后回到正常巡航。
##
## 运行（需要渲染，不能 --headless）：
##   godot --path TURBBIT res://scenes/stage4_char_feedback_capture.tscn
## 输出：screenshots/refine06-p5-*.png

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const STEP := 1.0 / 60.0
const SHOTS := {
	"rabbit_splash": "res://screenshots/refine06-p5-rabbit-splash.png",
	"rabbit_approach": "res://screenshots/refine06-p5-rabbit-approach.png",
	"rabbit_catch": "res://screenshots/refine06-p5-rabbit-catch.png",
	"turtle_flip": "res://screenshots/refine06-p5-turtle-flip.png",
	"turtle_recovered": "res://screenshots/refine06-p5-turtle-recovered.png",
}

var is_runner := false
var race: Node = null


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4CharFeedbackCaptureRunner"
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
		push_error("P5 CAPTURE: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	Input.action_release("down")
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	# 1) 落水：从水线上方掉下去，抓穿水那一帧（水花圈在真实落点）。
	_clean()
	GameManager.current_control = "turtle"
	race.rabbit.position = race.turtle.position + Vector2(-30.0, -70.0)
	race.rabbit.velocity = Vector2(0.0, 320.0)
	race.rabbit.state = "FALLING_WATER"
	race._trigger_accident("RABBIT_WATER")
	var guard := 0
	while String(race.mount.state) == "RESCUE_FALLING" and guard < 120:
		race._physics_process(STEP)
		guard += 1
	_step(0.06)
	await _shot("rabbit_splash", "mount=%s splash_t=%.2f" % [
		String(race.mount.state), race.rescue_splash_t])

	# 2) 靠近：刚开始下潜 0.1 s，兔子还在水里、乌龟正在下去。
	Input.action_press("down")
	_step(0.10)
	Input.action_release("down")
	await _shot("rabbit_approach", "mount=%s r=%s t=%s" % [
		String(race.mount.state),
		str(race.rabbit.position.round()),
		str(race.turtle.position.round())])

	# 3) 接住：一帧一帧下潜到 CARRYING，抓抬回壳上的过程（不跳过整段）。
	Input.action_press("down")
	guard = 0
	while String(race.mount.state) != "CARRYING" and guard < 240:
		race._physics_process(STEP)
		guard += 1
	Input.action_release("down")
	_step(0.02)
	await _shot("rabbit_catch", "mount=%s r=%s" % [
		String(race.mount.state), str(race.rabbit.position.round())])

	# 4) 翻肚皮：浪击后 0.35 s，翻到肚皮朝天、四肢在蹬。
	_clean()
	GameManager.current_control = "turtle"
	race._turtle_contact("probe_reef", "SHARK")
	_step(0.35)
	await _shot("turtle_flip", "flip_t=%.2f state=%s" % [
		race.turtle.flip_t, String(race.turtle.state)])

	# 5) 恢复：掀翻 + 入水都走完，回到巡航。
	guard = 0
	while (race.turtle.flip_t > 0.0 or race.turtle.dunk_timer > 0.0
			or String(race.turtle.state) != "CRUISING") and guard < 600:
		race._physics_process(STEP)
		guard += 1
	_step(0.1)
	await _shot("turtle_recovered", "flip_t=%.2f state=%s speed=%.0f" % [
		race.turtle.flip_t, String(race.turtle.state), race.turtle.speed])

	get_tree().quit(0)


func _clean() -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	race.showtime_active = false
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.rabbit_stun = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.emergency_timer = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	race.rescue_splash_t = -1.0
	race.reset_brains()
	race.turtle.reset(Vector2(5000.0, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _step(seconds: float) -> void:
	var guard := 0
	while guard < int(seconds / STEP):
		race._physics_process(STEP)
		guard += 1


func _shot(tag: String, note: String) -> void:
	race.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err: int = img.save_png(ProjectSettings.globalize_path(String(SHOTS[tag])))
	print("P5 CAPTURE %s: %s saved err=%d" % [tag, note, err])
