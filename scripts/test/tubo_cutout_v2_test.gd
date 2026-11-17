extends Node2D
## FEEL-09 P1-C v2 — TUBO cutout comparison.
##
## A: v1 9 cut parts (front fin single segment, no neck hierarchy).
## B: v2 17 parts (3-segment front fin, 2-segment rear fin, neck→head,
##    lid blink, socket fills).
##
## Run live:
##   Godot --path . res://scenes/tubo_cutout_v2_test.tscn
## Render 12 s (360 frames at 30 fps):
##   Godot --path . res://scenes/tubo_cutout_v2_test.tscn -- --capture

const V1_BASE := "res://art_test/tubo_v2/parts_v1/"
const V2_BASE := "res://art_test/tubo_v2/parts_v2/"
const OUT_DIR := "res://art_test/tubo_v2/preview_frames/"
const ORIGIN := Vector2(430, 470)
const FRAMES := 360

var meta1 := {}
var meta2 := {}
var rig_a: Dictionary = {}
var rig_b: Dictionary = {}
var t := 0.0
var capture := false
var frame_i := 0


func _ready() -> void:
	meta1 = _load_json("res://art_test/tubo_v2/pivots_v1.json")
	meta2 = _load_json("res://art_test/tubo_v2/pivots_v2.json")
	if meta1.is_empty() or meta2.is_empty():
		push_error("pivots json missing")
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	if capture:
		get_window().size = Vector2i(1280, 720)
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(OUT_DIR))
		_clear_frames()
	rig_a = _make_rig(meta1, V1_BASE, Vector2(0.27, 0.55), 0.38, false)
	rig_b = _make_rig(meta2, V2_BASE, Vector2(0.73, 0.55), 0.38, true)
	queue_redraw()
	if capture:
		await _capture_loop()


func _load_json(path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	var d = JSON.parse_string(raw)
	return d if typeof(d) == TYPE_DICTIONARY else {}


func _clear_frames() -> void:
	var dir := DirAccess.open(OUT_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)


func _make_rig(meta: Dictionary, base: String, at_norm: Vector2,
		scale: float, hier: bool) -> Dictionary:
	var root := Node2D.new()
	root.position = get_viewport_rect().size * at_norm
	root.scale = Vector2(scale, scale)
	add_child(root)
	var sprites := {}
	var names := []
	for name in meta.keys():
		names.append(String(name))
	# Create parents before children; z order still comes from the meta table.
	names.sort_custom(func(a, b): return _depth(a) < _depth(b))
	for name in names:
		var m: Dictionary = meta[name]
		if name == "rear_far_low":
			continue
		var s := Sprite2D.new()
		s.texture = load(base + name + ".png")
		s.centered = false
		s.z_as_relative = false
		s.z_index = int(m["order"])
		var piv: Array = m["pivot_source"]
		var pl: Array = m["pivot_local"]
		s.offset = Vector2(-float(pl[0]), -float(pl[1]))
		var parent: Node2D = root
		if hier:
			if name == "head":
				parent = sprites.get("neck", root)
			elif name == "lid":
				parent = sprites.get("head", root)
		parent.add_child(s)
		if parent == root:
			s.position = Vector2(float(piv[0]) - ORIGIN.x,
				float(piv[1]) - ORIGIN.y)
		else:
			var pp: String = ""
			for k in sprites.keys():
				if sprites[k] == parent:
					pp = String(k)
					break
			var ppiv: Array = meta[pp]["pivot_source"]
			s.position = Vector2(float(piv[0]) - float(ppiv[0]),
				float(piv[1]) - float(ppiv[1]))
		if not hier and name == "front_tip":
			s.visible = false
		if name == "lid":
			s.visible = false
		if hier and (name == "shoulder_near" or name == "shoulder_rear"):
			s.visible = false
		sprites[name] = s
	return {"root": root, "sprites": sprites, "hier": hier}


func _depth(name: String) -> int:
	match name:
		"lid":
			return 3
		"head":
			return 2
	return 1


func _capture_loop() -> void:
	await get_tree().process_frame
	for i in FRAMES:
		t = float(i) / 30.0
		_pose(rig_a, t)
		_pose(rig_b, t)
		queue_redraw()
		await get_tree().process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(
			OUT_DIR + "frame_%03d.png" % i))
	get_tree().quit(0)


func _process(delta: float) -> void:
	if capture:
		return
	t += minf(delta, 0.05)
	_pose(rig_a, t)
	_pose(rig_b, t)


## 0–4 s Idle, 4–8 s Cruise, 8–12 s Jump.
func _phase() -> Array:
	var u := fmod(t, 12.0)
	if u < 4.0:
		return ["IDLE", u, u / 4.0]
	if u < 8.0:
		return ["CRUISE", u - 4.0, (u - 4.0) / 4.0]
	return ["JUMP", u - 8.0, (u - 8.0) / 4.0]


func _pose(rig: Dictionary, now: float) -> void:
	if rig.is_empty():
		return
	var sp: Dictionary = rig["sprites"]
	var hier: bool = rig["hier"]
	var root: Node2D = rig["root"]
	var ph := _phase()
	var state: String = ph[0]
	var p: float = ph[2]
	var breath := sin(now * 2.0)
	var lift := 0.0
	root.position.y = get_viewport_rect().size.y * 0.55 + breath * 3.0
	root.rotation = 0.0
	var neck_t := 0.0
	var head_t := 0.0
	var fu_t := 0.0
	var fm_t := 0.0
	var ft_t := 0.0
	var ru_t := 0.0
	var rt_t := 0.0
	var rf_t := 0.0
	var squash := 1.0
	match state:
		"IDLE":
			neck_t = sin(now * 1.4) * 0.04
			head_t = sin(now * 1.4 - 0.5) * 0.05
			fu_t = sin(now * 1.1) * 0.06
			fm_t = sin(now * 1.1 - 0.5) * 0.05
			ft_t = sin(now * 1.1 - 1.0) * 0.05
			ru_t = sin(now * 1.1 + 1.4) * 0.04
			rt_t = sin(now * 1.1 + 2.1) * 0.04
			rf_t = sin(now * 1.1 + 2.8) * 0.05
			squash = 1.0 + sin(now * 2.0) * 0.006
		"CRUISE":
			neck_t = sin(now * 3.0) * 0.03
			head_t = sin(now * 3.0 - 0.6) * 0.03
			fu_t = sin(now * 6.2) * 0.20
			ft_t = sin(now * 6.2 - 0.9) * 0.14
			ru_t = sin(now * 6.2 + 2.2) * 0.16
			rt_t = sin(now * 6.2 + 2.8) * 0.10
			rf_t = sin(now * 6.2 + 3.4) * 0.14
			squash = 1.0 + sin(now * 6.2) * 0.008
		"JUMP":
			var up := smoothstep(0.0, 0.30, p) * (1.0 - smoothstep(0.75, 1.0, p))
			root.rotation = -0.10 * up
			lift = sin(PI * p) * 120.0
			neck_t = -0.08 * up
			head_t = -0.10 * up
			fu_t = -0.30 * up
			ft_t = -0.10 * up
			ru_t = -0.18 * up
			rt_t = -0.08 * up
			rf_t = -0.12 * up
			squash = 1.0 + 0.02 * up
	if not hier:
		# A: single-segment, neck/head same phase, no lid.
		fu_t = sin(now * 6.2) * 0.22 if state == "CRUISE" else fu_t
		ft_t = 0.0
		fm_t = 0.0
		head_t = neck_t * 0.8
	else:
		# B: the distal segment only lags a little; a big relative bend reads as
		# a broken paddle at gameplay size.
		var lag := sin(now * 6.2 - 0.9) * 0.03 if state == "CRUISE" else 0.0
		ft_t = fu_t * 0.25 + lag
		rt_t = ru_t * 0.25 + lag * 0.6
	var k := 1.0 - exp(-14.0 * (1.0 / 30.0 if capture else 0.016))
	_rot(sp, "neck", neck_t, k)
	_rot(sp, "head", head_t, k)
	_rot(sp, "front_fin", fu_t, k)
	_rot(sp, "rear_fin", ru_t, k)
	_rot(sp, "front_far", rf_t, k)
	if sp.has("carapace"):
		sp["carapace"].scale = Vector2(1.0, squash)
	if sp.has("rim"):
		sp["rim"].scale = Vector2(1.0, squash)
	# Blink: every 3.4 s, 0.12 s closed.
	if sp.has("lid"):
		var lid: Sprite2D = sp["lid"]
		var bt := fmod(now, 3.4)
		if bt < 0.12:
			lid.visible = true
			lid.scale = Vector2(1.0, sin(PI * (bt / 0.12)))
		else:
			lid.visible = false
	root.position.y -= lift


func _rot(sp: Dictionary, name: String, target: float, k: float) -> void:
	var s: Sprite2D = sp.get(name)
	if s == null:
		return
	s.rotation = lerp_angle(s.rotation, target, k)


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(0, 0, vp.x, vp.y * 0.42), Color(0.36, 0.58, 0.68))
	draw_rect(Rect2(0, vp.y * 0.42, vp.x, vp.y * 0.58),
		Color(0.05, 0.2, 0.28))
	draw_line(Vector2(0, vp.y * 0.42), Vector2(vp.x, vp.y * 0.42),
		Color(0.7, 0.95, 1.0, 0.8), 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(vp.x * 0.27 - 150, vp.y * 0.10),
		"A  v1: 9 parts / 1-seg fin", HORIZONTAL_ALIGNMENT_LEFT, -1, 21,
		Color(0.8, 0.92, 1.0))
	draw_string(font, Vector2(vp.x * 0.73 - 190, vp.y * 0.10),
		"B  v2: 10 parts / flat / blink", HORIZONTAL_ALIGNMENT_LEFT, -1, 21,
		Color(1.0, 0.88, 0.4))
	var ph := _phase()
	draw_string(font, Vector2(vp.x * 0.5 - 130, vp.y * 0.94),
		"%s  %.1fs" % [ph[0], ph[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
		Color(0.9, 0.96, 1.0))
	queue_redraw()
