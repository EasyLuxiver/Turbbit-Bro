extends Control
## 主菜单 + 设置：全部用原生控件做的可点菜单。
## 鼠标点按钮；键盘 ↑↓ 换焦点、Enter/Space 确认；S / L / Q 只是快捷方式，
## 不再是唯一入口。退出走二次确认，避免误触。文字全部走 Locale。

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _settings_open := false
var _quit_confirm_open := false
var _root: Control
var _focusables: Array[Button] = []
var _focus_index := 0


func _ready() -> void:
	queue_redraw()
	Locale.language_changed.connect(_on_language_changed)
	var args := OS.get_cmdline_user_args()
	if "--settings" in args or "--capture-settings" in args:
		_settings_open = true
	_build_ui()
	if "--capture-menu" in args:
		_capture_and_quit(_arg_after(args, "--capture-menu", "stage0_menu.png"))
	elif "--capture-settings" in args:
		_capture_and_quit(_arg_after(args, "--capture-settings", "stage4_settings.png"))
	elif "--autoplay" in args:
		# _ready 期间树正在加入节点，直接切场景会报 remove_child busy。
		GameManager.start_race.call_deferred()


func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.04, 0.12, 0.2))
	draw_circle(Vector2(view.x * 0.82, view.y * 0.2), 92.0, Color(1.0, 0.78, 0.35, 0.9))
	draw_rect(Rect2(0, view.y * 0.62, view.x, view.y * 0.38), Color(0.05, 0.33, 0.45))
	for i in range(7):
		var y := view.y * 0.62 + i * 20.0
		draw_line(Vector2(0, y), Vector2(view.x, y + sin(float(i)) * 7.0),
			Color(0.1, 0.45, 0.6, 0.35), 3.0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == 0:
		key = event.physical_keycode
	if _quit_confirm_open:
		if key in [KEY_ESCAPE, KEY_Q, KEY_BACKSPACE]:
			_close_quit_confirm()
			get_viewport().set_input_as_handled()
		return
	match key:
		KEY_L:
			Locale.toggle_language()
			get_viewport().set_input_as_handled()
		KEY_S:
			_settings_open = not _settings_open
			_refresh()
			get_viewport().set_input_as_handled()
		KEY_Q:
			_open_quit_confirm()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE, KEY_BACKSPACE:
			if _settings_open:
				_settings_open = false
				_refresh()
			else:
				# 主菜单的 ESC 不再直接退出游戏，改为弹确认。
				_open_quit_confirm()
			get_viewport().set_input_as_handled()


func _on_language_changed(_code: String) -> void:
	_refresh()


func _refresh() -> void:
	_build_ui()


func _build_ui() -> void:
	# 记下当前焦点位置，重建后尽量落回同一个按钮。
	if not _focusables.is_empty():
		var owner := get_viewport().gui_get_focus_owner()
		var idx := _focusables.find(owner)
		if idx >= 0:
			_focus_index = idx
	if _root != null and is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = null
	_focusables.clear()

	var layer := Control.new()
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root = layer

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	if _settings_open:
		_build_settings(box)
	else:
		_build_main(box)

	if _quit_confirm_open:
		_build_quit_confirm(layer)

	_grab_focus.call_deferred()


func _build_main(box: VBoxContainer) -> void:
	box.add_child(UiTheme.make_label(Locale.t("menu.title"), 72, UiTheme.GOLD))
	box.add_child(UiTheme.make_label(Locale.t("menu.subtitle"), 20,
		Color(0.85, 0.95, 1.0)))

	box.add_child(_spacer(12))
	var start := _button(box, Locale.t("menu.start_game"), _on_start, true)
	var settings := _button(box, Locale.t("menu.settings_button"), _on_settings)
	var quit := _button(box, Locale.t("menu.quit_button"), _open_quit_confirm)
	_focusables = [start, settings, quit]
	box.add_child(_spacer(6))
	box.add_child(UiTheme.make_label(Locale.t("menu.keys"), 18,
		Color(0.65, 0.82, 0.92)))


func _build_settings(box: VBoxContainer) -> void:
	box.add_child(UiTheme.make_label(Locale.t("settings.title"), 48, UiTheme.GOLD))
	box.add_child(_spacer(6))
	var language := _button(box, Locale.t("menu.language") + "   [L]",
		_on_toggle_language, true)
	var fullscreen := _button(box,
		Locale.t("settings.fullscreen_on" if Locale.fullscreen 			else "settings.fullscreen_off"), _on_toggle_fullscreen)
	box.add_child(UiTheme.make_label(Locale.t("settings.note"), 18,
		Color(0.72, 0.86, 0.95)))
	box.add_child(_spacer(6))
	var back := _button(box, Locale.t("settings.back_button"), _on_back)
	_focusables = [language, fullscreen, back]
	box.add_child(_spacer(4))
	box.add_child(UiTheme.make_label(Locale.t("settings.keys"), 18,
		Color(0.65, 0.82, 0.92)))


func _build_quit_confirm(layer: Control) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.62)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	box.add_child(UiTheme.make_label(Locale.t("quit.title"), 36, UiTheme.GOLD))
	box.add_child(UiTheme.make_label(Locale.t("quit.body"), 18,
		Color(0.82, 0.9, 0.96)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var cancel := _button_to(row, Locale.t("quit.no"), _close_quit_confirm)
	var yes := _button_to(row, Locale.t("quit.yes"), _on_quit_yes)
	# 默认焦点放在“取消”：误按 Enter 不会退出。
	_focusables = [cancel, yes]


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _button(box: VBoxContainer, text: String, cb: Callable, primary := false) -> Button:
	return _button_to(box, text, cb, primary)


func _button_to(box: Container, text: String, cb: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	UiTheme.style_button(button, primary)
	button.pressed.connect(cb)
	box.add_child(button)
	return button


func _grab_focus() -> void:
	if _focusables.is_empty():
		return
	for b in _focusables:
		if not is_instance_valid(b):
			return
	var idx := clampi(_focus_index if not _quit_confirm_open else 0,
		0, _focusables.size() - 1)
	_focusables[idx].grab_focus()


func _on_start() -> void:
	GameManager.start_game_flow()


func _on_producer() -> void:
	get_tree().change_scene_to_file("res://scenes/producer_menu.tscn")


func _on_test_arena() -> void:
	GameManager.test_no_best = true
	get_tree().change_scene_to_file("res://scenes/test_arena.tscn")


func _on_settings() -> void:
	_settings_open = true
	_focus_index = 0
	_refresh()


func _on_back() -> void:
	_settings_open = false
	_focus_index = 0
	_refresh()


func _on_toggle_language() -> void:
	Locale.toggle_language()


func _on_toggle_fullscreen() -> void:
	Locale.toggle_fullscreen()
	_refresh()


func _open_quit_confirm() -> void:
	_quit_confirm_open = true
	_refresh()


func _close_quit_confirm() -> void:
	_quit_confirm_open = false
	_refresh()


func _on_quit_yes() -> void:
	get_tree().quit()


func _arg_after(args: PackedStringArray, flag: String, fallback: String) -> String:
	var i := args.find(flag)
	if i >= 0 and i + 1 < args.size() and not args[i + 1].begins_with("--"):
		return args[i + 1]
	return fallback


func _capture_and_quit(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot(file_name)
	get_tree().quit(0)


func _save_shot(file_name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var image := get_viewport().get_texture().get_image()
	var path := dir.path_join(file_name)
	image.save_png(path)
	print("CAPTURE ", path)
