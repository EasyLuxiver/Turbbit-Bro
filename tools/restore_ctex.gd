extends SceneTree
## 临时工具（用完即删）：把 .godot/imported 里 lossless 的 .ctex 还原成 PNG。
## 只用于恢复被 --capture-boost 意外覆盖的历史截图；不参与游戏运行。

const SRC := "res://.godot/imported/stage2_boost.png-5eabc00e399ea69cd91388c46762f361.ctex"
const DST := "res://screenshots/stage2_boost.png"


func _initialize() -> void:
	var tex := ResourceLoader.load(SRC)
	if tex == null:
		print("RESTORE: LOAD FAILED")
		quit(1)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("RESTORE: NO IMAGE")
		quit(1)
		return
	var err := img.save_png(DST)
	print("RESTORE: %dx%d save_png err=%d" % [img.get_width(), img.get_height(), err])
	quit(0 if err == OK else 1)
