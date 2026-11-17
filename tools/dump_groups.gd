extends SceneTree


func _init() -> void:
	for g in LevelData.GROUPS:
		print("%s z%d %s x=%.0f w=%.0f identity=%s motion=%s" % [
			String(g.get("group", "")), int(g.get("zone", 0)),
			String(g.get("kind", "")), float(g.get("x", 0.0)),
			float(g.get("w", 0.0)), String(g.get("identity", "")),
			str(g.get("motion", {}))])
	quit()
