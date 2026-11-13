extends RefCounted
## 菜单/暂停/结算共用的按钮外观：全部用 StyleBoxFlat 在代码里画，
## 不引入任何美术素材（素材冻结）。悬停、按下、键盘焦点三种反馈分开做，
## 鼠标和键盘都能看出“当前选中的是哪一个”。

const PANEL_BG := Color(0.03, 0.09, 0.14, 0.92)
const PANEL_BORDER := Color(0.4, 0.8, 0.95, 0.45)
const TEXT := Color(0.93, 0.97, 1.0)
const GOLD := Color(1.0, 0.85, 0.3)


static func style_button(button: Button, primary := false) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(460, 58 if not primary else 66)
	button.add_theme_font_size_override("font_size", 30 if primary else 24)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7))
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_focus_color", TEXT)
	button.add_theme_stylebox_override("normal", _box(
		Color(0.07, 0.15, 0.21, 0.96), Color(0.32, 0.62, 0.78, 0.9), 2))
	button.add_theme_stylebox_override("hover", _box(
		Color(0.12, 0.26, 0.34, 0.98), Color(0.55, 0.9, 1.0, 1.0), 2))
	button.add_theme_stylebox_override("pressed", _box(
		Color(0.05, 0.1, 0.13, 1.0), GOLD, 3))
	var focus := _box(Color(0, 0, 0, 0), GOLD, 3)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", _box(
		Color(0.1, 0.12, 0.14, 0.8), Color(0.3, 0.32, 0.34), 1))


static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(10)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = PANEL_BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 36
	box.content_margin_right = 36
	box.content_margin_top = 26
	box.content_margin_bottom = 26
	return box


static func make_label(text: String, size: int, color := TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
