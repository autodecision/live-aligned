extends Node

func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	var vp := get_viewport()
	if vp:
		var tex := vp.get_texture()
		if tex:
			var img := tex.get_image()
			if img:
				img.save_png("res://screenshot.png")
				print("SCREENSHOT_SAVED")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)
