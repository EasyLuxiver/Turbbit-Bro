extends Control
## PHASE-FIX：HUD 里的兔子/乌龟小头像。只用原生 draw_*，不引入素材。

var role := "rabbit":
	set(value):
		role = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(36, 36)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	if role == "rabbit":
		var fur := Color(0.96, 0.94, 0.88)
		var line := Color(0.15, 0.18, 0.22, 0.85)
		draw_circle(c + Vector2(0, 5), 11.0, fur)
		draw_line(c + Vector2(-6, -2), c + Vector2(-9, -18), fur, 5.0)
		draw_line(c + Vector2(6, -2), c + Vector2(9, -18), fur, 5.0)
		draw_circle(c + Vector2(-4, 4), 2.0, line)
		draw_circle(c + Vector2(4, 4), 2.0, line)
		draw_circle(c + Vector2(0, 10), 1.6, Color(0.9, 0.55, 0.55))
	else:
		var shell := Color(0.35, 0.68, 0.36)
		var shell_dark := Color(0.20, 0.42, 0.24)
		var head := Color(0.55, 0.80, 0.40)
		var line := Color(0.10, 0.18, 0.12, 0.9)
		draw_circle(c + Vector2(-3, 5), 12.0, shell)
		draw_arc(c + Vector2(-3, 5), 8.0, 0, TAU, 18, shell_dark, 2.0)
		draw_circle(c + Vector2(11, 2), 6.5, head)
		draw_circle(c + Vector2(13, 0), 1.8, line)
