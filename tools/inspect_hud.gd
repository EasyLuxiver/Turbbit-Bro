extends SceneTree


func _init() -> void:
	var script: GDScript = load("res://scripts/ui/hud.gd")
	var src: String = script.source_code
	print("HAS_R=", src.contains('rabbit_arrow.text = "R"'))
	print("HAS_GT=", src.contains('rabbit_arrow.text = ">"'))
	print("HAS_ROWCHILD=", src.contains("ROWCHILD"))
	quit()
