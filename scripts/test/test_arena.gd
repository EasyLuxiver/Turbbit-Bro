extends Node
## 动态障碍测试场：独立于正式赛局，鼠标面板生成/清除/重启。
## 复用 race.tscn 的移动、动作、碰撞、伏击/海鸟/鲨群逻辑。

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const KINDS := ["SURFACE_ROCK", "LOW_BIRD", "LOW_BEAM", "DIVE_GATE",
	"FLOATING_LOG", "SHARK", "HIGH_WALL", "SHARK6"]

var race: Node
var _option: OptionButton
var _slider: HSlider
var _status: Label


func _ready() -> void:
	GameManager.test_no_best = true
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = "rabbit"
	race = load("res://scenes/race.tscn").instantiate()
	race.test_no_opening = true
	add_child(race)
	await get_tree().process_frame
	await get_tree().process_frame
	race.opening_active = false
	race.test_no_finish = true
	race.test_no_lessons = true
	race.test_no_coop_hint = true
	race.test_disable_hazards = false
	race.world_end = 1.0e12
	race.load_level([], [])
	race.turtle.reset(Vector2(400.0, race.surface_ref()))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 220.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	GameManager.accident_state = "NONE"
	GameManager.oxygen = 8.0
	GameManager.total_score = 0
	_build_ui()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 260)
	panel.custom_minimum_size = Vector2(360, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = Locale.t("arena.title")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var lab := Label.new()
	lab.text = Locale.t("arena.type")
	lab.add_theme_font_size_override("font_size", 16)
	row.add_child(lab)
	_option = OptionButton.new()
	_option.add_theme_font_size_override("font_size", 16)
	_option.custom_minimum_size = Vector2(190, 36)
	for k in KINDS:
		_option.add_item(k)
	row.add_child(_option)
	# 横向滑动选择条：满足“滑动选择障碍类型”，和下拉框保持同步。
	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.max_value = KINDS.size() - 1
	_slider.step = 1
	_slider.value = 0
	_slider.custom_minimum_size = Vector2(320, 24)
	_slider.value_changed.connect(_on_slider)
	box.add_child(_slider)
	_option.item_selected.connect(_on_option_selected)

	box.add_child(_button(Locale.t("arena.spawn"), _on_spawn, UiTheme.GOLD))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	box.add_child(row2)
	row2.add_child(_button(Locale.t("arena.clear"), _on_clear))
	row2.add_child(_button(Locale.t("arena.restart"), _on_restart))
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	box.add_child(row3)
	row3.add_child(_button(Locale.t("arena.stands"), _on_stands))
	row3.add_child(_button(Locale.t("arena.intervene"), _on_intervene))
	box.add_child(_button(Locale.t("arena.menu"), _on_menu))

	_status = Label.new()
	_status.text = Locale.t("arena.hint")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(320, 0)
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(0.72, 0.86, 0.95))
	box.add_child(_status)


func _button(text: String, cb: Callable, color: Color = Color(0.93, 0.97, 1.0)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", color)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _on_slider(value: float) -> void:
	_option.selected = int(value)
	if _status != null:
		_status.text = KINDS[int(value)]


func _on_option_selected(index: int) -> void:
	_slider.value = index
	if _status != null:
		_status.text = KINDS[index]


func _on_spawn() -> void:
	if race == null:
		return
	var kind: String = KINDS[_option.selected]
	var g: Dictionary = race.spawn_test_group(kind, 700.0)
	_status.text = "%s  x=%.0f  %s" % [kind, race._group_start(g), g["group"]]


func _on_clear() -> void:
	if race == null:
		return
	race.clear_test_groups()
	GameManager.total_score = 0
	_status.text = "CLEAR"


func _on_restart() -> void:
	GameManager.test_no_best = true
	get_tree().reload_current_scene()


func _on_stands() -> void:
	if race == null:
		return
	race.show_shark_stands(10.0)
	_status.text = "STANDS"


func _on_intervene() -> void:
	# FEEL-49：随机摧毁障碍的鲨群干预已移除，保留按钮避免旧场景信号断线。
	_status.text = "INTERVENTION REMOVED"


func _on_menu() -> void:
	GameManager.test_no_best = false
	GameManager.state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
