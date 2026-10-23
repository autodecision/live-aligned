extends SceneTree
## Deterministic full-map controller/UI check; never calls a real model or reads credentials.
const OUT := "/tmp/live-aligned-dialogue-check/"
const Controller = preload("res://scripts/ai/character_dialogue.gd")
const Credentials = preload("res://scripts/ai/ai_credentials.gd")
var failed := false
var checks := 0
var main: Node3D
var controller: CanvasLayer
var mock: Node
var capture := false

class MockProvider extends Node:
	var mode := "success"
	var epoch := 0
	var requests: Array = []
	func cancel() -> void: epoch += 1
	func generate(profile: Dictionary, messages: Array) -> Dictionary:
		var token := epoch
		requests.append({"profile": profile.duplicate(true), "messages": messages.duplicate(true)})
		await get_tree().create_timer(0.08 if mode != "slow" else 0.4).timeout
		if token != epoch: return {"ok": false, "error": "Cancelled"}
		if mode == "failure": return {"ok": false, "error": "Mock connection unavailable. Retry when ready."}
		if mode == "giant": return {"ok": true, "text": "A long answer. ".repeat(4000)}
		return {"ok": true, "text": "The water catches the light beautifully today. [b]This stays plain text.[/b] We can pause here and watch it together."}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("DIALOGUE_CHECK: " + message)

func settle(frames: int = 4) -> void:
	for i in frames: await process_frame

func wait_reply() -> void:
	for i in 300:
		await process_frame
		if not controller._busy: return
	check(false, "Reply failed to settle")

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	main = load("res://scenes/main.tscn").instantiate()
	controller = main.get_node("CharacterDialogue")
	controller.storage_root = OUT + "state_%d" % Time.get_ticks_usec()
	root.add_child(main)
	current_scene = main
	await settle(8)
	var player: CharacterBody3D = main.get_node("Player")
	var characters := main.get_node("IslandCharacters").get_children()
	for npc in characters: npc.set_physics_process(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.capture_mouse(false)
	controller.client.queue_free()
	mock = MockProvider.new()
	controller.add_child(mock)
	controller.client = mock
	controller.settings = {"version": 1, "default_profile_id": "shared", "character_profiles": {"robot": "robot_model"}, "profiles": [
		{"id": "shared", "name": "Island conversations", "provider_id": "custom", "model": "local-test", "base_url": "http://127.0.0.1:9/v1", "auth_mode": "none", "transport": "chat_completions"},
		{"id": "robot_model", "name": "Kestrel's model", "provider_id": "custom", "model": "robot-test", "base_url": "http://127.0.0.1:9/v1", "auth_mode": "none", "transport": "chat_completions"}]}
	var scientist: Node3D = characters[1]
	player.position = scientist.position + Vector3(0, 0, 2.1)
	player.head.rotation.x = 0
	player.rotation.y = 0
	await physics_frame
	await settle()
	check(controller.find_nearby_character() == scientist, "Nearest talk target is scientist")
	if capture:
		root.size = Vector2i(1280, 800)
		await settle(8)
		await screenshot("map-talk")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await settle()
	check(controller.dialogue.visible and controller.active_character == scientist, "E opens nearby conversation")
	check(player.dialogue_locked and scientist._dialogue_paused, "Player and NPC pause")
	var before: Vector3 = player.position
	player.velocity = Vector3(4, 5, 6)
	player._physics_process(1.0)
	check(player.position == before and player.velocity == Vector3.ZERO, "Dialogue freezes player movement and jumps")
	var waypoint: int = scientist.current_waypoint_idx
	var timer: float = scientist.state_timer
	scientist._physics_process(2.0)
	check(scientist.current_waypoint_idx == waypoint and scientist.state_timer == timer, "NPC route state preserved")
	controller.dialogue.composer.insert_text_at_caret("What do you notice by the water?")
	await settle()
	check(not controller.dialogue.send_button.disabled, "Typing a nonblank prompt enables Send")
	controller.dialogue.send_button.pressed.emit()
	await wait_reply()
	check(controller.memory.get_recent("female_scientist").size() == 2, "Successful complete pair persisted")
	check(mock.requests[0].profile.id == "shared", "Default profile selected")
	check(controller.memory.get_recent("robot").is_empty(), "Memory isolated from other character")
	mock.mode = "failure"
	controller._send("Please continue.")
	await wait_reply()
	check(controller.dialogue.retry_button.visible, "Failed request offers retry")
	check(controller.memory.get_recent("female_scientist").size() == 2, "Failure does not persist partial pair")
	mock.mode = "success"
	controller.dialogue.retry_button.pressed.emit()
	await wait_reply()
	check(controller.memory.get_recent("female_scientist").size() == 4, "Retry saves exactly one new pair")
	mock.mode = "slow"
	controller._send("Cancel this request.")
	controller.dialogue.cancel_button.pressed.emit()
	await create_timer(0.5).timeout
	check(controller.memory.get_recent("female_scientist").size() == 4, "Cancelled request does not persist")
	check(not controller._busy, "Cancel releases UI")
	controller.close_conversation()
	check(not scientist._dialogue_paused and not player.dialogue_locked, "Closing resumes movement and route")
	controller.open_conversation(characters[2])
	mock.mode = "success"
	controller._send("Hello Kestrel.")
	await wait_reply()
	check(mock.requests[-1].profile.id == "robot_model", "Per-character profile overrides default")
	var robot_messages: Array = mock.requests[-1].messages
	check(robot_messages.size() == 3 and robot_messages[0].role == "system" and robot_messages[1].role == "system" and robot_messages[1].content.begins_with("CURRENT PUBLIC WORLD SNAPSHOT") and robot_messages[2] == {"role": "user", "content": "Hello Kestrel."}, "Robot request includes public world snapshot and excludes scientist history")
	mock.mode = "slow"
	controller._send("Stale response must not cross characters.")
	controller.close_conversation()
	controller.open_conversation(scientist)
	await create_timer(0.5).timeout
	check(controller.memory.get_recent("robot").size() == 2, "Closing cancels stale response")
	check(controller.dialogue.transcript.get_child_count() == 4, "Reopened transcript has only completed scientist turns")
	mock.mode = "giant"
	controller._send("Long answer test.")
	await wait_reply()
	var last: Node = controller.dialogue.transcript.get_child(-1).get_child(0).get_child(1)
	check(last.text.length() == controller.MAX_REPLY_CHARS, "Large reply bounded for rendering")
	for i in 100: controller.dialogue.add_message("assistant", "Bounded transcript row %d" % i)
	check(controller.dialogue.transcript.get_child_count() == 48, "Visible transcript nodes bounded")
	controller.close_conversation()
	controller.open_conversation(scientist)
	controller.dialogue.clear_messages()
	controller.dialogue.add_message("user", "What do you notice by the water?")
	controller.dialogue.add_message("assistant", "The light changes as the ripples move. There is always something different to notice when we slow down.")
	controller.dialogue.composer.text = "Tell me more about this place."
	controller.dialogue.composer.text_changed.emit()
	await check_view(Vector2i(1280, 800), "desktop")
	await check_view(Vector2i(1920, 1080), "wide-desktop")
	await check_view(Vector2i(390, 844), "portrait")
	await check_view(Vector2i(740, 320), "short-landscape")
	# The same layout branch is used when the virtual keyboard leaves 240 logical pixels.
	await check_view(Vector2i(390, 240), "keyboard-available-space")
	root.size = Vector2i(390, 844)
	controller.open_settings()
	await settle(8)
	check(not controller.dialogue.visible and player.dialogue_locked, "Settings replaces conversation and keeps movement paused")
	check(controller.settings_ui.tabs.get_child(0).get_v_scroll_bar().max_value > controller.settings_ui.tabs.size.y, "Portrait settings scrolls")
	check(controller.settings_ui.panel.get_global_rect().end.x <= root.size.x, "Portrait settings fits horizontally")
	check(controller.settings_ui.status.get_global_rect().end.y <= root.size.y, "Settings status remains visible")
	check(controller.settings_ui.panel.get_global_rect().get_center().distance_to(Vector2(root.size) / 2) < 1.0, "Portrait settings centered")
	if capture: await screenshot("settings-portrait")
	controller.settings_ui.tabs.current_tab = 1
	await settle()
	if capture: await screenshot("memory-portrait")
	root.size = Vector2i(1920, 1080)
	await settle(8)
	check(controller.settings_ui.panel.get_global_rect().get_center().distance_to(Vector2(root.size) / 2) < 1.0, "Desktop settings centered")
	if capture: await screenshot("settings-desktop")
	# Exercise the actual settings form against isolated files with synthetic credentials.
	var ui: Control = controller.settings_ui
	ui.tabs.current_tab = 0
	ui._new_profile()
	ui.fields.name.text = "Saved local profile"
	ui._select_metadata(ui.provider_picker, "custom")
	ui._provider_changed(ui.provider_picker.selected)
	ui.fields.base_url.text = "http://127.0.0.1:9/v1"
	ui.fields.model.text = "saved-model"
	ui._select_metadata(ui.transport_picker, "responses")
	ui._select_metadata(ui.auth_picker, "api_key")
	ui._auth_changed()
	ui.secret.text = "synthetic-key-for-controller-test"
	ui.fields.max_output_tokens.text = "777"
	ui.fields.timeout_seconds.text = "45"
	check(ui._save_profile(), "Settings form saves valid profile")
	var saved_id: String = ui.settings.profiles[ui._profile_index].id
	check(Credentials.get_secret(saved_id) == "synthetic-key-for-controller-test", "Synthetic key retained in session")
	ui._set_default()
	check(controller.settings.default_profile_id == saved_id, "Form sets default profile")
	ui._select_metadata(ui.assignment_character, "alien_suit")
	ui._select_metadata(ui.assignment_profile, "robot_model")
	ui._assign_profile(ui.assignment_profile.selected)
	check(controller.settings.character_profiles.alien_suit == "robot_model", "Form assigns character override")
	var disk: Dictionary = controller.Registry.load_settings(controller.storage_root.path_join("model_settings.json"))
	check(disk.default_profile_id == saved_id and disk.character_profiles.alien_suit == "robot_model", "Saved default and assignment reload")
	check(disk.profiles[-1].transport == "responses" and disk.profiles[-1].max_output_tokens == 777 and disk.profiles[-1].timeout_seconds == 45, "Transport and generation settings reload")
	check(not FileAccess.get_file_as_string(controller.storage_root.path_join("model_settings.json")).contains("synthetic-key"), "Settings file excludes secret")
	ui.fields.base_url.text = "http://127.0.0.1:10/v1"
	check(ui._save_profile(), "Endpoint update saves")
	check(not Credentials.has_secret(saved_id), "Endpoint update invalidates old credential")
	ui._new_profile()
	ui._select_metadata(ui.assignment_profile, str(ui.settings.profiles[-1].id))
	ui._assign_profile(ui.assignment_profile.selected)
	check(ui.settings.character_profiles.alien_suit == "robot_model", "Incomplete draft cannot be assigned")
	# Confirmation captures the intended character even if selection changes.
	ui._select_metadata(ui.assignment_character, "female_scientist")
	ui._confirm_clear()
	ui._select_metadata(ui.assignment_character, "robot")
	ui._confirm.confirmed.emit()
	ui._confirm.hide()
	check(controller.memory.get_recent("female_scientist").is_empty() and controller.memory.get_recent("robot").size() == 2, "Clear confirmation targets captured character only")
	Credentials.clear_all()
	controller.close_settings()
	check(controller.dialogue.visible and player.dialogue_locked, "Closing settings restores conversation without unlocking movement")
	controller.close_conversation()
	await settle()
	controller.talk_button.pressed.emit()
	check(controller.dialogue.visible, "Touch Talk button opens conversation")
	controller.close_conversation()
	await check_daily_checkins_and_zoom(player, characters)
	var report := {"passed": not failed, "checks": checks, "mock_requests": mock.requests.size(), "storage_root": controller.storage_root, "captures": capture}
	FileAccess.open(OUT + "validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("CHARACTER_DIALOGUE_", "FAIL" if failed else "PASS", " ", JSON.stringify(report))
	quit(1 if failed else 0)

func check_daily_checkins_and_zoom(player: CharacterBody3D, characters: Array) -> void:
	var envoy: PS3CharacterNPC = characters[0]
	var vale: PS3CharacterNPC = characters[1]
	var kestrel: PS3CharacterNPC = characters[2]
	# Let the zoom-out from the preceding close_conversation finish first.
	for i in 30:
		player._process(1.0 / 60.0)
	var base_fov: float = player.camera.fov
	controller.open_conversation(vale)
	for i in 25:
		player._process(1.0 / 60.0)
	check(player.is_dialogue_zoomed and player.dialogue_zoom_target == vale and player.camera.fov < base_fov - 15.0, "Dialogue opening zooms camera into character face")
	controller.close_conversation()
	for i in 30:
		player._process(1.0 / 60.0)
	check(not player.is_dialogue_zoomed and absf(player.camera.fov - base_fov) < 0.5, "Closing dialogue zooms camera back out")

	# Seed RAG memory from a prior day and simulate a fresh day's sequential check-ins.
	controller.memory.append_turn("female_scientist", "Tomorrow I need to submit the physics lab report.", "I will hold you to that physics lab report.")
	controller.memory.append_turn("robot", "My goal this quarter is to build an autonomous rover.", "Goal logged: autonomous rover.")
	controller.memory.append_turn("alien_suit", "I have been feeling a bit lonely and I don't have any friends in town yet.", "I hear you, friend.")
	controller.current_day_override = "2026-10-29"
	controller.force_daily_checkins = true
	mock.mode = "success"
	player.global_position = Vector3(-3.5, 0.06, 10.5)

	# 1. Dr. Vale approaches first at full speed, zooms in, checks in with RAG, asks anything else, and ends on negative reply.
	check(controller.get_next_unseen_character() == vale, "Dr. Vale is first in the daily check-in queue")
	vale.global_position = Vector3(-1.5, 0.06, 10.5)
	vale.approach_arrival_distance = 1.6
	controller._process(1.0 / 60.0)
	check(vale.approaching_player and is_equal_approx(vale._target_walk_speed(), vale.walk_speed * vale.travel_speed_multiplier), "Dr. Vale approaches at full speed even when close to player")
	for step in 90:
		vale._physics_process(1.0 / 60.0)
		controller._process(1.0 / 60.0)
		player._process(1.0 / 60.0)
		await physics_frame
		if controller.dialogue.visible:
			break
	check(controller.dialogue.visible and controller.active_character == vale and player.is_dialogue_zoomed, "Dr. Vale arrival opens dialogue and zooms into her face")
	var vale_opening: Node = controller.dialogue.transcript.get_child(-1).get_child(0).get_child(1)
	check(vale_opening.text.to_lower().contains("today") and vale_opening.text.contains("physics lab report"), "Dr. Vale opening asks about today and references RAG memory")
	controller._send("Today I finished the physics lab report, and tonight I will outline chapter two.")
	await wait_reply()
	var vale_sys := str(mock.requests[-1].messages[0].content)
	check(vale_sys.contains("analytical") and vale_sys.contains("obligations and goals"), "Dr. Vale system prompt carries her analytical accountability persona")
	check(JSON.stringify(mock.requests[-1].messages).contains("physics lab report"), "Dr. Vale request includes RAG memory context")
	controller._send("I will finish the chapter two outline before 9 PM.")
	await wait_reply()
	check(controller.session_phase == "offer", "Dr. Vale wraps up check-in and offers to talk about anything else")
	var vale_offer_bubble: Node = controller.dialogue.transcript.get_child(-1).get_child(0).get_child(1)
	check(vale_offer_bubble.text.to_lower().contains("anything else"), "Dr. Vale asks if player wants to talk about anything else")
	controller._send("No thanks, that's all for now.")
	await wait_reply()
	check(not controller.dialogue.visible and not player.is_dialogue_zoomed, "Negative reply to 'anything else?' ends Dr. Vale conversation and zooms out")

	# 2. Kestrel-09 comes next at full speed, asks about week/future/goals, and continues when player replies positively to 'anything else?'.
	check(controller.get_next_unseen_character() == kestrel, "Kestrel-09 is queued immediately after Dr. Vale")
	kestrel.global_position = Vector3(-5.6, 0.06, 10.5)
	kestrel.approach_arrival_distance = 1.6
	controller._process(1.0 / 60.0)
	check(kestrel.approaching_player and is_equal_approx(kestrel._target_walk_speed(), kestrel.walk_speed * kestrel.travel_speed_multiplier), "Kestrel-09 approaches at full speed")
	for step in 90:
		kestrel._physics_process(1.0 / 60.0)
		controller._process(1.0 / 60.0)
		player._process(1.0 / 60.0)
		await physics_frame
		if controller.dialogue.visible:
			break
	check(controller.dialogue.visible and controller.active_character == kestrel and player.is_dialogue_zoomed, "Kestrel-09 arrival opens dialogue and zooms into his face")
	controller._send("This week I am wiring the sensors, and next month I plan to test the rover chassis.")
	await wait_reply()
	var kestrel_sys := str(mock.requests[-1].messages[0].content)
	check(kestrel_sys.contains("stoic") and kestrel_sys.contains("Spock") and kestrel_sys.contains("week"), "Kestrel-09 system prompt carries stoic Spock-like persona and weekly/future agenda")
	controller._send("Progress on the autonomous rover is on schedule.")
	await wait_reply()
	check(controller.session_phase == "offer", "Kestrel-09 enters 'anything else?' offer phase")
	controller._send("Actually yes, what do you think of the south garden bridge structure?")
	await wait_reply()
	check(controller.dialogue.visible and controller.session_phase == "open", "Affirmative/topical reply continues conversation until player ends it")
	controller._send("Goodbye")
	await wait_reply()
	check(not controller.dialogue.visible and not player.is_dialogue_zoomed, "Player ending open conversation closes dialogue and zooms out")

	# 3. The Envoy (traveler) comes next at full speed, asks about feelings/friendships (respecting no-friends note), and ends on negative reply.
	check(controller.get_next_unseen_character() == envoy, "The Envoy is queued immediately after Kestrel-09")
	envoy.global_position = Vector3(-1.5, 0.06, 10.5)
	envoy.approach_arrival_distance = 1.6
	controller._process(1.0 / 60.0)
	check(envoy.approaching_player and is_equal_approx(envoy._target_walk_speed(), envoy.walk_speed * envoy.travel_speed_multiplier), "The Envoy approaches at full speed")
	for step in 90:
		envoy._physics_process(1.0 / 60.0)
		controller._process(1.0 / 60.0)
		player._process(1.0 / 60.0)
		await physics_frame
		if controller.dialogue.visible:
			break
	check(controller.dialogue.visible and controller.active_character == envoy and player.is_dialogue_zoomed, "The Envoy arrival opens dialogue and zooms into his face")
	controller._send("I have been feeling much more peaceful and rested today.")
	await wait_reply()
	var envoy_sys := str(mock.requests[-1].messages[0].content)
	check(envoy_sys.contains("hippy") and envoy_sys.contains("alien") and envoy_sys.contains("Do NOT bother them about friendships"), "The Envoy system prompt has hippy-alien persona and respects no-friends note")
	controller._send("My broader goal in life is to stay creative and balanced.")
	await wait_reply()
	check(controller.session_phase == "offer", "The Envoy enters 'anything else?' offer phase")
	controller._send("Nope, I'm good for today.")
	await wait_reply()
	check(not controller.dialogue.visible and not player.is_dialogue_zoomed, "Negative reply ends The Envoy conversation and zooms out")
	check(controller.get_next_unseen_character() == null, "All three daily check-ins completed for the day")
	controller.force_daily_checkins = false

func check_view(dimensions: Vector2i, title: String) -> void:
	root.size = dimensions
	await settle(8)
	# Desktop window managers may clamp a requested size to the usable screen.
	dimensions = root.size
	var ui: Control = controller.dialogue
	print("DIALOGUE_LAYOUT ", title, " viewport=", root.size, " ui=", ui.size, " panel=", ui.panel.get_global_rect(), " min=", ui.panel.get_combined_minimum_size(), " send=", ui.send_button.get_global_rect())
	check(ui.send_button.get_global_rect().end.y <= dimensions.y + 1, title + " Send reachable")
	check(ui.composer.get_global_rect().end.y <= dimensions.y + 1, title + " composer reachable")
	check(ui.panel.get_global_rect().end.x <= dimensions.x + 1, title + " panel fits horizontally")
	check(ui.panel.get_global_rect().get_center().distance_to(Vector2(dimensions) / 2) < 1.0, title + " panel centered on both axes")
	for bubble in ui.transcript.get_children():
		check(absf(bubble.get_global_rect().get_center().x - ui.scroll.get_global_rect().get_center().x) < 8.0, title + " message frames centered within transcript")
	if capture: await screenshot(title)

func screenshot(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + title + ".png")
