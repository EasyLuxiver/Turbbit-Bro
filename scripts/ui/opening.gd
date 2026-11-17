extends CanvasLayer
## Phase V P2-7：可跳过的开场占位（6 s）。
## 只用原生 Control / Label，不引入美术或音频素材。
## 任意键 / 鼠标点击立即跳过；期间比赛不推进（由 race 冻结）。
## 正式入口：race.tscn 启动时自动挂载；--capture-* 与 headless 测试不挂。

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

## 5–8 s 的窗口里取中值：够读出标题，又不拖住想直接开跑的人。
const OPENING_TIME := 6.0

var _race: Node
var _root: Control
var _t := 0.0
var _done := false


func setup(race: Node) -> void:
	_race = race


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Locale.language_changed.connect(_on_locale_changed)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t >= OPENING_TIME:
		_finish()


## 任意键 / 左键点击都跳过；消费事件，避免同时触发 SHIFT / ESC。
func _input(event: InputEvent) -> void:
	if _done:
		return
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if pressed:
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	visible = false
	if _race != null and _race.has_method("on_opening_finished"):
		_race.on_opening_finished()
	queue_free()


func _on_locale_changed(_code: String = "") -> void:
	if _done:
		return
	if _root != null and is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = null
	_build()


func _build() -> void:
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.09, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	box.add_child(UiTheme.make_label(Locale.t("menu.title"), 76, UiTheme.GOLD))
	box.add_child(UiTheme.make_label(Locale.t("opening.subtitle"), 22,
		Color(0.78, 0.9, 0.98)))
	box.add_child(UiTheme.make_label(Locale.t("opening.ready"), 30,
		Color(0.95, 0.95, 0.95)))
	# FEEL-09 P1-A：开场只教“基础移动/跳跃”，不堆三行长字；
	# SHIFT 等第一道必须换人的障碍（gate1）再教。食物只留一句，不写数值。
	# 食物规则的完整版仍在暂停页和第一次接近食物时。
	box.add_child(UiTheme.make_label(Locale.t("opening.hint"), 20,
		Color(0.62, 0.8, 0.9)))
	# 食物规则放在第一次接近食物时也有一份；开场先说一句，玩家不用等。
	box.add_child(UiTheme.make_label(Locale.t("opening.food"), 18,
		Color(0.72, 0.88, 0.8)))

	var skip := UiTheme.make_label(Locale.t("opening.skip"), 18,
		Color(0.95, 0.8, 0.35, 0.9))
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	skip.offset_top = -64.0
	skip.offset_bottom = -24.0
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(skip)
