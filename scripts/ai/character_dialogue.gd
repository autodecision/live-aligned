class_name CharacterDialogue
extends CanvasLayer
## Owns interaction, Skyrim-style face zoom, daily check-in queue, cancellation
## and complete-pair persistence for all NPCs.
const UI = preload("res://scripts/ai/dialogue_ui.gd")
const UIThemes = preload("res://scripts/ui_themes.gd")
const SettingsUI = preload("res://scripts/ai/ai_settings_ui.gd")
const Registry = preload("res://scripts/ai/ai_provider_registry.gd")
const Client = preload("res://scripts/ai/ai_provider_client.gd")
const Memory = preload("res://scripts/ai/character_memory.gd")
const WorldContext = preload("res://scripts/ai/character_world_context.gd")
const Personas = preload("res://scripts/ai/character_personas.gd")
const Navigation = preload("res://scripts/npc_navigation.gd")
const TALK_DISTANCE := 3.2
const MAX_REPLY_CHARS := 16000
@export var storage_root := "user://ai"
@export var daily_checkins_enabled := true
var force_daily_checkins := false
var current_day_override := ""
var dialogue: Control
var settings_ui: Control
var client: Node
var navigation: Node
var memory = Memory.new()
var world_context = WorldContext.new()
var settings: Dictionary
var player: Node3D
var characters: Node
var active_character: Node3D
var nearby_character: Node3D
var approaching_character: Node3D
var talk_button: Button
var models_button: Button
var session_phase := "open"
var session_is_checkin := false
var session_goal_review := false
var agenda_turns := 0
var _hud: Control
var _busy := false
var _epoch := 0
var _pending_text := ""
var _restore_capture := false
var _memory_limits: Dictionary = {}
var _checkin_warmup := 0.55

func _ready() -> void:
	layer = 30
	player = get_parent().get_node_or_null("Player")
	characters = get_parent().get_node_or_null("IslandCharacters")
	settings = Registry.load_settings(storage_root.path_join("model_settings.json"))
	_memory_limits = settings.get("memory_limits", {})
	memory.configure(storage_root.path_join("memory"), _memory_limits)
	navigation = Navigation.new()
	navigation.name = "NPCNavigation"
	navigation.world = get_parent()
	add_child(navigation)
	client = Client.new()
	add_child(client)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = UI.make_theme()
	add_child(_hud)
	talk_button = UI.button("Talk", func(): open_conversation(nearby_character))
	_hud.add_child(talk_button)
	talk_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	talk_button.offset_left = -140
	talk_button.offset_right = 140
	talk_button.offset_top = -114
	talk_button.offset_bottom = -62
	talk_button.hide()
	models_button = UI.button("AI settings", open_settings)
	_hud.add_child(models_button)
	models_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	models_button.offset_left = -152
	models_button.offset_right = -16
	models_button.offset_top = 66
	models_button.offset_bottom = 114
	models_button.tooltip_text = "Choose models and manage character memory (F8)"
	dialogue = UI.new()
	add_child(dialogue)
	dialogue.submitted.connect(_send)
	dialogue.close_requested.connect(close_conversation)
	dialogue.settings_requested.connect(open_settings)
	dialogue.cancel_requested.connect(_cancel_reply)
	dialogue.retry_requested.connect(_retry)
	settings_ui = SettingsUI.new()
	settings_ui.settings_path = storage_root.path_join("model_settings.json")
	add_child(settings_ui)
	settings_ui.close_requested.connect(close_settings)
	settings_ui.settings_changed.connect(func(value): settings = value; _refresh_model_label())
	settings_ui.memory_action.connect(_memory_action)

func today_key() -> String:
	return current_day_override if not current_day_override.is_empty() else Time.get_date_string_from_system()

func get_next_unseen_character() -> Node3D:
	if not is_instance_valid(characters):
		return null
	var day := today_key()
	for character_id in Personas.CHECKIN_ORDER:
		if memory.has_seen_today(character_id, day):
			continue
		for child in characters.get_children():
			if child is PS3CharacterNPC and child.character_id == character_id:
				return child
	return null

func _should_run_daily_checkins() -> bool:
	if not daily_checkins_enabled or not is_instance_valid(player) or not is_instance_valid(characters):
		return false
	return force_daily_checkins or player.is_physics_processing()

func _update_daily_checkins(delta: float) -> void:
	if not _should_run_daily_checkins():
		if is_instance_valid(approaching_character) and approaching_character.has_method("stop_approach_player"):
			approaching_character.stop_approach_player(navigation)
		approaching_character = null
		return
	if dialogue.visible or settings_ui.visible:
		return
	if _checkin_warmup > 0.0 and not force_daily_checkins:
		_checkin_warmup -= delta
		return
	var target_npc := get_next_unseen_character()
	for child in characters.get_children():
		if not child is PS3CharacterNPC:
			continue
		if child == target_npc:
			if not child.approaching_player:
				child.start_approach_player(player, navigation)
		elif child.approaching_player:
			child.stop_approach_player(navigation)
	approaching_character = target_npc
	if is_instance_valid(target_npc) and target_npc.has_reached_player(player):
		open_conversation(target_npc, true)

func _process(delta: float) -> void:
	_update_daily_checkins(delta)
	if dialogue.visible or settings_ui.visible:
		talk_button.hide()
		models_button.hide()
		return
	models_button.show()
	talk_button.offset_top = -170 if _hud.size.x < 600 else -114
	talk_button.offset_bottom = -118 if _hud.size.x < 600 else -62
	nearby_character = find_nearby_character()
	talk_button.visible = is_instance_valid(nearby_character)
	if nearby_character:
		talk_button.text = "Talk to %s%s" % [nearby_character.character_name, "" if OS.has_feature("mobile") else "  ·  E"]

func find_nearby_character() -> Node3D:
	if not is_instance_valid(player) or not is_instance_valid(characters): return null
	var nearest: Node3D
	var distance := TALK_DISTANCE
	for candidate in characters.get_children():
		if not candidate is PS3CharacterNPC: continue
		var offset: Vector3 = candidate.global_position - player.global_position
		if absf(offset.y) > 1.8 or offset.length() >= distance: continue
		# Solid map walls block interaction, while character/player capsules do not.
		var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 1.3, candidate.global_position + Vector3.UP * 1.3, 1)
		if not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		nearest = candidate
		distance = offset.length()
	return nearest

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE and (dialogue.visible or settings_ui.visible):
		if settings_ui.visible: close_settings()
		else: close_conversation()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F8:
		if settings_ui.visible: close_settings()
		else: open_settings()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F10:
		UIThemes.cycle_theme(1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E and not dialogue.visible and not settings_ui.visible and is_instance_valid(nearby_character):
		open_conversation(nearby_character)
		get_viewport().set_input_as_handled()

func open_conversation(character: Node3D, initiated_by_npc: bool = false) -> void:
	if not is_instance_valid(character) or settings_ui.visible: return
	if is_instance_valid(active_character): close_conversation()
	if character is PS3CharacterNPC and character.approaching_player:
		initiated_by_npc = true
		character.stop_approach_player(navigation)
	if approaching_character == character:
		approaching_character = null
	active_character = character
	_lock_player()
	if is_instance_valid(player) and player.has_method("begin_dialogue_zoom"):
		player.begin_dialogue_zoom(active_character)
	active_character.set_dialogue_paused(true)
	_pending_text = ""
	var cid: String = character.character_id
	var day := today_key()
	var unseen_today: bool = Personas.has_persona(cid) and not memory.has_seen_today(cid, day)
	session_is_checkin = unseen_today
	session_goal_review = Personas.wants_goal_review(cid, day, memory.days_since_goal_review(cid, day))
	session_phase = "agenda" if session_is_checkin else "open"
	agenda_turns = 0
	var recent: Array = memory.get_recent(cid)
	var memory_error: String = memory.last_error
	dialogue.begin(character.character_name, model_label(cid), recent)
	if not memory_error.is_empty():
		dialogue.set_status("Memory could not be read. Check Characters & memory: " + memory_error.left(160))
		return
	if session_is_checkin:
		memory.mark_seen_today(cid, day, session_goal_review)
		if initiated_by_npc:
			var opening_line := Personas.build_opening_line(cid, memory.get_notes(cid), recent, session_goal_review, memory.get_friendship_status(cid))
			dialogue.add_message("assistant", opening_line)
		dialogue.set_status(Personas.cue_text(cid, character.character_name))
	var valid := Registry.validate_profile(profile_for(cid))
	if not valid.get("ok", false):
		dialogue.set_status("Open Models to choose a provider and model before sending.")

func close_conversation() -> void:
	_cancel_reply(false)
	if is_instance_valid(active_character):
		var closing_id: String = active_character.character_id
		if session_is_checkin and Personas.has_persona(closing_id):
			memory.mark_seen_today(closing_id, today_key(), session_goal_review)
		memory.auto_compact_if_needed(closing_id)
		active_character.set_dialogue_paused(false)
		if active_character is PS3CharacterNPC and active_character.approaching_player:
			active_character.stop_approach_player(navigation)
	active_character = null
	_pending_text = ""
	dialogue.dismiss()
	if settings_ui.visible: settings_ui.dismiss()
	_unlock_player()

func open_settings() -> void:
	if settings_ui.visible: return
	_lock_player()
	if _busy: _cancel_reply()
	dialogue.hide()
	dialogue.composer.release_focus()
	settings_ui.open(settings, active_character.character_id if is_instance_valid(active_character) else "alien_suit")

func close_settings() -> void:
	settings_ui.dismiss()
	_refresh_model_label()
	if not is_instance_valid(active_character):
		_unlock_player()
	else:
		dialogue.show()
		if not OS.has_feature("mobile"): dialogue.composer.grab_focus()

func _lock_player() -> void:
	var lab := get_parent().get_node_or_null("VisualLab")
	if lab:
		lab.set_panel_open(false)
		lab.set_process_input(false)
	if not is_instance_valid(player): return
	if not player.dialogue_locked: _restore_capture = player.is_mouse_captured
	player.set_dialogue_locked(true)

func _unlock_player() -> void:
	var lab := get_parent().get_node_or_null("VisualLab")
	if lab: lab.set_process_input(true)
	if is_instance_valid(player):
		player.set_dialogue_locked(false)
		player.capture_mouse(_restore_capture)

func profile_for(character_id: String) -> Dictionary:
	var id := str(settings.get("character_profiles", {}).get(character_id, ""))
	if id.is_empty(): id = str(settings.get("default_profile_id", ""))
	for profile in settings.get("profiles", []):
		if str(profile.get("id", "")) == id: return profile.duplicate(true)
	return Registry.default_profile()

func model_label(character_id: String) -> String:
	var profile := profile_for(character_id)
	var model := str(profile.get("model", ""))
	return "%s · %s" % [str(profile.get("name", "Model")), model] if not model.is_empty() else "Choose a model in Models"

func _refresh_model_label() -> void:
	if is_instance_valid(active_character): dialogue.model_label.text = model_label(active_character.character_id)

func _send(text: String) -> void:
	if _busy or not is_instance_valid(active_character): return
	_pending_text = text.strip_edges().left(8000)
	if _pending_text.is_empty(): return
	dialogue.add_message("user", _pending_text)
	_run_reply()

func _retry() -> void:
	if not _busy and not _pending_text.is_empty() and is_instance_valid(active_character): _run_reply()

func _run_reply() -> void:
	var character_id: String = active_character.character_id
	var query := _pending_text
	var epoch := _epoch
	_busy = true
	dialogue.set_busy(true)
	var next_agenda_turns := agenda_turns
	var request_phase := session_phase
	var next_phase := session_phase
	var declined_offer := false
	if session_phase == "agenda":
		next_agenda_turns = agenda_turns + 1
	elif session_phase == "offer":
		if Personas.is_clear_decline(query):
			request_phase = "offer_declined"
			declined_offer = true
		else:
			request_phase = "offer"
			next_phase = "open"
	elif session_phase == "open":
		var lower_q := query.to_lower().strip_edges()
		if lower_q in ["bye", "goodbye", "good bye", "see you", "i have to go", "i should go", "i'm done", "im done", "done for now"]:
			request_phase = "offer_declined"
			declined_offer = true
	var friendship_status: String = memory.get_friendship_status(character_id)
	var system_text := Personas.system_prompt(character_id, active_character.character_name) + "\n\n" + Personas.phase_instructions(character_id, request_phase, next_agenda_turns, session_goal_review, friendship_status)
	var messages: Array = [{"role": "system", "content": system_text}]
	messages.append_array(memory.build_context(character_id, query, Personas.recall_query(character_id)))
	if not memory.last_error.is_empty():
		_busy = false
		dialogue.set_busy(false)
		dialogue.set_status("Memory could not be read: " + memory.last_error.left(180), true)
		return
	if client.has_method("is_busy"):
		while client.is_busy():
			await get_tree().process_frame
			if epoch != _epoch: return
	# Rebuild after any transport wait, including retries. Never persist this
	# shared public snapshot or merge it with a character's private memory.
	messages.append({"role": "system", "content": world_context.build_context(get_parent(), active_character, player, characters)})
	messages.append({"role": "user", "content": query})
	var result: Dictionary = await client.generate(profile_for(character_id), messages)
	if epoch != _epoch or not is_instance_valid(active_character) or active_character.character_id != character_id: return
	_busy = false
	dialogue.set_busy(false)
	if not result.get("ok", false):
		dialogue.set_status(str(result.get("error", "The model did not answer. Try again.")).left(360), true)
		return
	var raw_answer := str(result.get("text", "")).strip_edges()
	var parsed := Personas.parse_reply(raw_answer)
	var answer: String = str(parsed.text)
	if answer.is_empty():
		dialogue.set_status("The model returned no text. Try again or choose another model.", true)
		return
	agenda_turns = next_agenda_turns
	session_phase = next_phase
	var offer_triggered: bool = parsed.offer or Personas.looks_like_offer(answer)
	var end_triggered: bool = parsed.end or declined_offer
	if session_phase == "agenda" and not end_triggered:
		if offer_triggered:
			session_phase = "offer"
		elif agenda_turns >= 2:
			if answer.length() + Personas.offer_line(character_id).length() + 2 <= MAX_REPLY_CHARS:
				answer = (answer + "\n\n" + Personas.offer_line(character_id)).strip_edges()
			session_phase = "offer"
			offer_triggered = true
	var truncated: bool = answer.length() > MAX_REPLY_CHARS or result.get("truncated", false)
	answer = answer.left(MAX_REPLY_CHARS)
	dialogue.add_message("assistant", answer)
	var saved: Dictionary = memory.append_turn(character_id, query, answer)
	memory.auto_compact_if_needed(character_id)
	_pending_text = ""
	if not saved.get("ok", false):
		dialogue.set_status("Reply received, but memory could not be saved: " + str(saved.get("error", "Storage unavailable.")).left(160))
	elif end_triggered:
		close_conversation()
		return
	elif session_phase == "offer":
		dialogue.set_status("Asked if you'd like to talk about anything else — reply no to finish, or keep talking.")
	else:
		dialogue.set_status("Long reply shortened. A bounded excerpt was saved." if truncated else "Saved to this character's bounded memory.")

func _cancel_reply(offer_retry: bool = true) -> void:
	_epoch += 1
	client.cancel()
	if _busy:
		_busy = false
		dialogue.set_busy(false)
		dialogue.set_status("Stopped. This exchange was not saved.", offer_retry and not _pending_text.is_empty())

func _memory_action(action: String, character_id: String, value: int) -> void:
	var result: Dictionary = {"ok": true}
	var message := ""
	match action:
		"clear":
			if active_character and active_character.character_id == character_id:
				_cancel_reply(false)
			result = memory.clear_character(character_id)
			if result.get("ok", false) and active_character and active_character.character_id == character_id:
				_pending_text = ""
				dialogue.clear_messages()
			message = "Memory cleared."
		"compact":
			result = memory.compact(character_id)
			message = "Older exchanges compacted."
		"budget":
			var candidate_limits: Dictionary = _memory_limits.duplicate(true)
			candidate_limits.global_bytes = value
			result = memory.set_limits(candidate_limits)
			if result.get("ok", false):
				_memory_limits = candidate_limits
				var candidate_settings := settings.duplicate(true)
				candidate_settings["memory_limits"] = candidate_limits
				result = Registry.save_settings(candidate_settings, storage_root.path_join("model_settings.json"))
				if result.get("ok", false):
					settings = result.settings
					_memory_limits = settings.get("memory_limits", {}).duplicate(true)
					settings_ui.settings = settings.duplicate(true)
				else:
					result.error = "Budget applied for this session but not saved. Any pruning already performed cannot be undone."
			message = "Storage budget updated."
	if not result.get("ok", false): message = str(result.get("error", "Memory operation failed."))
	settings_ui.show_memory_stats(memory.get_stats(character_id), message)
