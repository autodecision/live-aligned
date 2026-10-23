extends SceneTree
## Real-map snapshot and mock transport integration. No credentials or paid calls.
const Context = preload("res://scripts/ai/character_world_context.gd")
const OUT := "/tmp/live-aligned-world-context-check/"
var failed := false
var checks := 0
var controller: CanvasLayer

class MockProvider extends Node:
	var requests: Array = []
	var fail := false
	var waiting := false
	func cancel() -> void: pass
	func is_busy() -> bool: return waiting
	func generate(_profile: Dictionary, messages: Array) -> Dictionary:
		requests.append(messages.duplicate(true))
		await get_tree().create_timer(0.01).timeout
		return {"ok": false, "error": "Synthetic failure"} if fail else {"ok": true, "text": "I can describe the latest public location."}

class ExtraNPC extends PS3CharacterNPC:
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("WORLD_CONTEXT_CHECK: " + message)

func settle() -> void:
	for i in 8: await process_frame

func reply() -> void:
	for i in 300:
		await process_frame
		if not controller._busy: return
	check(false, "Mock reply settled")

func snapshot(messages: Array) -> String:
	for message in messages:
		if str(message.get("content", "")).begins_with("CURRENT PUBLIC WORLD SNAPSHOT"):
			return message.content
	return ""

func roster_row(context: String, character: String) -> String:
	for line in context.split("\n"):
		if line.begins_with("- " + character + ":"): return line
	return ""

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	controller = main.get_node("CharacterDialogue")
	controller.storage_root = OUT + "state_%d" % Time.get_ticks_usec()
	root.add_child(main)
	current_scene = main
	await settle()
	var player: Node3D = main.get_node("Player")
	var roster: Node = main.get_node("IslandCharacters")
	for npc in roster.get_children(): npc.set_physics_process(false)
	player.set_physics_process(false)
	player.capture_mouse(false)
	var vale: Node3D = roster.get_node("Scientist")
	var kestrel: Node3D = roster.get_node("Robot")
	var context = Context.new()
	var landmarks: Array[Dictionary] = context._landmarks(main)
	var labels: Array[String] = []
	for landmark in landmarks: labels.append(landmark.label)
	print("WORLD_CONTEXT_LANDMARKS ", labels)
	for label in ["temple interior", "temple bust and altar", "lower pool", "circular fountain", "central stairs courtyard", "temple terrace and forecourt", "south garden koi pond", "south garden raked sand garden", "main-to-north island bridge", "main-to-south island bridge", "north-to-south island bridge", "north island pagoda", "north pagoda ground floor", "north pagoda middle floor", "north pagoda top floor", "north pagoda entrance", "south garden perimeter path", "south garden timber viewing deck"]:
		check(label in labels, "Runtime landmark present: " + label)
	var initial: String = context.build_context(main, vale, player, roster)
	for name in ["The Envoy", "Dr. Vale", "Kestrel-09"]: check(not roster_row(initial, name).is_empty(), "Public live roster includes " + name)
	check(initial.contains("authoritative") and initial.contains("Positions may change") and initial.contains("straight-line") and initial.contains("north (-Z)"), "Prompt explains freshness, directions and distance limits")
	check(context._direction(Vector3(0, 0, -5)) == "north" and context._direction(Vector3(5, 0, 0)) == "east" and context._direction(Vector3(0, 0, 5)) == "south" and context._direction(Vector3(-5, 0, 0)) == "west", "Godot cardinal directions correct")
	# Place at actual bridge centre, pond, sand and pagoda; labels follow live positions.
	for landmark in landmarks:
		if landmark.label not in ["main-to-south island bridge", "south garden koi pond", "south garden raked sand garden", "north pagoda entrance", "south garden timber viewing deck", "north pagoda ground floor", "north pagoda middle floor", "north pagoda top floor"]: continue
		kestrel.global_position = landmark.center
		var row := roster_row(context.build_context(main, vale, player, roster), "Kestrel-09")
		check(row.contains(landmark.label), "Current position matched: " + landmark.label + " -> " + row)
	# Ground current pose, never infer an inspection from a retained activity tag.
	kestrel.current_activity = "inspect"
	kestrel.set_dialogue_paused(true)
	check(roster_row(context.build_context(main, vale, player, roster), "Kestrel-09").contains("paused for conversation"), "Pause state takes precedence over retained task")
	kestrel.set_dialogue_paused(false)
	kestrel.velocity = Vector3.ZERO
	check(roster_row(context.build_context(main, vale, player, roster), "Kestrel-09").contains("currently stationary"), "Stationary pose does not fabricate an active inspection")
	controller.client.queue_free()
	var mock := MockProvider.new()
	controller.add_child(mock)
	controller.client = mock
	controller.settings = {"profiles": [], "character_profiles": {}}
	# A different character's private memory must never enter Vale's request.
	controller.memory.append_turn("robot", "PRIVATE_KESTREL_TEST_937", "PRIVATE_ANSWER_937")
	controller.open_conversation(vale)
	for landmark in landmarks:
		if landmark.label == "main-to-south island bridge": kestrel.global_position = landmark.center
	controller._send("Where is Kestrel now?")
	await reply()
	var first := snapshot(mock.requests[-1])
	check(roster_row(first, "Kestrel-09").contains("main-to-south island bridge"), "Vale request receives current Kestrel bridge location")
	check(not JSON.stringify(mock.requests[-1]).contains("PRIVATE_"), "Public awareness excludes other character private memory")
	# An older assistant claim should coexist with a later authoritative live snapshot.
	controller.memory.append_turn("female_scientist", "Old location?", "Kestrel used to be near the bridge.")
	for landmark in landmarks:
		if landmark.label == "south garden koi pond": kestrel.global_position = landmark.center
	controller._send("Where is Kestrel now?")
	await reply()
	var second := snapshot(mock.requests[-1])
	check(roster_row(second, "Kestrel-09").contains("south garden koi pond") and second != first, "Next request refreshes changed Kestrel location")
	check(mock.requests[-1][-2].role == "system" and mock.requests[-1][-1].role == "user", "Fresh world snapshot follows recalled conversation immediately before query")
	mock.fail = true
	controller._send("Check again.")
	await reply()
	for landmark in landmarks:
		if landmark.label == "north pagoda entrance": kestrel.global_position = landmark.center
	mock.fail = false
	controller._retry()
	await reply()
	check(roster_row(snapshot(mock.requests[-1]), "Kestrel-09").contains("north pagoda entrance"), "Retry refreshes snapshot after movement")
	# Waiting for a transport to release must not freeze the snapshot early.
	mock.waiting = true
	controller._send("After transport wait?")
	for landmark in landmarks:
		if landmark.label == "south garden raked sand garden": kestrel.global_position = landmark.center
	mock.waiting = false
	await reply()
	check(roster_row(snapshot(mock.requests[-1]), "Kestrel-09").contains("south garden raked sand garden"), "Snapshot taken after transport wait")
	var disk: String = controller.storage_root.path_join("memory").path_join("female_scientist".sha256_text() + ".json")
	var saved := FileAccess.get_file_as_string(disk)
	check(not saved.contains("CURRENT PUBLIC WORLD SNAPSHOT") and not saved.contains("Mapped landmarks currently present"), "Transient world system context is never persisted")
	check(not JSON.stringify(controller.memory.build_context("female_scientist", "location")).contains("CURRENT PUBLIC WORLD SNAPSHOT"), "Recall contains dialogue only")
	controller.close_conversation()
	var saved_transform := kestrel.transform
	roster.remove_child(kestrel)
	check(roster_row(context.build_context(main, vale, player, roster), "Kestrel-09").contains("current location unknown"), "Missing roster member reported unknown")
	roster.add_child(kestrel)
	kestrel.transform = saved_transform
	var missing: String = context.build_context(null, null, null, null)
	check(missing.contains("No landmark anchors available") and missing.contains("Player location is unavailable") and missing.contains("current location unknown"), "Missing world, speaker and roster handled gracefully")
	check(context.describe_position(Vector3(9999, 0, 9999), landmarks).contains("away from the mapped landmarks"), "Outlying position does not assert character is at a landmark")
	for i in 20:
		var extra := ExtraNPC.new()
		extra.character_id = "extra_%d" % i
		extra.character_name = "Long bounded name ".repeat(1000)
		roster.add_child(extra)
	var bounded: String = context.build_context(main, vale, player, roster)
	check(bounded.length() <= Context.MAX_CONTEXT_CHARS and bounded.contains("Additional characters omitted"), "Roster and text are bounded")
	FileAccess.open(OUT + "snapshot.txt", FileAccess.WRITE).store_string(second)
	var report := {"passed": not failed, "checks": checks, "landmarks": labels, "requests": mock.requests.size()}
	FileAccess.open(OUT + "validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("CHARACTER_WORLD_CONTEXT_", "FAIL" if failed else "PASS", " ", JSON.stringify(report))
	quit(1 if failed else 0)
