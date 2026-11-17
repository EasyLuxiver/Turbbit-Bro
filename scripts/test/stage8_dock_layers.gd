extends Node
## CORE-FEEL-08 P1-D 探针：第二区域（室内木质码头）的分层与视差。
##
## 判的是“结构和参数”，不是“好不好看”（后者靠截图 + 人眼）：
##   1. 六个层节点名字齐全、顺序固定；
##   2. z 顺序：背景三层在角色之下（负），近景两层在上（正）；
##   3. 视差：镜头走 1200 px，各层位移严格按 parallax 分层，且都在 0.3~1.15；
##   4. 背景层里没有任何碰撞体/区域——背景和玩法空间彻底分开；
##   5. 边界：远离 Z2 时不显示，进入后显示且完全不透明（边界处有淡入）。
##
## 输出 JSON 给报告引用。

const DOCK_SCENE := preload("res://scenes/zone2_dock.tscn")
const OUT_PATH := "res://docs/reports/longrun/core-feel-08-p1d-dock-layers.json"

const EXPECTED := [
	["BG_Far", -100.0, 0.30],
	["BG_Mid", -90.0, 0.50],
	["BG_Props", -80.0, 0.70],
	["Gameplay_Canal", -70.0, 1.00],
	["FG_Near", 50.0, 1.15],
	["FG_Overhead", 60.0, 1.08],
]

var checks: Array = []
var dock: Node2D


func _ready() -> void:
	dock = DOCK_SCENE.instantiate()
	add_child(dock)
	await get_tree().process_frame
	_check_nodes()
	_check_z_order()
	_check_parallax()
	_check_no_collision()
	_check_boundary()
	_check_occlusion_band()

	var failed := 0
	for c in checks:
		if not c["ok"]:
			failed += 1
			print("FAIL  %s  %s" % [c["name"], c["detail"]])
		else:
			print("ok    %s  %s" % [c["name"], c["detail"]])
	_write_json()
	print("P1D RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)


func _add(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})


func _layer(name: String) -> Node2D:
	return dock.get_node_or_null(name)


func _check_nodes() -> void:
	var missing := []
	var names := []
	for e in EXPECTED:
		var n: Node2D = _layer(String(e[0]))
		if n == null:
			missing.append(e[0])
		else:
			names.append(n.name)
	_add("six_layers_present", missing.is_empty(),
		"节点 %s%s" % [str(names), "" if missing.is_empty() else "，缺：" + str(missing)])


func _check_z_order() -> void:
	var bad := []
	var prev := -9999.0
	for e in EXPECTED:
		var n: Node2D = _layer(String(e[0]))
		if n == null:
			continue
		if not is_equal_approx(n.z_index, float(e[1])):
			bad.append("%s z=%d≠%d" % [n.name, n.z_index, int(e[1])])
		if n.z_index < prev:
			bad.append("%s 顺序反了" % n.name)
		prev = n.z_index
	# 背景必须在角色/障碍（world 层 z=0）之后、近景之前。
	var ok := bad.is_empty() \
		and _layer("BG_Far").z_index < 0 and _layer("Gameplay_Canal").z_index < 0 \
		and _layer("FG_Overhead").z_index > 0 and _layer("FG_Near").z_index > 0
	_add("z_order", ok, "背景 <0 < 近景；%s" % ("顺序正确" if ok else str(bad)))


func _check_parallax() -> void:
	var bad := []
	dock.visible = true
	dock.modulate.a = 1.0
	dock.update_cam(22000.0)
	var before := {}
	for e in EXPECTED:
		var n: Node2D = _layer(String(e[0]))
		n.active = true
		before[e[0]] = n.vx(22000.0)
		if not is_equal_approx(n.parallax, float(e[2])):
			bad.append("%s parallax=%.2f≠%.2f" % [e[0], n.parallax, float(e[2])])
	dock.update_cam(23200.0)
	var deltas := {}
	for e in EXPECTED:
		var n: Node2D = _layer(String(e[0]))
		# 屏幕位移 = vx 变化 − 镜头前进量 = −parallax × 1200。
		var d: float = (n.vx(22000.0) - 23200.0) - (float(before[e[0]]) - 22000.0)
		deltas[e[0]] = d
		var want: float = -1200.0 * float(e[2])
		if absf(d - want) > 0.5:
			bad.append("%s 位移 %.1f≠%.1f" % [e[0], d, want])
	# 位移必须严格按 parallax 分层：远景动得少、近景动得多，不能倒挂。
	# 按 parallax 从小到大排（FG_Near 在画面下方、FG_Overhead 在上方，互不遮挡，
	# 两者在节点顺序里谁在前不影响观感；这里只验“越远越慢”这条规律）。
	var order := EXPECTED.duplicate()
	order.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	var seq := []
	for e in order:
		seq.append(deltas[e[0]])
	var ordered := true
	for i in range(1, seq.size()):
		if seq[i] >= seq[i - 1]:
			ordered = false
	_add("parallax_layers", bad.is_empty() and ordered,
		"镜头走 1200 px 时各层屏幕位移 %s（严格递减=远慢近快）" % str(seq))


func _check_no_collision() -> void:
	# 背景节点里出现任何碰撞体/区域，就意味着“背景”会参与玩法——这里必须是 0。
	var bad := []
	_walk_collision(dock, bad)
	_add("background_has_no_collision", bad.is_empty(),
		"Zone2Dock 子树里碰撞节点数 = %d%s" % [bad.size(),
			"" if bad.is_empty() else "：" + str(bad)])


func _walk_collision(n: Node, bad: Array) -> void:
	if n is CollisionShape2D or n is CollisionPolygon2D or n is Area2D \
			or n is StaticBody2D or n is CharacterBody2D or n is RigidBody2D:
		bad.append(String(n.name))
	for c in n.get_children():
		_walk_collision(c, bad)


func _check_boundary() -> void:
	dock.update_cam(12000.0)
	var far_hidden: bool = not dock.visible
	dock.update_cam(22000.0)
	var mid_visible: bool = dock.visible
	var canal_alpha: float = _layer("Gameplay_Canal").modulate.a
	dock.update_cam(38000.0)
	var exit_visible: bool = dock.visible
	_add("zone_gate", far_hidden and mid_visible and exit_visible,
		"12000 隐藏=%s，22000 显示=%s，38000 显示=%s，水渠层 alpha=%.2f" % [
			str(far_hidden), str(mid_visible), str(exit_visible), canal_alpha])
	_add("canal_opaque", is_equal_approx(canal_alpha, 1.0),
		"水渠层在区域中段完全不透明（边界不会露洞）：alpha=%.2f" % canal_alpha)


## P2-7 遮挡顺序：背景在角色后面、近景在角色前面，而且两层都不能压进判定带。
## 判定带（世界 y 130~450）里任何前景像素都会让玩家看不清障碍。
func _check_occlusion_band() -> void:
	var overhead_max: float = _layer("FG_Overhead").OVERHEAD_MAX_Y
	var near_min: float = _layer("FG_Near").NEAR_MIN_Y
	var band_top := 130.0
	var band_bottom := 450.0
	_add("foreground_clears_band",
		overhead_max < band_top and near_min > band_bottom,
		"顶梁最低 y=%.0f（<%.0f），近景最高 y=%.0f（>%.0f），判定带 %.0f~%.0f 无遮挡" % [
			overhead_max, band_top, near_min, band_bottom, band_top, band_bottom])


func _write_json() -> void:
	var rows := []
	for e in EXPECTED:
		var n: Node2D = _layer(String(e[0]))
		rows.append({
			"node": e[0],
			"z_index": n.z_index if n != null else null,
			"parallax": n.parallax if n != null else null,
			"fade_lag": n.fade_lag if n != null else null,
		})
	var failed := 0
	for c in checks:
		if not c["ok"]:
			failed += 1
	var data := {
		"task": "TBB-CORE-FEEL-08 P1-D",
		"generated_at": Time.get_datetime_string_from_system(),
		"zone": "Z2 15000-39000 indoor wooden dock",
		"layers": rows,
		"checks": checks,
		"failed": failed,
	}
	var abs := ProjectSettings.globalize_path(OUT_PATH)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
