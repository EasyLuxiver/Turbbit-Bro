extends Node
## FEEL-10 P1-B：A/B/C/D/G 五个“能实际进”的制作人测试场景。
##
## 每个场景都真实实例化 race.tscn（正式物理、输入、HUD），只把关卡换成
## 一段短测试：R 重置，F10 回测试菜单。测试期间 GameManager.test_no_best
## 阻止写 best.json；G 用完整 55 组从 14200 起跑。
##
## A: 单角色事故 + J 手动演示真实联合
## B: 兔子落水救援 + K 演示救援中碰撞不记账
## C/D: 把兔子/乌龟推到 RESTLESS，观察前摇与不服从
## G: Z1→Z2 入场

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelData = preload("res://scripts/systems/level_data.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var mode := "A"
var race: Node = null
var title := ""
var body := ""
var status_label: Label
var _help_panel: PanelContainer
var _help_t := 0.0
var _reloading := false
var _last_burst := ""


func _ready() -> void:
	GameManager.test_no_best = true
	mode = GameManager.producer_mode if GameManager.producer_mode != "" else "A"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = "rabbit"
	race = load("res://scenes/race.tscn").instantiate()
	add_child(race)
	await get_tree().process_frame
	await get_tree().process_frame
	race.opening_active = false
	race.test_no_finish = true
	race.test_no_coop_hint = true
	race.test_disable_hazards = true
	race.world_end = 3600.0
	race.turtle.reset(Vector2(500.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	match mode:
		"A":
			_setup_a()
		"B":
			_setup_b()
		"C":
			_setup_drift("turtle")
		"D":
			_setup_drift("rabbit")
		"G":
			_setup_g()
	_build_overlay()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			_demo.call_deferred(a.substr(7))


func _demo(which: String) -> void:
	await get_tree().create_timer(0.8).timeout
	if which == "J" and mode == "A":
		_force_joint()
		await get_tree().create_timer(0.3).timeout
		print("DEMO A joint=%d accidents=%d show=%.2f" % [
			GameManager.joint_accident_count, GameManager.accident_count,
			float(race.joint_show_t)])
	elif which == "K" and mode == "B":
		var before: int = GameManager.accident_count
		var bro: int = GameManager.bro_meter
		_force_rescue_hit()
		await get_tree().create_timer(0.2).timeout
		print("DEMO B accidents %d->%d bro %d->%d mount=%s" % [
			before, GameManager.accident_count, bro, GameManager.bro_meter,
			String(race.mount.state)])
	get_tree().quit(0)


func _capture() -> void:
	await get_tree().create_timer(1.2).timeout
	var dir := ProjectSettings.globalize_path(
		"res://docs/reports/longrun/feel10-p1b")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(
		dir.path_join("producer-%s.png" % mode))
	get_tree().quit(0)


func _setup_a() -> void:
	title = "A  单角色 / 联合事故"
	body = ("↑ 撞海鸥：只有兔子扣一格 BRO。\n"
		+ "按 J：把兔子和乌龟同时推进真实危险（≤0.6 s）→ 播联合事故。\n"
		+ "观察：撞鸟时 joint 仍为 0；J 之后 joint=1、两人冻结。")
	var spec := {"group": "producer_gull", "zone": 1, "kind": "LOW_BIRD",
		"x": 1600.0, "w": 120.0}
	race.load_level([LevelData.build_group(spec)], [])
	race.test_disable_hazards = false
	race.world_end = 3200.0


func _setup_b() -> void:
	title = "B  救援免疫"
	body = ("已在起点触发兔子落水。SHIFT 到乌龟、按住 ↓ 去接。\n"
		+ "按 K：在救援上下文中再发生一次碰撞，观察 accidents/BRO 不变。\n"
		+ "观察：救援成功/失败本身不再喂 BRO，也不触发联合。")
	race.load_level([], [])
	race.world_end = 3600.0
	race._trigger_accident("RABBIT_WATER")


func _setup_drift(who: String) -> void:
	title = ("C  TUBO 神游" if who == "turtle" else "D  BITT 神游")
	body = ("你在控%s，%s在旁边神游。已把它推到 RESTLESS（约 8.5/12）。\n"
		+ "等 1–2 s：先出现 0.35 s 前摇，再 0.70 s 不服从；你手上的角色仍可操作。\n"
		+ "观察状态栏的 drift / burst / refuse，结束后 3 s 会再次尝试。") % [
			"乌龟" if who == "rabbit" else "兔子",
			"兔子" if who == "rabbit" else "乌龟"]
	race.load_level([], [])
	race.test_disable_hazards = true
	race.world_end = 3600.0
	# 神游只在“没被控”的角色身上累积；要观察兔子就控乌龟，反之亦然。
	if who == "rabbit":
		race.rabbit_brain.drift = Tuning.DRIFT_RESTLESS_END + 0.5
		race.rabbit.drift = Tuning.DRIFT_RESTLESS_END + 0.5
		GameManager.set_control("turtle")
	else:
		race.turtle_brain.drift = Tuning.DRIFT_RESTLESS_END + 0.5
		race.turtle.drift = Tuning.DRIFT_RESTLESS_END + 0.5
		GameManager.set_control("rabbit")


func _setup_g() -> void:
	title = "G  Z1 → Z2 入场"
	body = ("从 14200 起跑。远景码头先出现，屋顶/近景在过界前后渐入，\n"
		+ "区域提示在 15000，第一组 Z2 障碍（鳗鱼）在 15800。\n"
		+ "观察：接缝是渐变不是硬切；第一组障碍前环境已实心。")
	race.load_level(LevelData.groups(), [])
	race.test_disable_hazards = false
	race.turtle.position = Vector2(14200.0, race.surface_ref())
	race.rabbit.attach(race.turtle.get_mount_point())
	race._update_zone()
	race._update_camera()
	race._update_dock()


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(300, 16)
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(UiTheme.make_label(title, 22, UiTheme.GOLD))
	var b := UiTheme.make_label(body, 15, Color(0.85, 0.94, 1.0))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(b)
	var keys := UiTheme.make_label("H 说明 · R 重置 · F10 返回测试菜单", 14,
		Color(0.62, 0.78, 0.86))
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(keys)
	_help_panel = panel
	_help_t = 6.0
	# 状态行单独放左下（氧气面板上方），不跟着说明一起挡住中央反馈。
	var sp := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.09, 0.14, 0.86)
	st.set_corner_radius_all(8)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	sp.add_theme_stylebox_override("panel", st)
	sp.position = Vector2(18, 552)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sp)
	status_label = UiTheme.make_label("", 14, Color(0.55, 0.95, 0.9))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sp.add_child(status_label)


func _process(delta: float) -> void:
	if _help_panel != null and _help_t > 0.0:
		_help_t -= delta
		if _help_t <= 0.0:
			_help_panel.visible = false
	if race == null or status_label == null:
		return
	var g := "accidents=%d  BRO=%d/3  joint=%d  control=%s" % [
		GameManager.accident_count, GameManager.bro_meter,
		GameManager.joint_accident_count, GameManager.current_control]
	if mode == "A" or mode == "B":
		g += "  mount=%s" % String(race.mount.state)
	if mode == "A":
		g += "  joint_show=%.1f" % float(race.joint_show_t)
	if mode == "C" or mode == "D":
		g += "  drift R=%.2f T=%.2f  burst=%s/%s  refuse R=%.2f T=%.2f" % [
			float(race.rabbit.drift), float(race.turtle.drift),
			String(race._burst_who), String(race._burst_phase),
			float(race._rabbit_refuse_t), float(race._turtle_refuse_t)]
		var bnow := "%s/%s" % [String(race._burst_who), String(race._burst_phase)]
		if bnow != _last_burst:
			_last_burst = bnow
			print("PRODUCER BURST mode=%s %s at t=%.2f" % [mode, bnow,
				GameManager.race_time])
	if mode == "G":
		g += "  x=%.0f  zone=%d" % [float(race.turtle.position.x),
			GameManager.zone]
	status_label.text = g


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_R and not _reloading:
		_reloading = true
		get_tree().reload_current_scene.call_deferred()
		get_viewport().set_input_as_handled()
	elif key == KEY_F10:
		get_tree().change_scene_to_file("res://scenes/producer_menu.tscn")
		get_viewport().set_input_as_handled()
	elif key == KEY_H:
		if _help_panel != null:
			_help_panel.visible = not _help_panel.visible
			_help_t = 6.0 if _help_panel.visible else 0.0
		get_viewport().set_input_as_handled()
	elif key == KEY_J and mode == "A":
		_force_joint()
		get_viewport().set_input_as_handled()
	elif key == KEY_K and mode == "B":
		_force_rescue_hit()
		get_viewport().set_input_as_handled()


## A 的演示键：把两人同时放进真实危险，让 _update_true_joint 自己判。
func _force_joint() -> void:
	race.rabbit.state = "FALLING_WATER"
	race.mount.state = "RESCUE_FALLING"
	race.turtle.accident = true
	race.turtle_repair = 2.0
	race.accident_event_time = 0.0
	race._rabbit_danger_since = 0.0
	race._turtle_danger_since = 0.0
	race._joint_episode_done = false
	GameManager.accident_state = "NONE"
	race._update_true_joint(0.0)


## B 的演示键：保留救援上下文，清掉“当前事故”这层门（真实碰撞时它就是
## 事故状态本身），再走正式 _trigger_accident，观察它不记账。
func _force_rescue_hit() -> void:
	GameManager.accident_state = "NONE"
	race.mount.state = "RESCUE_FALLING"
	race.hazard_cooldown = 0.0
	race._trigger_accident("RABBIT_WATER")
