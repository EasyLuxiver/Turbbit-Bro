extends Node
## FEEL-13 P1-A：组装预览截图与动作 GIF 帧。
## 运行（窗口化）：Godot --path . --resolution 1280x720 res://scenes/feel13_part_capture.tscn

const RIG := preload("res://scenes/feel13_part_assembly.tscn")
const OUT := "res://docs/reports/longrun/feel13"
const FRAMES := "res://_attic/2026-11-14/feel13-assembly-frames"

var is_runner := false
var rig: Node


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	rig = RIG.instantiate()
	add_child(rig)
	for i in 5:
		await get_tree().process_frame
	rig.set_process(false)
	var clips: Array = rig.CLIPS
	var f := FileAccess.open(OUT + "/core-feel-13-assembly.json", FileAccess.WRITE)
	var rows := []
	for c in clips:
		rig.set_clip(String(c))
		# 每个 clip 取 8 帧（20 fps），既做截图又做 GIF。
		for k in 8:
			rig._process(0.05)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			if k < 8:
				get_viewport().get_texture().get_image().save_png(
					ProjectSettings.globalize_path(FRAMES).path_join(
						"%s_%02d.png" % [String(c), k]))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUT).path_join("assembly-%s.png" % String(c)))
		rows.append({"clip": String(c), "screenshot": "assembly-%s.png" % String(c)})
		print("CAPTURE assembly ", c)
	f.store_string(JSON.stringify({"clips": rows, "parts": "art_test/feel13/parts_meta.json"}, "  "))
	f.close()
	print("ASSEMBLY CAPTURE: PASS clips=%d" % rows.size())
	get_tree().quit(0)
