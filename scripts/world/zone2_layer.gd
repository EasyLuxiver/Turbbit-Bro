extends Node2D
## 第二区域（室内木质码头）的**单独一层**。只画，不判定、不持有任何游戏状态。
##
## CORE-FEEL-08 P1-D 的空间约定（侧视）：
##   y < 300   对岸与室内纵深（仓库、窗、梁、吊装）
##   y = 300   水线（水渠的表面）
##   300~860   水渠水体；860 以下是水底
##   屏幕上方   FG_Overhead 的屋顶梁架
##   屏幕下方   FG_Near 的近景木桩与浪
##
## 每层用 parallax 控制速度：1.0 = 和角色同速（世界层），<1 = 更远更慢，
## >1 = 更近更快。绘制不做“整层平移节点”，而是按 parallax 换算虚拟坐标，
## 只画镜头附近的那一段——这样 24,000 px 的段落不会一次性画完。

const ZONE_START := 15000.0
const ZONE_END := 39000.0
const SURFACE_Y := 300.0
const VIEW_W := 1920.0
const MARGIN := 600.0
## 前景两层与玩法带的分界（世界 y）。判定带是 130~450：
## 顶梁最低画到 104，近景木桩最高画到 678——两层都不会遮住玩家读障碍。
const OVERHEAD_MAX_Y := 104.0
const NEAR_MIN_Y := 678.0

## 木质码头的调色：暖木 + 清晰色块 + 粗描边。全部是占位色块，等美术接管。
const C_WOOD := Color(0.62, 0.45, 0.28)
const C_WOOD_DARK := Color(0.40, 0.28, 0.17)
const C_OUTLINE := Color(0.18, 0.12, 0.08)
const C_ROOF := Color(0.35, 0.24, 0.16)
const C_GLOW := Color(0.98, 0.90, 0.66)
const C_WATER_TOP := Color(0.11, 0.38, 0.47)
const C_WATER_MID := Color(0.07, 0.26, 0.36)
const C_WATER_DEEP := Color(0.05, 0.18, 0.27)
const C_FLOOR := Color(0.45, 0.35, 0.25)

@export_enum("bg_far", "bg_mid", "bg_props", "canal", "fg_near", "fg_overhead")
var layer: String = "bg_far"
## 1.0 = 世界同速。远景 0.3 起，近景 1.15 止——差太多会晕。
@export var parallax := 1.0
## 进场时这一层比背景晚多少 px 才开始淡入。屋顶梁和近景木桩要等玩家
## 真的走进码头再出现，否则会浮在第一区域的海面上。
@export var fade_lag := 0.0
## 这一层是否可以画（由 controller 按镜头位置开关）。
var active := false

var cam_x := 0.0


func update_cam(x: float) -> void:
	if not is_visible_in_tree():
		return
	if absf(x - cam_x) < 0.01:
		return
	cam_x = x
	queue_redraw()


## 世界坐标 → 这一层的虚拟横坐标。
## 以 Z2 入口对齐：进场时各层严丝合缝，之后远景慢、近景快。
## 设 d = 进场距离，p = parallax：屏幕位置 = (X - ZONE_START) - p*d。
func vx(world_x: float) -> float:
	return world_x + (cam_x - ZONE_START) * (1.0 - parallax)


func _motif_range(period: float) -> Array:
	# 这一层此刻“看到”的世界中心：p*d 之后的那一段。
	var center := ZONE_START + parallax * (cam_x - ZONE_START)
	var lo := center - MARGIN
	var hi := center + VIEW_W + MARGIN
	return [int(floor((lo - ZONE_START) / period)),
		int(ceil((hi - ZONE_START) / period))]


func _draw() -> void:
	match layer:
		"bg_far":
			_draw_far()
		"bg_mid":
			_draw_mid()
		"bg_props":
			_draw_props()
		"canal":
			_draw_canal()
		"fg_near":
			_draw_near()
		"fg_overhead":
			_draw_overhead()


# ---- BG_Far：室内纵深、窗、远处光 ----
## 远景只画屏幕宽度的那一段（不跟 parallax 换算），否则 0.3 倍速会露出空白。
func _draw_far() -> void:
	var x0 := cam_x - 800.0
	var w := VIEW_W + 1600.0
	# 远处的暗色内墙 + 地板线
	draw_rect(Rect2(x0, -240, w, 540), Color(0.13, 0.17, 0.20))
	draw_rect(Rect2(x0, 290, w, 12), Color(0.09, 0.11, 0.13))
	# 远墙上的高窗：每 900 px 一扇，带光柱
	var r := _motif_range(900.0)
	for i in range(r[0], r[1]):
		var wx := ZONE_START + i * 900.0 + 250.0
		var x := vx(wx)
		var top := 18.0
		draw_circle(Vector2(x + 72.0, top), 72.0, C_GLOW)
		draw_rect(Rect2(x, top, 144, 150), C_GLOW)
		draw_arc(Vector2(x + 72.0, top), 72.0, PI, TAU, 24, C_OUTLINE, 6.0)
		draw_rect(Rect2(x, top, 144, 150), C_OUTLINE, false, 6.0)
		draw_line(Vector2(x + 72.0, top - 70.0), Vector2(x + 72.0, top + 150.0),
			C_OUTLINE, 4.0)
		draw_line(Vector2(x, top + 70.0), Vector2(x + 144.0, top + 70.0),
			C_OUTLINE, 4.0)
		# 光柱：从窗口斜到水面
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + 10.0, top + 150.0), Vector2(x + 134.0, top + 150.0),
			Vector2(x + 250.0, SURFACE_Y + 40.0), Vector2(x + 40.0, SURFACE_Y + 40.0),
		]), Color(0.98, 0.92, 0.70, 0.10))
	# 远处木桩：每 300 px 一根，站在水线后面
	var rp := _motif_range(300.0)
	for i in range(rp[0], rp[1]):
		var x := vx(ZONE_START + i * 300.0 + 40.0)
		draw_rect(Rect2(x, 210, 16, 92), Color(0.10, 0.13, 0.15))


# ---- BG_Mid：对岸的木质仓库、码头平台、楼梯 ----
func _draw_mid() -> void:
	var r := _motif_range(1500.0)
	for i in range(r[0], r[1]):
		var wx := ZONE_START + i * 1500.0
		var x := vx(wx)
		var wall_top := 300.0 - 150.0
		# 仓库墙体 + 坡屋顶（粗描边）
		draw_rect(Rect2(x, wall_top, 620.0, 150.0), C_WOOD)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 28.0, wall_top + 4.0),
			Vector2(x + 310.0, wall_top - 74.0),
			Vector2(x + 648.0, wall_top + 4.0),
		]), C_ROOF)
		draw_rect(Rect2(x, wall_top, 620.0, 150.0), C_OUTLINE, false, 5.0)
		# 板材横线：读作“木板仓库”，不是纯色块
		for k in 4:
			var ly := wall_top + 30.0 + k * 30.0
			draw_line(Vector2(x + 6.0, ly), Vector2(x + 614.0, ly),
				Color(0.45, 0.32, 0.20, 0.55), 2.0)
		# 门 + 亮窗
		draw_rect(Rect2(x + 54.0, wall_top + 46.0, 78.0, 104.0),
			Color(0.22, 0.16, 0.11))
		draw_rect(Rect2(x + 54.0, wall_top + 46.0, 78.0, 104.0), C_OUTLINE, false, 4.0)
		draw_rect(Rect2(x + 420.0, wall_top + 34.0, 96.0, 64.0), C_GLOW)
		draw_rect(Rect2(x + 420.0, wall_top + 34.0, 96.0, 64.0), C_OUTLINE, false, 4.0)
		# 码头平台
		draw_rect(Rect2(x - 40.0, 282.0, 700.0, 18.0), C_WOOD_DARK)
		draw_rect(Rect2(x - 40.0, 282.0, 700.0, 18.0), C_OUTLINE, false, 4.0)
		# 下到水面的木楼梯（5 级）
		for s in 5:
			draw_rect(Rect2(x + 560.0 - s * 22.0, 282.0 + s * 6.0, 24.0, 8.0),
				C_WOOD_DARK)
	# 对岸连续的石基：水线以下的 40 px，把“对岸在哪里”钉住
	var x0 := cam_x - 800.0
	var w := VIEW_W + 1600.0
	draw_rect(Rect2(x0, SURFACE_Y, w, 44.0), Color(0.34, 0.31, 0.27))
	draw_rect(Rect2(x0, SURFACE_Y, w, 6.0), Color(0.20, 0.17, 0.14))
	# 判定带（世界 254~296）压一层暗：障碍物永远比它身后的木板更有轮廓。
	# 不改任何判定，只是让“障碍在哪里”比“仓库在哪里”更容易读。
	draw_rect(Rect2(x0, 244.0, w, 56.0), Color(0.06, 0.05, 0.04, 0.30))


# ---- BG_Props：对岸上的木箱、货桶、小船、吊钩 ----
## 全部压在 y 200~300：判定带在 254~296，所以这一层的颜色更暗、更小，
## 让障碍物（画在这层之上）始终有清楚的轮廓。
func _draw_props() -> void:
	var r := _motif_range(700.0)
	for i in range(r[0], r[1]):
		var x := vx(ZONE_START + i * 700.0 + 120.0)
		match int(posmod(i, 3)):
			0:
				# 两只叠放的木箱
				draw_rect(Rect2(x, 246.0, 74.0, 36.0), Color(0.53, 0.38, 0.22))
				draw_rect(Rect2(x, 246.0, 74.0, 36.0), C_OUTLINE, false, 3.0)
				draw_rect(Rect2(x + 14.0, 212.0, 46.0, 34.0), Color(0.58, 0.42, 0.24))
				draw_rect(Rect2(x + 14.0, 212.0, 46.0, 34.0), C_OUTLINE, false, 3.0)
			1:
				# 三只货桶
				for k in 3:
					var bx := x + k * 34.0
					draw_rect(Rect2(bx, 262.0, 28.0, 20.0), Color(0.46, 0.30, 0.18))
					draw_line(Vector2(bx, 268.0), Vector2(bx + 28.0, 268.0),
						C_OUTLINE, 2.0)
					draw_rect(Rect2(bx, 262.0, 28.0, 20.0), C_OUTLINE, false, 3.0)
			_:
				# 翻扣的小船 + 盘起的缆绳
				draw_colored_polygon(PackedVector2Array([
					Vector2(x, 282.0), Vector2(x + 130.0, 282.0),
					Vector2(x + 110.0, 252.0), Vector2(x + 20.0, 252.0),
				]), Color(0.42, 0.29, 0.18))
				draw_line(Vector2(x + 20.0, 252.0), Vector2(x + 110.0, 252.0),
					C_OUTLINE, 4.0)
				draw_circle(Vector2(x + 168.0, 274.0), 14.0, Color(0.55, 0.45, 0.30))
				draw_circle(Vector2(x + 168.0, 274.0), 6.0, Color(0.22, 0.16, 0.10))


# ---- Gameplay_Canal：中央水渠本体（世界层，parallax=1） ----
func _draw_canal() -> void:
	# 水的可见范围钉在区域边界上：左边接着第一区域的水，右边交给第三区域，
	# 中间没有洞、也没有两块重叠的水。
	# 入口水面向左多铺 400 px，和 race 的 Z1→Z2 渐变带重叠；
	# 否则渐变带下面会露出没有水体的洞。闸门仍画在 ZONE_START。
	var x0 := maxf(cam_x - 800.0, ZONE_START - 400.0)
	var x1 := minf(cam_x + VIEW_W + 800.0, ZONE_END)
	if x1 <= x0:
		return
	var w := x1 - x0
	draw_rect(Rect2(x0, SURFACE_Y, w, 200.0), C_WATER_TOP)
	draw_rect(Rect2(x0, 500.0, w, 240.0), C_WATER_MID)
	draw_rect(Rect2(x0, 740.0, w, 180.0), C_WATER_DEEP)
	draw_rect(Rect2(x0, 860.0, w, 200.0), C_FLOOR)
	# 水面：一条会随镜头推进的波线（只画，不参与判定）
	var pts := PackedVector2Array()
	var px := x0
	while px <= x1:
		pts.append(Vector2(px, SURFACE_Y + sin(px * 0.018) * 4.0))
		px += 40.0
	if pts.size() >= 2:
		draw_polyline(pts, Color(0.78, 0.96, 1.0), 4.0)
	# 波光短线：每 240 px 一道
	var r := _motif_range(240.0)
	for i in range(r[0], r[1]):
		var x := vx(ZONE_START + i * 240.0 + 60.0)
		draw_line(Vector2(x, SURFACE_Y + 34.0), Vector2(x + 46.0, SURFACE_Y + 34.0),
			Color(0.65, 0.90, 1.0, 0.25), 3.0)
	# 水下的旧木桩：水渠里的结构感，落在 520~860，不挡判定带
	var rp := _motif_range(520.0)
	for i in range(rp[0], rp[1]):
		var x := vx(ZONE_START + i * 520.0 + 200.0)
		draw_rect(Rect2(x, 520.0, 26.0, 360.0), Color(0.04, 0.15, 0.22))
	# 首尾两座门洞：把“这一段是室内码头”和区域边界对上，顺便遮住接缝。
	_draw_gate(ZONE_START)
	_draw_gate(ZONE_END)


## 门洞：外光照进来的敞口 + 粗木框。只画，不构成障碍。
func _draw_gate(world_x: float) -> void:
	var x := vx(world_x)
	if x < cam_x - 900.0 or x > cam_x + VIEW_W + 900.0:
		return
	draw_rect(Rect2(x - 130.0, 34.0, 130.0, 266.0),
		Color(0.99, 0.93, 0.72, 0.75))
	draw_rect(Rect2(x - 130.0, 34.0, 130.0, 266.0), C_OUTLINE, false, 4.0)
	draw_rect(Rect2(x - 150.0, 24.0, 22.0, 280.0), C_WOOD_DARK)
	draw_rect(Rect2(x - 150.0, 24.0, 172.0, 20.0), C_WOOD_DARK)
	draw_rect(Rect2(x - 150.0, 24.0, 172.0, 280.0), C_OUTLINE, false, 5.0)


# ---- FG_Near：近景木桩、缆绳、浪 ----
func _draw_near() -> void:
	var r := _motif_range(520.0)
	var tops := []
	for i in range(r[0], r[1]):
		var x := vx(ZONE_START + i * 520.0 + 80.0)
		# 近景木桩：只从 690 往下长，绝不进判定带
		draw_rect(Rect2(x, 690.0, 46.0, 320.0), Color(0.24, 0.15, 0.09))
		draw_rect(Rect2(x - 9.0, NEAR_MIN_Y, 64.0, 18.0), Color(0.29, 0.19, 0.11))
		draw_rect(Rect2(x, 690.0, 46.0, 320.0), Color(0.12, 0.08, 0.05), false, 4.0)
		tops.append(Vector2(x + 23.0, NEAR_MIN_Y))
	# 桩间缆绳：下垂 46 px
	for i in range(tops.size() - 1):
		var a: Vector2 = tops[i]
		var b: Vector2 = tops[i + 1]
		var pts := PackedVector2Array()
		for k in 11:
			var t := k / 10.0
			var p := a.lerp(b, t)
			pts.append(Vector2(p.x, p.y + sin(t * PI) * 46.0))
		draw_polyline(pts, Color(0.62, 0.52, 0.34), 3.0)
	# 底边浪：一排半圆，读作“近处水面”
	var rw := _motif_range(120.0)
	for i in range(rw[0], rw[1]):
		var x := vx(ZONE_START + i * 120.0)
		draw_arc(Vector2(x + 60.0, 900.0), 34.0, PI, TAU, 12,
			Color(0.55, 0.82, 0.95, 0.35), 4.0)


# ---- FG_Overhead：屋顶梁架、吊绳、滑轮、绳网 ----
func _draw_overhead() -> void:
	var r := _motif_range(640.0)
	for i in range(r[0], r[1]):
		var x := vx(ZONE_START + i * 640.0)
		# 横梁 + 下沿阴影
		draw_rect(Rect2(x, -60.0, 640.0, 86.0), Color(0.27, 0.18, 0.11))
		draw_rect(Rect2(x, 18.0, 640.0, 8.0), Color(0.17, 0.11, 0.07))
		# 立柱（只在画面顶边缘露出一点）
		draw_rect(Rect2(x + 8.0, -60.0, 20.0, 86.0), Color(0.22, 0.15, 0.09))
		# 竖直吊绳 + 滑轮 + 绳网
		draw_line(Vector2(x + 320.0, 26.0), Vector2(x + 320.0, 62.0),
			Color(0.58, 0.48, 0.32), 3.0)
		draw_circle(Vector2(x + 320.0, 66.0), 8.0, Color(0.34, 0.28, 0.20))
		draw_circle(Vector2(x + 320.0, 66.0), 3.0, Color(0.14, 0.10, 0.07))
		if int(posmod(i, 2)) == 0:
			# 绳网：两段斜绳交叉，挂在梁下
			for k in 3:
				var nx := x + 60.0 + k * 44.0
				draw_line(Vector2(nx, 26.0), Vector2(nx + 26.0, OVERHEAD_MAX_Y),
					Color(0.55, 0.46, 0.30, 0.75), 2.0)
				draw_line(Vector2(nx + 26.0, 26.0), Vector2(nx, OVERHEAD_MAX_Y),
					Color(0.55, 0.46, 0.30, 0.75), 2.0)
