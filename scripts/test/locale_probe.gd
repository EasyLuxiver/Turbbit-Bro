extends Node
## 语言持久化探针：单独进程启动时读 user://settings.json。
## 用法：
##   godot --headless --path TURBBIT res://scenes/locale_probe.tscn
##   godot --headless --path TURBBIT res://scenes/locale_probe.tscn -- --toggle

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--toggle" in args:
		var before := Locale.language
		Locale.toggle_language()
		print("TOGGLE %s -> %s" % [before, Locale.language])
		print("LANG %s" % Locale.language)
	else:
		print("LANG %s" % Locale.language)
	print("SETTINGS %s" % Locale.settings_path_absolute())
	get_tree().quit(0)
