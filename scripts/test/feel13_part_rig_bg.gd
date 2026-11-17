extends Node2D
## 组装预览背景：不引入素材，只画渐变色块与地平线。

func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.55, 0.78, 0.88))
	draw_rect(Rect2(0, vp.y * 0.62, vp.x, vp.y * 0.38), Color(0.08, 0.37, 0.48))
	for i in 7:
		var y := vp.y * 0.62 + i * 22.0
		draw_line(Vector2(0, y), Vector2(vp.x, y + sin(float(i)) * 6.0),
			Color(0.2, 0.55, 0.65, 0.35), 3.0)
