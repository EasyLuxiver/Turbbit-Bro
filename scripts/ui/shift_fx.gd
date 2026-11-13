extends Control
## SHIFT 电击表现（TBB-SHIFT-FEEL-03 §2）。
##
## 只订阅 GameManager.shift_shocked：不读输入、不加冷却、不改控制权、不碰物理。
## 表现 = 两人之间的短促电弧 + 轻微全屏闪光 + 程序化电流音效。
## 音效替换点：把 burst_stream 指向正式音源即可，其余代码不需要改。
##
## 挂法：Race._ready() 建 CanvasLayer + 本节点，并 connect shift_shocked。
## 不允许只在测试场景里挂——正式 Race 是唯一入口。

const ARC_TIME := 0.22
const FLASH_TIME := 0.16
const MIX_RATE := 22050.0
const BURST_SECONDS := 0.16

## TBB-SHIFT-PLAYFUL-04 硬边界：关闭现有 SHIFT 电流音效，不扩展音频。
## 视觉电弧/闪光保留；关闭时连 AudioStreamPlayer 都不创建，音频帧增量恒为 0。
const SFX_ENABLED := false

## 正式音源替换点。为空时用下面的程序化电流声；
## 有音源时直接播放它，其余表现不变。
var burst_stream: AudioStream = null

## 供测试读取：真实触发了多少次表现 / 音效事件。
var fx_count := 0
var sfx_count := 0
## 实际推进了生成器缓冲的采样帧数：headless 下也能证明“音效数据真的产生了”。
var sfx_frames := 0
var last_from := ""
var last_to := ""
var last_trigger_msec := 0

var race: Node = null

var _t := -1.0
var _from_pos := Vector2.ZERO
var _to_pos := Vector2.ZERO
var _flash := 0.0
var _rng := RandomNumberGenerator.new()

var _player: AudioStreamPlayer
var _gen: AudioStreamGenerator


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 20261112
	if SFX_ENABLED:
		_setup_audio()


func _setup_audio() -> void:
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = MIX_RATE
	_gen.buffer_length = 0.30
	_player = AudioStreamPlayer.new()
	_player.name = "ShiftSfx"
	_player.stream = _gen
	_player.volume_db = -7.0
	add_child(_player)


## 唯一订阅入口。由正式 Race 场景连接，不允许测试场景另起一套。
func on_shift_shocked(from_who: String, to_who: String) -> void:
	fx_count += 1
	if SFX_ENABLED:
		sfx_count += 1
	last_from = from_who
	last_to = to_who
	last_trigger_msec = Time.get_ticks_msec()
	_t = 0.0
	_flash = 1.0
	if race != null and is_instance_valid(race):
		# 触发当帧的真实位置：兔子与乌龟之间拉弧。
		_from_pos = race.rabbit.position
		_to_pos = race.turtle.position + Vector2(0, -8)
		if race.has_method("on_shift_fx"):
			race.on_shift_fx(to_who)
	if SFX_ENABLED:
		_play_burst()
	queue_redraw()


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	if _t >= ARC_TIME and _flash <= 0.0:
		_t = -1.0
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var xform := get_viewport().get_canvas_transform()
	var p0 := xform * _from_pos
	var p1 := xform * _to_pos
	if _flash > 0.0:
		# 轻微闪光：上限 0.16 alpha，持续 0.16 s；不挡 HUD 文字（本层排在 HUD 之下）。
		var vp_size := size if size.x > 1.0 else get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.75, 0.95, 1.0, 0.16 * _flash))
	var k := clampf(1.0 - _t / ARC_TIME, 0.0, 1.0)
	if k <= 0.0:
		return
	# 三条抖动电弧：主弧亮，旁弧细；每帧重新抖，读作“电”。
	var dir := p1 - p0
	var perp := dir.normalized().orthogonal() if dir.length() > 1.0 else Vector2(0, 1)
	for arc_i in 3:
		var pts := PackedVector2Array()
		var steps := 7
		for i in steps + 1:
			var f := float(i) / float(steps)
			var base := p0.lerp(p1, f)
			var env := sin(f * PI)
			var jitter := _rng.randf_range(-1.0, 1.0) * (10.0 + arc_i * 5.0) * env * k
			pts.append(base + perp * jitter)
		var col := Color(0.72, 0.95, 1.0, 0.85 * k) if arc_i == 0 \
			else Color(0.5, 0.85, 1.0, 0.45 * k)
		draw_polyline(pts, col, 4.0 if arc_i == 0 else 2.0)
	# 落点火花：新角色身上炸开几颗。
	for i in 6:
		var a := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(8.0, 26.0) * (1.0 - k * 0.5)
		draw_circle(p1 + Vector2(cos(a), sin(a)) * r, 2.6 * k + 0.6,
			Color(0.85, 1.0, 1.0, 0.9 * k))


func _play_burst() -> void:
	if _player == null:
		return
	if burst_stream != null:
		_player.stream = burst_stream
		_player.play()
		return
	_player.stream = _gen
	_player.play()
	var pb := _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var pushed := 0
	for frame in _make_burst():
		if not pb.push_frame(frame):
			break
		pushed += 1
	sfx_frames += pushed


## 短促电流 + 湿润冲击：高通嘶声、稀疏爆点、低频闷响。
## 不用 8-bit 方波提示音；频段偏宽、衰减快，符合“电一下”而不是“叮”。
func _make_burst() -> PackedVector2Array:
	var n := int(BURST_SECONDS * MIX_RATE)
	var out := PackedVector2Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var x := float(i) / float(n)
		var env := exp(-x * 7.5)
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.16)
		var hiss := _rng.randf_range(-1.0, 1.0) - lp
		var crackle := 0.0
		if _rng.randf() < 0.055:
			crackle = _rng.randf_range(-1.0, 1.0) * 1.7
		var hum := sin(TAU * 92.0 * float(i) / MIX_RATE) * exp(-x * 9.0) * 0.5
		var s := clampf((hiss * 0.5 + crackle + hum * 0.35) * env, -1.0, 1.0) * 0.42
		out[i] = Vector2(s, s)
	return out
