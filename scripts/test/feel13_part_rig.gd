extends Node2D
## FEEL-13 P1-A：TUBO / BITT 独立透明部件的 Godot 组装与动作样例。
## 部件来自 Anima 的“拆件图”（art_test/feel13/source/*_parts_sheet.png），
## 不是从完整角色成图裁切。这里用部件关节（Node2D 层级）把独立 PNG 挂到骨点上，
## 程序化播放 Idle/Cruise/Jump/Leap/Landing/Guard/Catch/Spring OD/Shell OD。

const META := "res://art_test/feel13/parts_meta.json"
const CLIPS := ["idle", "cruise", "jump", "leap", "landing", "guard", "catch",
	"spring_od", "shell_od"]

var clip := "idle"
var t := 0.0
var bones := {}
var sprites := {}
var shield: Polygon2D
var labels: Array[Label] = []


func _ready() -> void:
	_build_background()
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(META))
	_build_tubo(meta["parts"]["TUBO"])
	_build_bitt(meta["parts"]["BITT"])
	_clip_label = _label("", Vector2(32, 22), 26, Color(1, 1, 1))
	_clip_label.text = "CLIP: idle"
	set_process(true)


var _clip_label: Label


func _build_background() -> void:
	var bg := Node2D.new()
	bg.set_script(preload("res://scripts/test/feel13_part_rig_bg.gd"))
	add_child(bg)


func _label(text: String, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	labels.append(l)
	return l


func _bone(parent: Node, name: String, pos: Vector2) -> Node2D:
	var b := Node2D.new()
	b.name = name
	b.position = pos
	parent.add_child(b)
	bones[name] = b
	return b


func _sprite(bone: Node2D, key: String, who: String, part: String,
		target_w: float, z: int, pivot_override = null) -> void:
	var tex: Texture2D = load("res://art_test/feel13/parts/%s/%s.png" % [who, part])
	if tex == null:
		push_error("missing part " + part)
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	var s := target_w / float(tex.get_width())
	spr.scale = Vector2(s, s)
	var piv: Array = pivot_override if pivot_override != null else [0.5, 0.5]
	spr.position = Vector2(-piv[0] * tex.get_width() * s,
		-piv[1] * tex.get_height() * s)
	spr.z_index = z
	bone.add_child(spr)
	sprites[key] = spr


func _build_tubo(parts: Dictionary) -> void:
	var skel := Node2D.new()
	skel.name = "TUBO_PartRig"
	skel.position = Vector2(410, 560)
	skel.z_as_relative = false
	skel.z_index = 10
	add_child(skel)
	var root := _bone(skel, "tubo_root", Vector2.ZERO)
	var torso := _bone(root, "tubo_torso", Vector2(0, -38))
	var head := _bone(torso, "tubo_head", Vector2(0, -30))
	var arm_l := _bone(torso, "tubo_arm_l", Vector2(-20, -20))
	var arm_r := _bone(torso, "tubo_arm_r", Vector2(20, -20))
	var leg_l := _bone(root, "tubo_leg_l", Vector2(-11, 8))
	var leg_r := _bone(root, "tubo_leg_r", Vector2(11, 8))
	var tail := _bone(root, "tubo_tail", Vector2(-20, -8))
	_sprite(tail, "tubo_tail", "TUBO", "tail", 13, -5, parts["tail"]["pivot"])
	_sprite(leg_l, "tubo_leg_l", "TUBO", "leg_l", 18, -4, parts["leg_l"]["pivot"])
	_sprite(leg_r, "tubo_leg_r", "TUBO", "leg_r", 18, -4, parts["leg_r"]["pivot"])
	_sprite(torso, "tubo_torso", "TUBO", "torso", 42, 0, parts["torso"]["pivot"])
	_sprite(arm_l, "tubo_arm_l", "TUBO", "arm_l", 18, 2, parts["arm_l"]["pivot"])
	_sprite(arm_r, "tubo_arm_r", "TUBO", "arm_r", 18, 2, parts["arm_r"]["pivot"])
	_sprite(head, "tubo_head", "TUBO", "head", 56, 3, parts["head"]["pivot"])
	sprites["tubo_head"].z_as_relative = false
	sprites["tubo_head"].z_index = 100
	# 独立耳朵/脸部件同样加载为“备件”，挂在头部骨点上但不重复绘制；
	# 这样交付里既验证了耳朵是独立文件，又不让同一只耳朵出现两次。
	var ear_l := _bone(head, "tubo_ear_l", Vector2(-12, -34))
	var ear_r := _bone(head, "tubo_ear_r", Vector2(12, -34))
	_sprite(ear_l, "tubo_ear_l", "TUBO", "ear_l", 15, 4, parts["ear_l"]["pivot"])
	_sprite(ear_r, "tubo_ear_r", "TUBO", "ear_r", 15, 4, parts["ear_r"]["pivot"])
	# head 文件本身含耳朵，所以独立耳件在预览里隐藏；保留节点证明拆件存在。
	if sprites.has("tubo_ear_l"):
		sprites["tubo_ear_l"].visible = false
	if sprites.has("tubo_ear_r"):
		sprites["tubo_ear_r"].visible = false
	shield = Polygon2D.new()
	shield.polygon = PackedVector2Array([Vector2(-20, -26), Vector2(20, -20),
		Vector2(26, 8), Vector2(0, 30), Vector2(-24, 10)])
	shield.color = Color(1.0, 0.48, 0.12, 0.95)
	shield.position = Vector2(28, -20)
	shield.z_index = 5
	shield.visible = false
	arm_r.add_child(shield)
	_label("TUBO (rabbit) · 9 parts", Vector2(300, 660), 18, Color(0.95, 0.95, 1.0))


func _build_bitt(parts: Dictionary) -> void:
	var skel := Node2D.new()
	skel.name = "BITT_PartRig"
	skel.position = Vector2(840, 580)
	add_child(skel)
	var root := _bone(skel, "bitt_root", Vector2.ZERO)
	var shell := _bone(root, "bitt_shell", Vector2(0, -22))
	var head := _bone(root, "bitt_head", Vector2(46, -30))
	var ff := _bone(root, "bitt_flipper_front", Vector2(38, -4))
	var fb := _bone(root, "bitt_flipper_back", Vector2(-36, -6))
	var ffar := _bone(root, "bitt_flipper_far", Vector2(-22, 2))
	var frear := _bone(root, "bitt_flipper_rear", Vector2(-48, 2))
	_sprite(ffar, "bitt_flipper_far", "BITT", "flipper_far", 17, -2, parts["flipper_far"]["pivot"])
	_sprite(frear, "bitt_flipper_rear", "BITT", "flipper_rear", 18, -2, parts["flipper_rear"]["pivot"])
	_sprite(fb, "bitt_flipper_back", "BITT", "flipper_back", 18, 0, parts["flipper_back"]["pivot"])
	_sprite(shell, "bitt_shell", "BITT", "shell", 96, 1, parts["shell"]["pivot"])
	_sprite(ff, "bitt_flipper_front", "BITT", "flipper_front", 18, 2, parts["flipper_front"]["pivot"])
	_sprite(head, "bitt_head", "BITT", "head", 34, 3, parts["head"]["pivot"])
	_label("BITT (turtle) · 8 parts", Vector2(740, 680), 18, Color(0.95, 0.95, 1.0))


func set_clip(name: String) -> void:
	clip = name
	t = 0.0
	if _clip_label != null:
		_clip_label.text = "CLIP: " + name


func _process(delta: float) -> void:
	t += delta
	if t > 2.4:
		t = fmod(t, 2.4)
	_pose()


func _reset_pose() -> void:
	for k in bones:
		var b: Node2D = bones[k]
		b.rotation = 0.0
		b.scale = Vector2.ONE
	# 根骨是 TUBO_PartRig / BITT_PartRig 的子节点，位置必须是局部 0；
	# 世界坐标已经在 rig 根上，写成 (410,560) 会把整只角色再平移一次。
	bones["tubo_root"].position = Vector2.ZERO
	bones["bitt_root"].position = Vector2.ZERO
	bones["tubo_root"].rotation = 0.0
	bones["bitt_root"].rotation = 0.0
	bones["bitt_shell"].position = Vector2(0, -22)
	shield.visible = false


func _pose() -> void:
	_reset_pose()
	var p := t * TAU / 1.2
	match clip:
		"idle":
			bones["tubo_torso"].rotation = sin(p) * 0.025
			bones["tubo_head"].rotation = sin(p) * 0.05
			bones["tubo_arm_l"].rotation = sin(p) * 0.08
			bones["tubo_arm_r"].rotation = -sin(p) * 0.08
			bones["bitt_shell"].position.y = -22 + sin(p) * 1.5
			bones["bitt_head"].rotation = sin(p) * 0.05
		"cruise":
			bones["tubo_root"].position.y += sin(p) * 2.0
			bones["tubo_torso"].rotation = -0.28
			bones["tubo_head"].rotation = 0.16
			bones["tubo_arm_l"].rotation = 0.55
			bones["tubo_arm_r"].rotation = -0.35
			bones["bitt_root"].position.y += sin(p) * 2.0
			bones["bitt_head"].rotation = 0.12
			bones["bitt_flipper_front"].rotation = sin(p) * 0.25
			bones["bitt_flipper_back"].rotation = -sin(p) * 0.25
		"jump":
			bones["tubo_root"].position.y -= 34.0 * sin(minf(t / 0.55, 1.0) * PI)
			bones["tubo_leg_l"].rotation = 0.45
			bones["tubo_leg_r"].rotation = -0.45
			bones["tubo_arm_l"].rotation = -0.8
			bones["tubo_arm_r"].rotation = 0.8
			bones["bitt_head"].rotation = -0.1
		"leap":
			bones["bitt_root"].position.y -= 42.0 * sin(minf(t / 0.7, 1.0) * PI)
			bones["bitt_root"].rotation = -0.18
			bones["bitt_flipper_front"].rotation = -0.9
			bones["bitt_flipper_back"].rotation = 0.7
			bones["bitt_flipper_far"].rotation = -0.5
			bones["bitt_flipper_rear"].rotation = 0.5
		"landing":
			var k := sin(minf(t / 0.35, 1.0) * PI)
			bones["tubo_root"].scale = Vector2(1.0 + 0.12 * k, 1.0 - 0.16 * k)
			bones["tubo_leg_l"].rotation = 0.5 * k
			bones["tubo_leg_r"].rotation = -0.5 * k
			bones["bitt_root"].scale = Vector2(1.0 + 0.08 * k, 1.0 - 0.10 * k)
		"guard":
			shield.visible = true
			bones["tubo_arm_r"].rotation = -1.25
			bones["tubo_arm_l"].rotation = 0.35
			bones["tubo_torso"].rotation = 0.12
			bones["tubo_head"].rotation = -0.08
		"catch":
			bones["bitt_head"].rotation = 0.35
			bones["bitt_flipper_front"].rotation = -0.55
			bones["bitt_flipper_back"].rotation = -0.55
			bones["bitt_root"].position.x += 18.0 * sin(minf(t / 0.8, 1.0) * PI)
			bones["tubo_arm_r"].rotation = 0.4
		"spring_od":
			var k := sin(minf(t / 0.9, 1.0) * PI)
			bones["tubo_root"].scale = Vector2(1.0 - 0.10 * k, 1.0 + 0.22 * k)
			bones["tubo_head"].rotation = -0.2 * k
			bones["tubo_arm_l"].rotation = -1.2 * k
			bones["tubo_arm_r"].rotation = 1.2 * k
		"shell_od":
			bones["bitt_shell"].rotation = t * 9.0
			bones["bitt_root"].position.x += 28.0 * sin(minf(t / 0.8, 1.0) * PI)
			bones["bitt_flipper_front"].rotation = -0.8
			bones["bitt_flipper_back"].rotation = -0.8
