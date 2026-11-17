extends Node
## 字体探针：确认默认字体能否渲染简体中文，再决定是否需要系统字体回退。

func _ready() -> void:
	var label := Label.new()
	label.text = "简体中文 测试：阳光海岸 码头乱流 肌肉狂潮 乌龟 兔子 氧气"
	label.position = Vector2(80, 120)
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(label)
	var small := Label.new()
	small.text = "暂停 设置 语言：简体中文 / English 重开 主菜单"
	small.position = Vector2(80, 240)
	small.add_theme_font_size_override("font_size", 28)
	add_child(small)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("font_probe.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
	get_tree().quit(0)
