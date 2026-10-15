extends SceneTree

var frames := 0
var total_fps := 0.0

func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	print("--- PERFORMANCE BENCHMARK STARTED ---")

func _process(delta: float) -> bool:
	frames += 1
	var fps = Engine.get_frames_per_second()
	total_fps += fps
	if frames % 60 == 0:
		print("Frame: ", frames, " | FPS: ", fps, " | Process: ", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "ms | Physics: ", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, "ms")
	if frames >= 180:
		print("AVERAGE FPS: ", total_fps / frames)
		quit(0)
		return true
	return false
