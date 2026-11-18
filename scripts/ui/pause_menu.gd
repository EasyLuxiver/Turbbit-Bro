extends CanvasLayer
## 暂停菜单：继续 / 重新开始 / 返回主菜单。
## 全部是可点的原生按钮；ESC / R / M 只是快捷键，不是唯一入口。
## 语言切换时原地重建文字，不丢暂停状态。

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _root: Control
var _resume_button: Button
var _widgets: Array[Button] = []
const HELP_PAGES := 7
var _help_page := 0
var _help_body: Label
var _help_page_label: Label
var _help_prev: Button
var _help_next: Button
var _was_paused := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_locale_changed()
	Locale.language_changed.connect(_locale_changed)


func _process(_delta: float) -> void:
	var paused := GameManager.state == GameManager.GameState.PAUSED
	visible = paused
	if paused and not _was_paused:
		_rebuild()
		if _resume_button != null and is_instance_valid(_resume_button):
			_resume_button.grab_focus.call_deferred()
	_was_paused = paused


func _locale_changed(_code: String = "") -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	if _root != null and is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = null
	_widgets.clear()

	var layer := Control.new()
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root = layer

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	box.add_child(UiTheme.make_label(Locale.t("pause.title"), 52, UiTheme.GOLD))
	box.add_child(UiTheme.make_label(Locale.t("pause.breath"), 22,
		Color(0.8, 0.92, 1.0)))
	box.add_child(_spacer(10))
	_resume_button = _button(box, Locale.t("pause.resume"),
		func() -> void: GameManager.toggle_pause(), true)
	var restart := _button(box, Locale.t("pause.restart"),
		func() -> void: GameManager.start_race())
	var menu := _button(box, Locale.t("pause.menu"),
		func() -> void: GameManager.go_to_menu())
	# FEEL-09 P1-A：帮助直接铺在暂停页，随时可重看（不新增按钮，
	# 保持 resume / restart / menu 三个入口的既有顺序与快捷键）。
	box.add_child(_spacer(2))
	box.add_child(UiTheme.make_label(Locale.t("pause.help_title"), 20,
		UiTheme.GOLD))
	_help_body = UiTheme.make_label("", 18, Color(0.82, 0.92, 1.0))
	_help_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_body.custom_minimum_size = Vector2(760, 0)
	box.add_child(_help_body)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	box.add_child(nav)
	_help_prev = _help_arrow(nav, "◀", -1)
	_help_page_label = UiTheme.make_label("", 16, Color(0.72, 0.86, 0.96))
	_help_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_page_label.custom_minimum_size = Vector2(52, 0)
	nav.add_child(_help_page_label)
	_help_next = _help_arrow(nav, "▶", 1)
	_set_help_page(_help_page)
	box.add_child(_spacer(6))
	# 帮助正文已经覆盖按键、障碍分工和食物；这里只留菜单快捷键。
	box.add_child(UiTheme.make_label(Locale.t("pause.keys"), 18,
		Color(0.68, 0.84, 0.94)))


func _help_arrow(parent: HBoxContainer, text: String, dir: int) -> Button:
	var button := Button.new()
	button.text = text
	UiTheme.style_button(button)
	# style_button 会把最小尺寸设成菜单按钮的 460×58，箭头要盖回来。
	button.custom_minimum_size = Vector2(44, 34)
	button.add_theme_font_size_override("font_size", 18)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: _set_help_page(_help_page + dir))
	parent.add_child(button)
	_widgets.append(button)
	return button


func _set_help_page(page: int) -> void:
	_help_page = clampi(page, 0, HELP_PAGES - 1)
	if _help_body == null or _help_page_label == null:
		return
	_help_body.text = Locale.t("pause.help_page_%d" % (_help_page + 1))
	_help_page_label.text = "%d/%d" % [_help_page + 1, HELP_PAGES]
	if _help_prev != null:
		_help_prev.disabled = _help_page <= 0
	if _help_next != null:
		_help_next.disabled = _help_page >= HELP_PAGES - 1


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _button(box: VBoxContainer, text: String, cb: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	UiTheme.style_button(button, primary)
	button.pressed.connect(cb)
	box.add_child(button)
	_widgets.append(button)
	return button
