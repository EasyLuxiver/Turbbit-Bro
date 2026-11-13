extends Node
## 骑乘关系：离壳、接人判定、救援计时。
## 接人窗口按制作人反馈放宽：横向 120 px、纵向 -60～90，命中后直接吸附。

const Tuning = preload("res://scripts/systems/tuning.gd")

var state := "RIDING"
var rescue_timer := 0.0
var carry_timer := 0.0


func reset() -> void:
	state = "RIDING"
	rescue_timer = 0.0
	carry_timer = 0.0


func mark_airborne() -> void:
	state = "AIRBORNE"


func mark_riding() -> void:
	state = "RIDING"
	rescue_timer = 0.0
	carry_timer = 0.0


## PLAYFUL-04：接住之后的一段连续抬升。兔子从真实接住点移到壳上，
## 不是一帧瞬移；抬升结束才恢复骑乘。期间不判落水、不吸第二下。
func mark_carrying(seconds: float) -> void:
	state = "CARRYING"
	carry_timer = seconds


func mark_rescuing(seconds: float) -> void:
	state = "RESCUING"
	rescue_timer = seconds


## 真实落水第一阶段：兔子正从离壳点往下掉，还没碰到水。
## 这一段没有计时——水花出现之前，救援窗口根本还没开始。
func mark_rescue_falling() -> void:
	state = "RESCUE_FALLING"
	rescue_timer = 0.0


## 主动救援：兔子在水里，玩家必须把乌龟潜到它下面；不是自动倒计时放回。
func mark_rescue_active(seconds: float) -> void:
	state = "RESCUE_ACTIVE"
	rescue_timer = seconds


func tick_rescue_active(delta: float) -> bool:
	if state != "RESCUE_ACTIVE":
		return false
	rescue_timer = maxf(rescue_timer - delta, 0.0)
	return rescue_timer <= 0.0


## 救援接住的几何：相对壳上落点的位置 + 相对速度。
## 兔子在水里 340 起、45 px/s 下沉；巡航落点 276 -> 约 1.4 s 后差 124（超出 95，够不着），
## 满潜落点 426 -> 正在水里就够得着。有效区比普通接人 120/-60~90 略放大。
func can_rescue_catch(rabbit_pos: Vector2, mount_point: Vector2,
		rabbit_vel: Vector2 = Vector2.ZERO, turtle_speed: float = 0.0,
		prev_rabbit: Vector2 = Vector2.INF) -> bool:
	if state != "RESCUE_ACTIVE":
		return false
	# 相对速度：乌龟相对兔子还在接近才算“靠近”。兔子被甩到壳后时不接。
	if turtle_speed - rabbit_vel.x < Tuning.RESCUE_CLOSING_MIN:
		return false
	if _in_catch_box(rabbit_pos, mount_point):
		return true
	# 低帧率的一帧可能跨过整个窗口（30 Hz 时一次约 8 px，但暴跌/加速时更大），
	# 所以在上一帧到这一帧的线段上补一次扫掠检测，这是“短暂容错窗口”的实体。
	if prev_rabbit != Vector2.INF:
		for i in 6:
			var t := (float(i) + 1.0) / 7.0
			if _in_catch_box(prev_rabbit.lerp(rabbit_pos, t), mount_point):
				return true
	return false


func _in_catch_box(rabbit_pos: Vector2, mount_point: Vector2) -> bool:
	var dx := absf(rabbit_pos.x - mount_point.x)
	var dy := rabbit_pos.y - mount_point.y
	return dx <= Tuning.RESCUE_CATCH_DX \
		and dy >= Tuning.RESCUE_CATCH_DY_MIN and dy <= Tuning.RESCUE_CATCH_DY_MAX


## 轻微吸附：只在更外一圈、且真的近的时候朝壳拉一点。
## 巡航高度（落点差 139）在吸附圈外，所以它不能替代下潜。
func rescue_suction_offset(rabbit_pos: Vector2, mount_point: Vector2,
		delta: float) -> Vector2:
	if state != "RESCUE_ACTIVE":
		return Vector2.ZERO
	var dx := absf(rabbit_pos.x - mount_point.x)
	var dy := rabbit_pos.y - mount_point.y
	if dx > Tuning.RESCUE_SUCTION_DX or dy > Tuning.RESCUE_SUCTION_DY_MAX \
			or dy < Tuning.RESCUE_SUCTION_DY_MIN:
		return Vector2.ZERO
	var to_mount := mount_point - rabbit_pos
	var dist := to_mount.length()
	if dist < 1.0:
		return Vector2.ZERO
	var step := minf(Tuning.RESCUE_SUCTION_SPEED * delta, dist)
	return to_mount / dist * step


## 方案 2 原型：空中救援。兔子从上方落下，乌龟必须正在跃起，壳顶才有高度。
func mark_rescue_air(seconds: float) -> void:
	state = "RESCUE_AIR"
	rescue_timer = seconds


func tick_rescue_air(delta: float) -> bool:
	if state != "RESCUE_AIR":
		return false
	rescue_timer = maxf(rescue_timer - delta, 0.0)
	return rescue_timer <= 0.0


func can_rescue_air_catch(rabbit_pos: Vector2, mount_point: Vector2,
		turtle_leaping: bool) -> bool:
	if state != "RESCUE_AIR" or not turtle_leaping:
		return false
	var dx := absf(rabbit_pos.x - mount_point.x)
	var dy := rabbit_pos.y - mount_point.y
	return dx <= Tuning.PICKUP_DX \
		and dy >= Tuning.PICKUP_DY_MIN and dy <= Tuning.PICKUP_DY_MAX


func can_pickup(rabbit_pos: Vector2, rabbit_vel_y: float, mount_point: Vector2,
		turtle_at_surface: bool, turtle_rising: bool = false) -> bool:
	if state != "AIRBORNE":
		return false
	if rabbit_vel_y < 0.0:
		return false
	# PLAYFUL-04：壳还在水下、但已经在浮上来（玩家刚松开 ↓）也接得住。
	# 这一段只对“正在上浮”成立；巡航/下潜中的壳仍然必须在水面。
	if not turtle_at_surface and not turtle_rising:
		return false
	var dx := absf(rabbit_pos.x - mount_point.x)
	var dy := rabbit_pos.y - mount_point.y
	# 接住正在上浮的壳时纵向窗口放宽（BRO DIVE）；巡航中的壳保持 -60。
	var dy_min := Tuning.PICKUP_DY_MIN
	if turtle_rising:
		dy_min = Tuning.PICKUP_DY_MIN_RISING if turtle_at_surface \
			else Tuning.PICKUP_DY_RISING_DEEP
	return dx <= Tuning.PICKUP_DX \
		and dy >= dy_min and dy <= Tuning.PICKUP_DY_MAX


func tick_rescue(delta: float) -> bool:
	if state != "RESCUING":
		return false
	rescue_timer -= delta
	return rescue_timer <= 0.0
