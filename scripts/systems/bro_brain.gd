extends RefCounted
## BRO BRAIN：未被控制的那一半会自己动起来，而不是冻结成待机海报。
##
## 2026-11-12 TBB-SHIFT-CORE-02 第 2 节。四段状态只是“读行为”的刻度：
##   CALM      0–3 s   正常待命
##   DISTRACTED 3–6 s  开始分心（摆姿势 / 东张西望）
##   RESTLESS  6–9 s   明显干扰（重心晃、脚步乱 / 上下晃、注意力散）
##   MISCHIEF  9 s+    恶作剧（挂壳边 / 主动找吃的）
##
## 这不是第二套生命值：
## - 永远封顶在 DRIFT_CAP，不会自己触发落水、翻肚皮或事故；
## - 不写 BRO METER，不参与惩罚结算；
## - 恢复只在“连续受控 0.5 s”之后开始，快速 SHIFT 白嫖不到；
## - 切换走时未恢复的量原样保留。
##
## 行为本身由角色控制器读取 drift / state 后执行（位置偏移、速度、
## 空中操控、觅食兴趣），本文件只负责累积、分段、恢复与供日志读取。

const Tuning = preload("res://scripts/systems/tuning.gd")

const CALM := "CALM"
const DISTRACTED := "DISTRACTED"
const RESTLESS := "RESTLESS"
const MISCHIEF := "MISCHIEF"

var role := ""
var drift := 0.0
var hold := 0.0


func _init(role_name: String = "") -> void:
	role = role_name


func reset() -> void:
	drift = 0.0
	hold = 0.0


## controlled：当前是否由玩家操控；attentive：是否处于可累积/恢复的正常玩法时间
## （事故演出、Showtime、冲线期间冻结，避免惩罚被强行塞进演出里）。
func tick(delta: float, controlled: bool, attentive: bool = true) -> void:
	if not attentive:
		return
	if controlled:
		hold += delta
		if hold >= Tuning.CONTROL_RECOVER_DELAY:
			drift = maxf(drift - Tuning.DRIFT_RECOVER_RATE * delta, 0.0)
	else:
		hold = 0.0
		drift = minf(drift + delta, Tuning.DRIFT_CAP)


func state_name() -> String:
	if drift < Tuning.DRIFT_CALM_END:
		return CALM
	if drift < Tuning.DRIFT_DISTRACTED_END:
		return DISTRACTED
	if drift < Tuning.DRIFT_RESTLESS_END:
		return RESTLESS
	return MISCHIEF


## 食物、或一次成功的照顾行为：明显恢复神游。
func calm() -> void:
	drift = 0.0
	hold = 0.0


## 0..1，便于控制器把“越走神越夸张”连续插值，而不是按状态跳变。
func progress() -> float:
	return clampf(drift / Tuning.DRIFT_CAP, 0.0, 1.0)
