extends Node2D
## FEEL-10 P1-A：TUBO 的真正独立拆件动画。
##
## 10 个部件：tail / rear_far / rear_fin / front_far / neck / carapace / rim /
## front_fin / head / lid。头挂在脖子下、眼睑挂在头下，其余各自绕自己的 pivot
## 旋转；绘制顺序由 pivots.json 的 order 固定（尾和远侧后鳍在壳后，前鳍在壳前）。
##
## 四个状态各 3 s：IDLE → CRUISE → JUMP → LANDING，12 s 循环。
##
## 实时预览：
##   Godot --path . res://scenes/tubo_parts_anim_test.tscn
## 渲染 360 帧（30 fps）：
##   Godot --path . res://scenes/tubo_parts_anim_test.tscn -- --capture

const BASE := "res://art_test/tubo_parts/"
const META := "res://art_test/tubo_parts/pivots.json"
const OUT_DIR := "res://art_test/tubo_parts/preview_frames/"
const ORIGIN := Vector2(430.0, 470.0)
const FRAMES := 360
const FPS := 30.0
const SCALE := 0.72

var meta: Dictionary = {}
var root: Node2D
var sprites: Dictionary = {}
var t := 0.0
var capture := false


func _ready() -> void:
	meta = _load_json(META)
	if meta.is_empty():
		push_error("pivots.json missing")
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	if capture:
		get_window().size = Vector2i(1280, 720)
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(OUT_DIR))
		_clear_frames()
	_build_rig()
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


func _build_rig() -> void:
	root = Node2D.new()
	root.position = get_viewport_rect().size * Vector2(0.5, 0.55)
	root.scale = Vector2(SCALE, SCALE)
	add_child(root)
	var names := []
	for k in meta.keys():
		names.append(String(k))
	names.sort_custom(func(a, b): return _depth(a) < _depth(b))
	for name in names:
		var m: Dictionary = meta[name]
		var s := Sprite2D.new()
		s.texture = load(BASE + name + ".png")
		s.centered = false
		s.z_as_relative = false
		s.z_index = int(m["order"])
		s.offset = Vector2(-float(m["pivot_local"][0]),
			-float(m["pivot_local"][1]))
		var parent: Node2D = root
		if name == "head":
			parent = sprites.get("neck", root)
		elif name == "lid":
			parent = sprites.get("head", root)
		parent.add_child(s)
		var piv: Array = m["pivot_source"]
		if name == "head" or name == "lid":
			var pp: String = "neck" if name == "head" else "head"
			var ppiv: Array = meta[pp]["pivot_source"]
			s.position = Vector2(float(piv[0]) - float(ppiv[0]),
				float(piv[1]) - float(ppiv[1]))
		else:
			s.position = Vector2(float(piv[0]) - ORIGIN.x,
				float(piv[1]) - ORIGIN.y)
		if name == "lid":
			s.visible = false
		sprites[name] = s
	_write_node_table()


func _depth(name: String) -> int:
	if name == "lid":
		return 3
	if name == "head":
		return 2
	if name == "neck":
		return 1
	return 0


func _write_node_table() -> void:
	var node_rows := []
	for k in sprites.keys():
		var s: Sprite2D = sprites[k]
		var parent_name := "root"
		if s.get_parent() == sprites.get("neck", null):
			parent_name = "neck"
		elif s.get_parent() == sprites.get("head", null):
			parent_name = "head"
		node_rows.append({
			"name": String(k), "parent": parent_name,
			"z_index": s.z_index,
			"pivot_source": meta[k]["pivot_source"],
			"pivot_local": meta[k]["pivot_local"],
			"texture": BASE + String(k) + ".png",
			"size": meta[k]["size"],
		})
	var data := {
		"character": "TUBO", "parts": node_rows.size(),
		"note": "TUBO is a turtle: no ears. Independent parts are head/neck/shell/rim/4 flippers/tail/lid.",
		"states": ["IDLE", "CRUISE", "JUMP", "LANDING"],
		"state_seconds": 3.0, "fps": FPS, "scale": SCALE,
		"nodes": node_rows,
	}
	var f := FileAccess.open("res://art_test/tubo_parts/anim_nodes.json",
		FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func _capture_loop() -> void:
	await get_tree().process_frame
	for i in FRAMES:
		t = float(i) / FPS
		_pose(t)
		queue_redraw()
		await get_tree().process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUT_DIR + "frame_%03d.png" % i))
	get_tree().quit(0)


func _process(delta: float) -> void:
	if capture:
		return
	t += minf(delta, 0.05)
	_pose(t)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if capture:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.physical_keycode == KEY_F10:
		get_tree().change_scene_to_file("res://scenes/producer_menu.tscn")


## 0–3 IDLE, 3–6 CRUISE, 6–9 JUMP, 9–12 LANDING.
func _phase(now: float) -> Array:
	var u := fmod(now, 12.0)
	if u < 3.0:
		return ["IDLE", u, u / 3.0]
	if u < 6.0:
		return ["CRUISE", u - 3.0, (u - 3.0) / 3.0]
	if u < 9.0:
		return ["JUMP", u - 6.0, (u - 6.0) / 3.0]
	return ["LANDING", u - 9.0, (u - 9.0) / 3.0]


func _pose(now: float) -> void:
	if root == null:
		return
	var ph := _phase(now)
	var state: String = ph[0]
	var p: float = ph[2]
	var vp := get_viewport_rect().size
	root.position = Vector2(vp.x * 0.5, vp.y * 0.55)
	root.rotation = 0.0
	root.scale = Vector2(SCALE, SCALE)
	var neck_t := 0.0
	var head_t := 0.0
	var ff_t := 0.0
	var rf_t := 0.0
	var ffar_t := 0.0
	var rfar_t := 0.0
	var tail_t := 0.0
	var squash := 1.0
	match state:
		"IDLE":
			var b := sin(now * 1.8)
			root.position.y += b * 3.0
			neck_t = sin(now * 1.4) * 0.04
			head_t = sin(now * 1.4 - 0.7) * 0.06
			ff_t = sin(now * 1.1) * 0.05
			rf_t = sin(now * 1.1 + 1.4) * 0.04
			ffar_t = sin(now * 1.1 + 2.2) * 0.035
			rfar_t = sin(now * 1.1 + 3.0) * 0.03
			tail_t = sin(now * 0.9 + 0.4) * 0.14
			squash = 1.0 + b * 0.006
		"CRUISE":
			var b := sin(now * 3.0)
			root.position.y += b * 4.0
			root.rotation = sin(now * 3.0) * 0.012
			neck_t = sin(now * 3.0 - 0.4) * 0.05
			head_t = sin(now * 3.0 - 1.0) * 0.04
			ff_t = sin(now * 6.2) * 0.30
			rf_t = sin(now * 6.2 + 2.2) * 0.24
			ffar_t = sin(now * 6.2 + PI) * 0.20
			rfar_t = sin(now * 6.2 + 2.2 + PI) * 0.16
			tail_t = sin(now * 3.1 + 1.2) * 0.26
			squash = 1.0 + b * 0.008
		"JUMP":
			# 0–0.15 蓄力，0.15–0.85 腾空，0.85–1 落回。
			var up := smoothstep(0.06, 0.22, p) * (1.0 - smoothstep(0.80, 0.98, p))
			var lift := sin(PI * clampf((p - 0.06) / 0.86, 0.0, 1.0)) * 150.0
			root.position.y -= lift
			root.rotation = -0.12 * up
			neck_t = -0.10 * up
			head_t = -0.12 * up
			ff_t = -0.42 * up
			rf_t = -0.26 * up
			ffar_t = -0.34 * up
			rfar_t = -0.18 * up
			tail_t = 0.30 * up
			squash = 1.0 + 0.03 * up
		"LANDING":
			# 落地瞬间压扁，随后两次反弹收敛；鳍向外张，头先下后回。
			var impact := exp(-5.5 * p) * cos(11.0 * p)
			squash = 1.0 - 0.16 * impact
			root.position.y += 10.0 * exp(-6.0 * p) * cos(9.0 * p)
			neck_t = 0.10 * exp(-4.0 * p) * cos(9.0 * p)
			head_t = 0.14 * exp(-4.0 * p) * cos(9.0 * p + 0.4)
			ff_t = 0.30 * exp(-3.5 * p) * cos(8.0 * p)
			rf_t = 0.22 * exp(-3.5 * p) * cos(8.0 * p + 0.5)
			ffar_t = 0.24 * exp(-3.5 * p) * cos(8.0 * p + 0.8)
			rfar_t = 0.16 * exp(-3.5 * p) * cos(8.0 * p + 1.1)
			tail_t = -0.28 * exp(-3.0 * p) * cos(7.0 * p)
	_rot("neck", neck_t)
	_rot("head", head_t)
	_rot("front_fin", ff_t)
	_rot("rear_fin", rf_t)
	_rot("front_far", ffar_t)
	_rot("rear_far", rfar_t)
	_rot("tail", tail_t)
	for name in ["carapace", "rim"]:
		var s: Sprite2D = sprites.get(name)
		if s != null:
			s.scale = Vector2(1.0 / sqrt(squash), squash)
	if sprites.has("lid"):
		var lid: Sprite2D = sprites["lid"]
		var bt := fmod(now, 3.4)
		if bt < 0.12:
			lid.visible = true
			lid.scale = Vector2(1.0, sin(PI * (bt / 0.12)))
		else:
			lid.visible = false


func _rot(name: String, target: float) -> void:
	var s: Sprite2D = sprites.get(name)
	if s != null:
		s.rotation = target


func _draw() -> void:
	var vp := get_viewport_rect().size
	# 干净的“水中棚拍”背景：上浅下深，一条水线，不抢角色轮廓。
	draw_rect(Rect2(0, 0, vp.x, vp.y * 0.42), Color(0.33, 0.55, 0.66))
	draw_rect(Rect2(0, vp.y * 0.42, vp.x, vp.y * 0.58),
		Color(0.05, 0.20, 0.28))
	draw_line(Vector2(0, vp.y * 0.42), Vector2(vp.x, vp.y * 0.42),
		Color(0.72, 0.95, 1.0, 0.75), 3.0)
	for i in 7:
		var y := vp.y * 0.50 + i * 34.0
		draw_line(Vector2(0, y), Vector2(vp.x, y),
			Color(0.35, 0.62, 0.72, 0.10), 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(24, 36), "TUBO  /  10 independent parts",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.86, 0.95, 1.0))
	draw_string(font, Vector2(24, 62),
		"head + neck  ·  shell + rim  ·  4 flippers  ·  tail  ·  lid",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.62, 0.82, 0.9))
	var ph := _phase(t)
	var state: String = ph[0]
	var labels := {"IDLE": "IDLE", "CRUISE": "CRUISE",
		"JUMP": "JUMP", "LANDING": "LANDING"}
	draw_string(font, Vector2(vp.x - 250, 38), String(labels[state]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.88, 0.45))
	draw_string(font, Vector2(vp.x - 250, 60), "%.1f s" % float(ph[1]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.85, 0.95))
	# 底部四段时间轴。
	var x0 := vp.x * 0.18
	var w := vp.x * 0.64
	var names := ["IDLE", "CRUISE", "JUMP", "LANDING"]
	var u := fmod(t, 12.0)
	var seg := int(u / 3.0)
	for i in 4:
		var r := Rect2(x0 + w * i / 4.0, vp.y - 52.0, w / 4.0 - 6.0, 8.0)
		draw_rect(r, Color(1.0, 0.88, 0.45) if seg == i
			else Color(0.30, 0.48, 0.56))
		draw_string(font, Vector2(r.position.x + 6.0, vp.y - 60.0),
			names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(1.0, 0.93, 0.7) if i == seg else Color(0.55, 0.7, 0.78))
	# 当前段进度。
	draw_rect(Rect2(x0 + w * seg / 4.0, vp.y - 52.0,
		w / 4.0 * (fmod(u, 3.0) / 3.0), 8.0), Color(1.0, 1.0, 1.0, 0.55))
	draw_string(font, Vector2(vp.x - 250, vp.y - 24),
		"R reset  ·  F10 producer menu", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.55, 0.72, 0.8))
