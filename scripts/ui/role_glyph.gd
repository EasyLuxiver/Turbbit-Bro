extends Control
## REFINE-06 P1：HUD 里的角色图形。只用原生 draw_*，不引入美术素材。
##
## 为什么要图形：制作人指出“两个小问号”分不出谁是谁。文字名称之外再给一个
## 形状——兔子是“头 + 两只长耳朵”，乌龟是“壳 + 探出的头”——不看字也能分。
##
## level 0..3 对应 CALM / DISTRACTED / RESTLESS / MISCHIEF：
## 颜色从白青 → 琥珀 → 橙 → 红，图形放大 12%/级，最高级轻微脉动。
## controlled 为真时外面套一圈金色弧，作为“当前控制”的第二个标识。

var role := "rabbit"
var level := 0
var controlled := false


func _ready() -> void:
	custom_minimum_size = Vector2(24, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	# 只有最高级才脉动；其余静止，避免整块 HUD 一直在动。
	if level >= 3 or controlled:
		queue_redraw()


func _draw() -> void:
	var c := Color(0.92, 0.97, 1.0)
	match level:
		1:
			c = Color(1.0, 0.90, 0.50)
		2:
			c = Color(1.0, 0.72, 0.30)
		3:
			c = Color(1.0, 0.50, 0.32)
	if level >= 3:
		c.a = 0.72 + 0.28 * absf(sin(Time.get_ticks_msec() * 0.008))
	var center := size * 0.5
	var s := 1.0 + 0.12 * float(level)
	if role == "rabbit":
		# 头 + 两只向上竖的耳朵。
		draw_circle(center + Vector2(0, 3), 5.2 * s, c)
		draw_line(center + Vector2(-3.2, -1), center + Vector2(-4.4, -8.6 * s), c, 2.2)
		draw_line(center + Vector2(3.2, -1), center + Vector2(4.4, -8.6 * s), c, 2.2)
	else:
		# 壳（圆圈）+ 伸到右边的头。
		draw_arc(center + Vector2(-1, 2), 6.0 * s, 0, TAU, 20, c, 2.0)
		draw_circle(center + Vector2(6.0 * s, 2), 2.9, c)
	if controlled:
		draw_arc(center, 10.8, -PI * 0.78, PI * 0.78, 18,
			Color(1.0, 0.86, 0.35, 0.95), 2.4)
