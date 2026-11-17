extends Node
## FEEL-10 P0-C：两个新操作动词的独立试玩段。
##
## mode = "current"：强水流浮木，安全通道随浪相位在“上面跳/下面潜”之间切换。
## mode = "net"：状态吊网，控乌龟时绞盘把网拉高（兔层让开），控兔子时网停在低位。
##
## 独立场景，不进正式 55 组；R 重开，ESC 暂停沿用比赛场景。

const LevelData = preload("res://scripts/systems/level_data.gd")

@export var mode := "current"
var race: Node
var _hint: Label


func _ready() -> void:
	GameManager.state = GameManager.GameState.RUNNING
	race = load("res://scenes/race.tscn").instantiate()
	add_child(race)
	await get_tree().process_frame
	await get_tree().process_frame
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = false
	race.test_no_coop_hint = true
	var spec: Dictionary
	if mode == "net":
		spec = {"group": "p0c_net", "zone": 1, "kind": "LOW_BIRD",
			"x": 1200.0, "w": 150.0, "identity": "state_net"}
	else:
		# amp 必须同时越过两条门槛，安全通道才会真的交替：
		#   抬到最高时，浮木上沿压到跳跃顶点以上 → 只能下潜；
		#   压到最低时，浮木下沿伸进下潜壳层 → 只能起跳。
		# 70 只够压住下潜，跳跃永远成立；100 才让“看水线选路”成为真选择。
		spec = {"group": "p0c_current", "zone": 1, "kind": "FLOATING_LOG",
			"x": 1200.0, "w": 32.0,
			"motion": {"name": "current_log", "axis": "y", "amp": 100.0,
				"period": 6.0, "bias": 0.0}}
	var group := LevelData.build_group(spec)
	race.load_level([group], [])
	race.world_end = 2600.0
	race.turtle.reset(Vector2(400.0, LevelData.SURFACE_Y + 34.0))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	# 独立试玩段用自己的教学句，不让正式 55 组的 “浮木上下都挡 - 跳→潜”
	# 覆盖这里的新规则；否则底栏说的和实际安全窗相反。
	race.lesson_seen[race._lesson_key(group)] = true
	race.motion_lesson_zone = 1
	GameManager.prompt.emit("浮木高 → ↓ 下潜　|　浮木低 → ↑ 起跳"
		if mode == "current" else "网低 → ↓ 趴低　|　切乌龟 → 绞盘拉高")
	_build_hint()


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_hint.position = Vector2(24, 620)
	_hint.size = Vector2(1200, 80)
	_hint.text = ("强水流：浮木被水推着上下走。浮木抬到最高时跳不过去，"
		+ "要下潜；压到最低时潜不过去，要起跳。\nR 重开 · F10 返回 · ESC 暂停") \
		if mode == "current" \
		else ("状态吊网：控兔子时网在低位，需要趴低；换到乌龟，绞盘把网拉高，"
		+ "兔层直接让开。\nR 重开 · F10 返回 · ESC 暂停")
	layer.add_child(_hint)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.physical_keycode == KEY_F10:
		get_tree().change_scene_to_file("res://scenes/producer_menu.tscn")
