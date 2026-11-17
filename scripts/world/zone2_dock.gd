extends Node2D
## 第二区域（室内木质码头）的分层容器。
##
## 只做两件事：
##   1. 镜头进入 Z2 的可见范围时，打开六层并每帧喂相机 x；
##   2. 不参与任何判定、不改关卡数据、不碰角色位置。
##
## 六层都是独立节点，各自的 parallax 在场景里改，不改代码：
##   BG_Far 0.30 / BG_Mid 0.50 / BG_Props 0.70 / Gameplay_Canal 1.00 /
##   FG_Overhead 1.08 / FG_Near 1.15
##
## z_index 全在场景里设定（BG 为负、FG 为正），所以背景永远在角色和障碍后面，
## 近景和顶梁永远在前面——和真实碰撞、障碍空间彻底分开。

const ZONE_START := 10000.0
const ZONE_END := 34000.0
## 进区域前后各多开一段，避免边界上突然整块消失。
const MARGIN := 2800.0
## FEEL-10 P0-D：入场不是“到 10000 才淡入”。远处码头从 12400 就开始出现，
## 到边界时 BG 已经实心、屋顶/近景约 60%，玩家有 2–3 s 读“这是码头”。
const FADE := 2200.0
const FADE_LEAD := 2600.0

@onready var layers: Array = [
	$BG_Far, $BG_Mid, $BG_Props, $Gameplay_Canal, $FG_Near, $FG_Overhead,
]


func _ready() -> void:
	visible = false


func update_cam(cam_x: float) -> void:
	var active := cam_x > ZONE_START - MARGIN and cam_x < ZONE_END + MARGIN
	if active != visible:
		visible = active
	if not active:
		return
	# 进场：从 ZONE_START−1400 开始淡入，过界之后完全实心。
	# 出场：从 ZONE_END−600 开始淡出，到 ZONE_END+1400 归零。
	# 每层可以带自己的 fade_lag：屋顶梁、近景木桩要等真的走进码头才出现。
	# 水渠层不淡入——它自己把可见范围钉在边界上，淡入反而会在边界露出空洞。
	for l in layers:
		if String(l.layer) == "canal":
			l.modulate.a = 1.0
		else:
			var start := ZONE_START - FADE_LEAD + float(l.fade_lag)
			var a := clampf((cam_x - start) / FADE, 0.0, 1.0)
			a = minf(a, clampf(((ZONE_END + 1400.0) - cam_x) / FADE, 0.0, 1.0))
			l.modulate.a = a
		l.update_cam(cam_x)
