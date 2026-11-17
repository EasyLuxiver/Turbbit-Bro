extends Node2D
## FEEL-09 P1-C — TUBO 拆件动画技术验证（独立场景，不接入正式主流程）。
##
## 左边 A：前鳍单段（隐藏 front_tip）——刚体拆件的下限。
## 右边 B：前鳍两段 + 颈部分层 + 跟随延迟——本轮要判断的上限。
## 两套用同一批 PNG、同一组 pivot，只差层级与次级运动。
##
## 运行：
##   Godot --path . res://scenes/tubo_cutout_test.tscn            # 实时循环
##   Godot --path . res://scenes/tubo_cutout_test.tscn -- --capture # 存 90 帧
##
## 输出帧：res://art_test/tubo/preview_frames/frame_000..089.png

const BASE := "res://art_test/tubo/"
const ORDER := ["rear_far", "rear_near", "neck", "carapace", "rim",
	"front_upper", "front_tip", "shoulder", "head"]

var meta := {}
var rig_a: Dictionary = {}
var rig_b: Dictionary = {}
var t := 0.0
var capture := false
var frame_i := 0
var speed := 1.0


func _ready() -> void:
	var raw := FileAccess.get_file_as_string(BASE + "pivots.json")
	meta = JSON.parse_string(raw)
	if typeof(meta) != TYPE_DICTIONARY:
		push_error("pivots.json parse failed")
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	if capture:
		get_window().size = Vector2i(1280, 720)
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(BASE + "preview_frames"))
		_clear_frames()
	rig_a = _make_rig(false, Vector2(0.29, 0.55), 0.40)
	rig_b = _make_rig(true, Vector2(0.71, 0.55), 0.40)
	queue_redraw()
	if capture:
		await _capture_loop()


func _capture_loop() -> void:
	await get_tree().process_frame
	for i in 270:
		t = float(i) / 30.0
		_pose(rig_a, t)
		_pose(rig_b, t)
		queue_redraw()
		await get_tree().process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(
			BASE + "preview_frames/frame_%03d.png" % i))
	get_tree().quit(0)


func _clear_frames() -> void:
	var dir := DirAccess.open(BASE + "preview_frames")
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)


func _make_rig(soft: bool, at_norm: Vector2, scale: float) -> Dictionary:
	var root := Node2D.new()
	root.position = get_viewport_rect().size * at_norm
	root.scale = Vector2(scale, scale)
	add_child(root)
	var sprites := {}
	var collider: Node2D = self
	var idx := 0
	for name in ORDER:
		var m: Dictionary = meta.get(name, {})
		if m.is_empty():
			continue
		var s := Sprite2D.new()
		var tex: Texture2D = load(BASE + String(m["file"]))
		s.texture = tex
		s.centered = false
		var bbox: Array = m["bbox"]
		var piv: Array = m["pivot_source"]
		var pl: Array = m["pivot_local"]
		# 节点原点 = pivot：位置放到源图 pivot，贴图偏移把局部 pivot 对回原点。
		s.position = Vector2(float(piv[0]) - 430.0, float(piv[1]) - 480.0)
		s.offset = Vector2(-float(pl[0]), -float(pl[1]))
		s.z_index = idx
		if not soft and name == "front_tip":
			s.visible = false
		root.add_child(s)
		sprites[name] = s
		idx += 1
	return {"root": root, "sprites": sprites, "soft": soft}


func _process(delta: float) -> void:
	if capture:
		return
	delta = minf(delta, 0.05)
	t += delta
	_pose(rig_a, t)
	_pose(rig_b, t)


## 状态：0–3 s Idle，3–6 s Cruise，6–9 s Jump，循环。
func _phase() -> Array:
	var u := fmod(t, 9.0)
	if u < 3.0:
		return ["IDLE", u, u / 3.0]
	if u < 6.0:
		return ["CRUISE", u - 3.0, (u - 3.0) / 3.0]
	return ["JUMP", u - 6.0, (u - 6.0) / 3.0]


func _pose(rig: Dictionary, now: float) -> void:
	if rig.is_empty():
		return
	var sp: Dictionary = rig["sprites"]
	var soft: bool = rig["soft"]
	var root: Node2D = rig["root"]
	var ph := _phase()
	var state: String = ph[0]
	var u: float = ph[1]
	var p: float = ph[2]
	# 呼吸 / 起伏：两套都有，但 soft 的头和壳错半拍。
	var breath := sin(now * 2.0)
	root.position.y = get_viewport_rect().size.y * 0.55 + breath * 3.0
	root.rotation = 0.0
	var lift := 0.0
	var head_target := 0.0
	var neck_target := 0.0
	var fu_target := 0.0
	var ft_target := 0.0
	var rn_target := 0.0
	var rf_target := 0.0
	var shell_squash := 1.0
	match state:
		"IDLE":
			head_target = sin(now * 1.5) * 0.05
			neck_target = sin(now * 1.5 - 0.5) * 0.02
			fu_target = sin(now * 1.2) * 0.05
			ft_target = sin(now * 1.2 - 0.4) * 0.06
			rn_target = sin(now * 1.2 + 1.0) * 0.04
			rf_target = sin(now * 1.2 + 2.0) * 0.04
			shell_squash = 1.0 + sin(now * 2.0) * 0.006
		"CRUISE":
			head_target = sin(now * 3.0) * 0.03
			neck_target = sin(now * 3.0 - 0.7) * 0.02
			fu_target = sin(now * 6.5) * 0.18
			ft_target = sin(now * 6.5 - 0.9) * 0.24
			rn_target = sin(now * 6.5 + 2.2) * 0.22
			rf_target = sin(now * 6.5 + 3.4) * 0.22
			shell_squash = 1.0 + sin(now * 6.5) * 0.008
		"JUMP":
			# 起跳：整只后仰，前鳍向后上方扫，落下时回正。
			var up := smoothstep(0.0, 0.35, p) * (1.0 - smoothstep(0.75, 1.0, p))
			root.rotation = -0.10 * up
			lift = sin(PI * p) * 110.0
			head_target = -0.16 * up
			neck_target = -0.08 * up
			fu_target = -0.55 * up + sin(now * 2.0) * 0.03
			ft_target = -0.30 * up
			rn_target = -0.30 * up
			rf_target = -0.18 * up
			shell_squash = 1.0 + 0.02 * up
	if not soft:
		# A：单段 —— 头/颈同相、无鳍尖滞后。
		neck_target = head_target * 0.8
		ft_target = 0.0
	var k := 1.0 - exp(-14.0 * (1.0 / 30.0 if capture else 0.016))
	_rot(sp, "head", head_target, k)
	_rot(sp, "neck", neck_target, k)
	_rot(sp, "front_upper", fu_target, k)
	_rot(sp, "front_tip", ft_target, k)
	_rot(sp, "rear_near", rn_target, k)
	_rot(sp, "rear_far", rf_target, k)
	sp["carapace"].scale = Vector2(1.0, shell_squash)
	sp["rim"].scale = Vector2(1.0, shell_squash)
	root.position.y -= lift


func _rot(sp: Dictionary, name: String, target: float, k: float) -> void:
	var s: Sprite2D = sp.get(name)
	if s == null:
		return
	s.rotation = lerp_angle(s.rotation, target, k)


func _draw() -> void:
	var vp := get_viewport_rect().size
	# 背景：上下两段，标出水面线；没有新素材。
	draw_rect(Rect2(0, 0, vp.x, vp.y * 0.42), Color(0.36, 0.58, 0.68))
	draw_rect(Rect2(0, vp.y * 0.42, vp.x, vp.y * 0.58),
		Color(0.05, 0.2, 0.28))
	draw_line(Vector2(0, vp.y * 0.42), Vector2(vp.x, vp.y * 0.42),
		Color(0.7, 0.95, 1.0, 0.8), 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(vp.x * 0.29 - 120, vp.y * 0.10),
		"A  front fin: 1 segment", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		Color(0.8, 0.92, 1.0))
	draw_string(font, Vector2(vp.x * 0.71 - 140, vp.y * 0.10),
		"B  front fin: 2 segments + lag", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		Color(1.0, 0.88, 0.4))
	var ph := _phase()
	draw_string(font, Vector2(vp.x * 0.5 - 120, vp.y * 0.94),
		"%s  %.1fs" % [ph[0], ph[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
		Color(0.9, 0.96, 1.0))
	queue_redraw()
