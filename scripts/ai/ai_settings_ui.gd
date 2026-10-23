class_name AISettingsUI
extends Control
## Provider/profile settings. Secrets live only in the credential session store.
signal close_requested
signal settings_changed(settings: Dictionary)
signal memory_action(action: String, character_id: String, value: int)
const UI = preload("res://scripts/ai/dialogue_ui.gd")
const UIThemes = preload("res://scripts/ui_themes.gd")
const Registry = preload("res://scripts/ai/ai_provider_registry.gd")
const Credentials = preload("res://scripts/ai/ai_credentials.gd")
const Client = preload("res://scripts/ai/ai_provider_client.gd")
const CHARACTERS := {"alien_suit": "The Envoy", "female_scientist": "Dr. Vale", "robot": "Kestrel-09"}
var settings: Dictionary = {}
var settings_path := Registry.SETTINGS_PATH
var transport_picker: OptionButton
var hermes_button: Button
var hermes_note: Label
var _network_epoch := 0
var _clear_character_id := ""
var _budget_confirm: ConfirmationDialog
var _pending_budget := 0
var _current_budget := 128 * 1048576
var _current_bytes := 0
var panel: PanelContainer
var tabs: TabContainer
var profile_picker: OptionButton
var provider_picker: OptionButton
var auth_picker: OptionButton
var model_picker: OptionButton
var fields: Dictionary = {}
var oauth_fields: VBoxContainer
var secret: LineEdit
var status: Label
var sign_in: Button
var stop_login: Button
var assignment_character: OptionButton
var assignment_profile: OptionButton
var memory_stats: Label
var budget_picker: OptionButton
var theme_picker: OptionButton
var theme_desc_label: Label
var theme_preview_panel: PanelContainer
var theme_swatches_container: HBoxContainer
var _theme_sample_box: PanelContainer
var _theme_preview_label: Label
var client: Node
var _profile_index := 0
var _loading := false
var _network_busy := false
var _confirm: ConfirmationDialog
var _last_keyboard := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.make_theme()
	UIThemes.add_theme_listener(_on_theme_changed)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.06, 0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.dialogue_box())
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(panel)
	panel.minimum_size_changed.connect(func(): _layout.call_deferred())
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	header.add_child(UI.label("Conversation settings", 23))
	header.add_child(UI.button("Done", func(): close_requested.emit()))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(tabs)
	var profiles := _page("Models")
	profiles.add_child(UI.label("Connect a model", 21))
	profiles.add_child(UI.label("Choose a provider, add a model, then save a profile. API keys and sign-in tokens stay in memory until the app closes.", 14, UI.MUTED))
	var row := HBoxContainer.new()
	profiles.add_child(row)
	profile_picker = OptionButton.new()
	profile_picker.fit_to_longest_item = false
	profile_picker.clip_text = true
	profile_picker.custom_minimum_size.y = 46
	profile_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_picker.item_selected.connect(_load_profile)
	row.add_child(profile_picker)
	row.add_child(UI.button("New", _new_profile))
	_field(profiles, "name", "Profile name", "My model")
	provider_picker = _picker(profiles, "Provider")
	for provider in Registry.list_providers():
		provider_picker.add_item(str(provider.name))
		provider_picker.set_item_metadata(provider_picker.item_count - 1, str(provider.id))
	provider_picker.item_selected.connect(_provider_changed)
	transport_picker = _picker(profiles, "API format")
	for transport in Registry.TRANSPORTS:
		transport_picker.add_item({"responses": "Responses", "chat_completions": "Chat Completions", "anthropic_messages": "Anthropic Messages"}[transport])
		transport_picker.set_item_metadata(transport_picker.item_count - 1, transport)
	_field(profiles, "model", "Model ID", "Enter a model ID or discover below")
	model_picker = _picker(profiles, "Available models")
	model_picker.add_item("Discover models to populate this list")
	model_picker.item_selected.connect(func(index):
		var value = model_picker.get_item_metadata(index)
		if value != null: fields.model.text = str(value))
	profiles.add_child(UI.button("Discover models", _discover_models))
	_field(profiles, "base_url", "Endpoint", "https://…")
	_field(profiles, "max_output_tokens", "Maximum reply tokens (64–8192)", "512")
	_field(profiles, "timeout_seconds", "Request timeout in seconds (5–180)", "60")
	auth_picker = _picker(profiles, "Authentication")
	auth_picker.item_selected.connect(func(_index): _auth_changed())
	secret = _field(profiles, "secret", "API key (this session)", "Leave blank to keep the current key")
	secret.secret = true
	profiles.add_child(UI.button("Forget session credential", _forget_secret))
	hermes_button = UI.button("Use Hermes session (Nous)", _import_hermes)
	profiles.add_child(hermes_button)
	hermes_note = UI.label("Desktop only. Sign into Hermes separately, then import its Nous session. Re-import after expiry.", 14, UI.MUTED)
	profiles.add_child(hermes_note)
	oauth_fields = VBoxContainer.new()
	oauth_fields.add_theme_constant_override("separation", 8)
	profiles.add_child(oauth_fields)
	oauth_fields.add_child(UI.label("Device sign-in needs a public client registration approved by your provider. Enter that registration's endpoints and client ID.", 14, UI.MUTED))
	_field(oauth_fields, "oauth_client_id", "Public client ID", "Your registered application")
	_field(oauth_fields, "oauth_device_url", "Device authorization URL", "https://…")
	_field(oauth_fields, "oauth_token_url", "Token URL", "https://…")
	_field(oauth_fields, "oauth_scope", "Scopes", "Provider-approved scopes")
	sign_in = UI.button("Sign in with browser", _sign_in)
	oauth_fields.add_child(sign_in)
	stop_login = UI.button("Cancel sign-in", _cancel_network)
	stop_login.hide()
	oauth_fields.add_child(stop_login)
	profiles.add_child(UI.button("Save profile", _save_profile))
	profiles.add_child(UI.button("Use this as the default", _set_default))
	status = UI.label("", 14, UI.ACCENT)
	status.max_lines_visible = 4
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	outer.add_child(status)
	var characters := _page("Characters & memory")
	characters.add_child(UI.label("A model for each character", 21))
	characters.add_child(UI.label("Each character has separate conversation memory, even when they share a model.", 14, UI.MUTED))
	assignment_character = _picker(characters, "Character")
	for id in CHARACTERS:
		assignment_character.add_item(CHARACTERS[id])
		assignment_character.set_item_metadata(assignment_character.item_count - 1, id)
	assignment_character.item_selected.connect(func(_i): _refresh_assignment(); memory_action.emit("stats", selected_character(), 0))
	assignment_profile = _picker(characters, "Model profile")
	assignment_profile.item_selected.connect(_assign_profile)
	memory_stats = UI.label("Memory usage will appear here.", 15, UI.MUTED)
	characters.add_child(memory_stats)
	characters.add_child(UI.button("Compact this character's memory", func(): memory_action.emit("compact", selected_character(), 0)))
	characters.add_child(UI.label("Compaction keeps short extracts of older conversations. Exact wording can be lost. Oldest recall is pruned when the storage budget is reached.", 14, UI.MUTED))
	characters.add_child(UI.button("Clear this character's memory…", _confirm_clear))
	budget_picker = _picker(characters, "Total memory budget on this device")
	for mib in [128, 512, 1024, 2048]:
		budget_picker.add_item("%d MiB" % mib)
		budget_picker.set_item_metadata(budget_picker.item_count - 1, mib * 1024 * 1024)
	budget_picker.item_selected.connect(_choose_budget)
	characters.add_child(UI.label("Memory is saved locally as plain text. Only this character's selected context is sent to the chosen provider when you send a message.", 14, UI.MUTED))
	var appearance := _page("Appearance")
	_build_appearance_tab(appearance)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Clear character memory?"
	_confirm.dialog_autowrap = true
	_confirm.dialog_text = "This permanently removes this character's saved conversation and recall. Other characters keep their memories."
	_confirm.confirmed.connect(func(): memory_action.emit("clear", _clear_character_id, 0))
	add_child(_confirm)
	_budget_confirm = ConfirmationDialog.new()
	_budget_confirm.title = "Reduce memory budget?"
	_budget_confirm.dialog_autowrap = true
	_budget_confirm.dialog_text = "Reducing the budget can permanently remove older recall and entire oldest character memories. Continue?"
	_budget_confirm.confirmed.connect(func(): memory_action.emit("budget", selected_character(), _pending_budget))
	_budget_confirm.canceled.connect(func(): _select_metadata(budget_picker, _current_budget))
	add_child(_budget_confirm)
	client = Client.new()
	add_child(client)
	resized.connect(_layout)
	_layout()
	hide()

func _page(title: String) -> VBoxContainer:
	var scroller := ScrollContainer.new()
	scroller.name = title
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.follow_focus = true
	tabs.add_child(scroller)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	scroller.add_child(page)
	return page

func _field(parent: Node, id: String, title: String, placeholder: String) -> LineEdit:
	parent.add_child(UI.label(title, 14, UI.MUTED))
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.custom_minimum_size.y = 46
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.max_length = 2048
	parent.add_child(field)
	fields[id] = field
	return field

func _picker(parent: Node, title: String) -> OptionButton:
	parent.add_child(UI.label(title, 14, UI.MUTED))
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 46
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item = false
	picker.clip_text = true
	parent.add_child(picker)
	return picker

func _process(_delta: float) -> void:
	if visible:
		var keyboard := UI.keyboard_height()
		if keyboard != _last_keyboard:
			_last_keyboard = keyboard
			_layout()

func _layout() -> void:
	if not panel: return
	var keyboard := UI.keyboard_height() * size.y / maxf(1, DisplayServer.window_get_size().y)
	var margin := 10.0 if size.x < 600 else 28.0
	var width := minf(720, size.x - 2 * margin)
	var height := minf(850, size.y - keyboard - 2 * margin)
	panel.size = Vector2(width, maxf(height, 180))
	panel.position = (Vector2(size.x, size.y - keyboard) - panel.size) / 2
	_scroll_focus.call_deferred()

func open(value: Dictionary, character_id: String = "alien_suit") -> void:
	settings = value.duplicate(true)
	if settings.get("profiles", []).is_empty():
		settings.profiles = [Registry.default_profile("openai")]
	_rebuild_profiles()
	_load_profile(0)
	_select_metadata(assignment_character, character_id)
	_refresh_assignment()
	memory_action.emit("stats", selected_character(), 0)
	show()
	_layout()

func dismiss() -> void:
	_cancel_network()
	secret.text = ""
	UI.hide_keyboard()
	hide()

func _rebuild_profiles() -> void:
	_loading = true
	profile_picker.clear()
	assignment_profile.clear()
	assignment_profile.add_item("Use default")
	assignment_profile.set_item_metadata(0, "")
	for profile in settings.profiles:
		profile_picker.add_item(str(profile.get("name", profile.id)))
		assignment_profile.add_item(str(profile.get("name", profile.id)))
		assignment_profile.set_item_metadata(assignment_profile.item_count - 1, str(profile.id))
	_loading = false

func _load_profile(index: int) -> void:
	if _network_busy: _cancel_network()
	_profile_index = index
	profile_picker.select(index)
	var profile: Dictionary = settings.profiles[index]
	for id in fields:
		fields[id].text = str(profile.get(id, "")) if id != "secret" else ""
	_select_metadata(provider_picker, str(profile.get("provider_id", "openai")))
	_fill_auth(str(profile.get("auth_mode", "api_key")))
	_select_metadata(transport_picker, str(profile.get("transport", "chat_completions")))
	transport_picker.disabled = str(profile.get("provider_id", "")) != "custom"
	model_picker.clear()
	model_picker.add_item("Discover models to populate this list")
	status.text = "Session credential available." if Credentials.has_secret(str(profile.id)) else "Keys are not saved to disk."

func _new_profile() -> void:
	if settings.profiles.size() >= 32:
		status.text = "Up to 32 model profiles are supported. Edit an existing profile."
		return
	var profile: Dictionary = Registry.default_profile("openai")
	profile.id = "profile_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	profile.name = "New model"
	settings.profiles.append(profile)
	_rebuild_profiles()
	_load_profile(settings.profiles.size() - 1)

func _provider_changed(_index: int) -> void:
	_cancel_network()
	var provider: Dictionary = Registry.provider(str(provider_picker.get_selected_metadata()))
	fields.base_url.text = str(provider.get("base_url", ""))
	fields.model.text = ""
	secret.text = ""
	_select_metadata(transport_picker, str(provider.get("transport", "chat_completions")))
	transport_picker.disabled = str(provider.get("id", "")) != "custom"
	model_picker.clear()
	model_picker.add_item("Discover models to populate this list")
	_fill_auth("api_key")

func _fill_auth(selected: String) -> void:
	var provider: Dictionary = Registry.provider(str(provider_picker.get_selected_metadata()))
	auth_picker.clear()
	for mode in provider.get("auth_modes", ["api_key"]):
		auth_picker.add_item({"api_key": "API key", "none": "No authentication / local", "oauth_device": "OAuth device sign-in", "hermes_session": "Existing Hermes session (desktop)"}.get(str(mode), str(mode)))
		auth_picker.set_item_metadata(auth_picker.item_count - 1, str(mode))
	_select_metadata(auth_picker, selected)
	_auth_changed()

func _auth_changed() -> void:
	if is_instance_valid(client): _cancel_network()
	secret.text = ""
	var mode := str(auth_picker.get_selected_metadata())
	secret.editable = mode == "api_key"
	oauth_fields.visible = mode == "oauth_device"
	hermes_button.visible = mode == "hermes_session"
	hermes_note.visible = mode == "hermes_session"

func _draft() -> Dictionary:
	var profile: Dictionary = settings.profiles[_profile_index].duplicate(true)
	for id in fields:
		if id != "secret": profile[id] = fields[id].text.strip_edges()
	profile.provider_id = str(provider_picker.get_selected_metadata())
	profile.auth_mode = str(auth_picker.get_selected_metadata())
	profile.transport = str(transport_picker.get_selected_metadata())
	profile.max_output_tokens = clampi(int(fields.max_output_tokens.text), 64, 8192)
	profile.timeout_seconds = clampi(int(fields.timeout_seconds.text), 5, 180)
	return profile

func _save_profile() -> bool:
	var profile := _draft()
	var valid: Dictionary = Registry.validate_profile(profile)
	if not valid.get("ok", false):
		status.text = str(valid.get("error", "Check the profile fields."))
		return false
	Credentials.bind_profile(profile)
	settings.profiles[_profile_index] = profile
	if profile.auth_mode == "api_key" and not secret.text.strip_edges().is_empty():
		Credentials.set_secret(str(profile.id), secret.text.strip_edges())
		secret.text = ""
	var result: Dictionary = Registry.save_settings(settings, settings_path)
	if not result.get("ok", false):
		status.text = str(result.get("error", "Could not save settings."))
		return false
	settings = result.get("settings", settings)
	_rebuild_profiles()
	profile_picker.select(_profile_index)
	_refresh_assignment()
	status.text = "Profile saved. Credentials remain available only for this session."
	settings_changed.emit(settings)
	return true

func _set_default() -> void:
	if not _save_profile(): return
	settings.default_profile_id = str(settings.profiles[_profile_index].id)
	_persist_assignments("Default model updated.")

func _persist_assignments(message: String) -> void:
	var result: Dictionary = Registry.save_settings(settings, settings_path)
	if result.get("ok", false):
		settings = result.get("settings", settings)
		settings_changed.emit(settings)
		status.text = message
	else: status.text = str(result.get("error", "Could not save settings."))

func _assign_profile(index: int) -> void:
	if _loading: return
	var chosen := str(assignment_profile.get_item_metadata(index))
	for profile in settings.profiles:
		if str(profile.id) == chosen and not Registry.validate_profile(profile).get("ok", false):
			status.text = "Complete and save this model profile before assigning it."
			_refresh_assignment()
			return
	if not settings.has("character_profiles"): settings.character_profiles = {}
	settings.character_profiles[selected_character()] = str(assignment_profile.get_item_metadata(index))
	_persist_assignments("Character model updated.")

func _refresh_assignment() -> void:
	_loading = true
	_select_metadata(assignment_profile, str(settings.get("character_profiles", {}).get(selected_character(), "")))
	_loading = false

func selected_character() -> String:
	return str(assignment_character.get_selected_metadata())

func show_memory_stats(stats: Dictionary, message: String = "") -> void:
	memory_stats.text = "%sThis character: %.1f MiB · %d recent turns · %d recall entries\nAll characters: %.1f / %.0f MiB" % [(message + "\n") if not message.is_empty() else "", float(stats.get("bytes", 0)) / 1048576, int(stats.get("recent_turns", 0)), int(stats.get("recall_entries", 0)), float(stats.get("global_bytes", 0)) / 1048576, float(stats.get("global_budget_bytes", 0)) / 1048576]
	if not str(stats.get("error", "")).is_empty():
		memory_stats.text = "Memory unavailable: %s\nUse Clear this character’s memory to remove a damaged snapshot." % str(stats.error)
	_current_budget = int(stats.get("global_budget_bytes", 128 * 1048576))
	_current_bytes = int(stats.get("global_bytes", 0))
	memory_stats.text += "\nPer character cap: %.1f MiB · %d notes. Recall uses matching words; compaction keeps excerpts." % [float(stats.get("budget_bytes", 1048576)) / 1048576, int(stats.get("notes_count", 0))]
	_select_metadata(budget_picker, int(stats.get("global_budget_bytes", 128 * 1048576)))

func _confirm_clear() -> void:
	_clear_character_id = selected_character()
	_confirm.dialog_text = "Permanently clear %s's saved conversation and recall? Other characters keep their memories." % CHARACTERS[selected_character()]
	_confirm.popup_centered(Vector2i(mini(int(size.x) - 30, 440), 180))

func _forget_secret() -> void:
	Credentials.clear_secret(str(settings.profiles[_profile_index].id))
	secret.text = ""
	status.text = "Session credential forgotten."

func _prepare_network() -> Dictionary:
	var profile := _draft()
	Credentials.bind_profile(profile)
	if profile.auth_mode == "api_key" and not secret.text.strip_edges().is_empty():
		Credentials.set_secret(str(profile.id), secret.text.strip_edges())
		secret.text = ""
	return profile

func _discover_models() -> void:
	if _network_busy: return
	_network_busy = true
	status.text = "Looking up models…"
	var epoch := _network_epoch
	var result: Dictionary = await client.fetch_models(_prepare_network())
	if epoch != _network_epoch: return
	_network_busy = false
	if not is_inside_tree(): return
	if not result.get("ok", false):
		status.text = str(result.get("error", "Could not fetch models. Enter a model ID manually."))
		return
	model_picker.clear()
	for model in result.get("models", []):
		var id: String = str(model.get("id", "")) if model is Dictionary else str(model)
		model_picker.add_item(id)
		model_picker.set_item_metadata(model_picker.item_count - 1, id)
	status.text = "Choose a model from the list, then save your profile."

func _sign_in() -> void:
	if _network_busy: return
	_network_busy = true
	stop_login.show()
	var profile := _prepare_network()
	status.text = "Starting device sign-in…"
	var epoch := _network_epoch
	var result: Dictionary = await client.begin_device_login(profile)
	if epoch != _network_epoch: return
	if result.get("ok", false):
		var url := str(result.get("verification_uri", ""))
		status.text = "Open %s and enter code %s. Waiting for sign-in…" % [url, str(result.get("user_code", ""))]
		if url.begins_with("https://"): OS.shell_open(url)
		result = await client.complete_device_login(profile)
		if epoch != _network_epoch: return
	_network_busy = false
	stop_login.hide()
	status.text = "Signed in for this session. Save the profile to use it." if result.get("ok", false) else str(result.get("error", "Sign-in did not finish."))

func _cancel_network() -> void:
	_network_epoch += 1
	client.cancel()
	_network_busy = false
	stop_login.hide()

func _select_metadata(picker: OptionButton, value: Variant) -> void:
	for index in picker.item_count:
		if picker.get_item_metadata(index) == value:
			picker.select(index)
			return
	if picker.item_count: picker.select(0)

func _import_hermes() -> void:
	var profile := _prepare_network()
	var result: Dictionary = Credentials.import_hermes_session(profile)
	status.text = "Hermes session imported for Nous. Save this profile to use it." if result.get("ok", false) else str(result.get("error", "Session import failed."))

func _choose_budget(index: int) -> void:
	_pending_budget = int(budget_picker.get_item_metadata(index))
	if _pending_budget < _current_budget and _current_bytes > 0:
		_budget_confirm.popup_centered(Vector2i(mini(int(size.x) - 30, 440), 180))
	else:
		memory_action.emit("budget", selected_character(), _pending_budget)

func _scroll_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused and tabs.is_ancestor_of(focused):
		var scroller := tabs.get_child(tabs.current_tab) as ScrollContainer
		if scroller and scroller.is_ancestor_of(focused): scroller.ensure_control_visible(focused)

func _exit_tree() -> void:
	UIThemes.remove_theme_listener(_on_theme_changed)

func _on_theme_changed(_id: String, theme_data: Dictionary) -> void:
	theme = UIThemes.make_dialogue_theme(theme_data)
	if is_instance_valid(panel):
		panel.add_theme_stylebox_override("panel", UIThemes.get_dialogue_box(theme_data.frame_top, theme_data.frame_bottom, 18, theme_data.bevel))
	if is_instance_valid(status):
		status.add_theme_color_override("font_color", theme_data.accent)
	_refresh_theme_tab_preview(theme_data)

func _build_appearance_tab(appearance: VBoxContainer) -> void:
	appearance.add_child(UI.label("Interface appearance", 21))
	appearance.add_child(UI.label("Select a UI color theme. The theme updates all dialogue windows, settings sheets, tools, and HUD elements in real time.", 14, UI.MUTED))

	var picker_row := HBoxContainer.new()
	picker_row.add_theme_constant_override("separation", 8)
	appearance.add_child(picker_row)

	theme_picker = OptionButton.new()
	theme_picker.name = "ThemePicker"
	theme_picker.custom_minimum_size.y = 46
	theme_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theme_picker.clip_text = true

	var all_themes := UIThemes.get_all_themes()
	var current_id := UIThemes.get_current_id()
	var selected_idx := 0
	for i in all_themes.size():
		var t: Dictionary = all_themes[i]
		var tag: String = "[%s] " % t.roygbiv_letter if t.category == "ROYGBIV" else "★ "
		theme_picker.add_item("%s%s" % [tag, t.name])
		theme_picker.set_item_metadata(i, t.id)
		if t.id == current_id:
			selected_idx = i
	theme_picker.select(selected_idx)
	theme_picker.item_selected.connect(func(index: int):
		var tid: String = str(theme_picker.get_item_metadata(index))
		UIThemes.set_theme(tid)
	)
	picker_row.add_child(theme_picker)

	var prev_btn := UI.button("◀ Prev", func():
		var t := UIThemes.cycle_theme(-1)
		_refresh_theme_picker_selection(t.id)
	)
	var next_btn := UI.button("Next ▶", func():
		var t := UIThemes.cycle_theme(1)
		_refresh_theme_picker_selection(t.id)
	)
	picker_row.add_child(prev_btn)
	picker_row.add_child(next_btn)

	theme_desc_label = UI.label("", 14, UI.MUTED)
	theme_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	appearance.add_child(theme_desc_label)

	theme_preview_panel = PanelContainer.new()
	appearance.add_child(theme_preview_panel)

	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 10)
	theme_preview_panel.add_child(preview_box)

	_theme_preview_label = UI.label("THEME PREVIEW", 12)
	preview_box.add_child(_theme_preview_label)

	theme_swatches_container = HBoxContainer.new()
	theme_swatches_container.add_theme_constant_override("separation", 8)
	preview_box.add_child(theme_swatches_container)

	_theme_sample_box = PanelContainer.new()
	preview_box.add_child(_theme_sample_box)
	var bubble_inner := VBoxContainer.new()
	bubble_inner.add_theme_constant_override("separation", 4)
	_theme_sample_box.add_child(bubble_inner)
	var sample_role := UI.label("EXAMPLE DIALOGUE", 11)
	sample_role.name = "SampleRole"
	bubble_inner.add_child(sample_role)
	var sample_msg := UI.label("The afternoon sun warms the columns while the sea breeze moves through the garden.", 15)
	sample_msg.name = "SampleMsg"
	sample_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_inner.add_child(sample_msg)

	var shortcut_note := UI.label("Quick switch: Press F10 anywhere in-game to cycle between UI color themes.", 13, UI.MUTED)
	appearance.add_child(shortcut_note)

	_refresh_theme_tab_preview(UIThemes.get_current())

func _make_swatch(label_text: String, color: Color) -> VBoxContainer:
	var item := VBoxContainer.new()
	item.add_theme_constant_override("separation", 3)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rect := ColorRect.new()
	rect.color = color
	rect.custom_minimum_size = Vector2(36, 24)
	item.add_child(rect)
	var lbl := UI.label(label_text, 10, UI.MUTED)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_child(lbl)
	return item

func _refresh_theme_picker_selection(theme_id: String) -> void:
	if not is_instance_valid(theme_picker): return
	for i in theme_picker.item_count:
		if str(theme_picker.get_item_metadata(i)) == theme_id:
			theme_picker.select(i)
			break

func _refresh_theme_tab_preview(theme_data: Dictionary) -> void:
	if not is_instance_valid(theme_desc_label): return
	_refresh_theme_picker_selection(theme_data.id)
	theme_desc_label.text = theme_data.description
	theme_desc_label.add_theme_color_override("font_color", theme_data.muted)
	if is_instance_valid(_theme_preview_label):
		var cat: String = "[%s] " % theme_data.roygbiv_letter if theme_data.category == "ROYGBIV" else ""
		_theme_preview_label.text = "%s%s" % [cat, theme_data.name.to_upper()]
		_theme_preview_label.add_theme_color_override("font_color", theme_data.accent)
	if is_instance_valid(theme_preview_panel):
		theme_preview_panel.add_theme_stylebox_override("panel", UIThemes.get_dialogue_box(theme_data.frame_top, theme_data.frame_bottom, 12, theme_data.bevel))
	if is_instance_valid(theme_swatches_container):
		for child in theme_swatches_container.get_children():
			theme_swatches_container.remove_child(child)
			child.queue_free()
		theme_swatches_container.add_child(_make_swatch("Accent", theme_data.accent))
		theme_swatches_container.add_child(_make_swatch("Top", theme_data.frame_top))
		theme_swatches_container.add_child(_make_swatch("Bottom", theme_data.frame_bottom))
		theme_swatches_container.add_child(_make_swatch("Bevel", theme_data.bevel[1]))
		theme_swatches_container.add_child(_make_swatch("Ink", theme_data.ink))
	if is_instance_valid(_theme_sample_box):
		_theme_sample_box.add_theme_stylebox_override("panel", UIThemes.get_bubble_style("assistant", theme_data, 10))
		if _theme_sample_box.get_child_count() > 0:
			var inner: VBoxContainer = _theme_sample_box.get_child(0)
			if inner.has_node("SampleRole"):
				inner.get_node("SampleRole").add_theme_color_override("font_color", theme_data.accent)
			if inner.has_node("SampleMsg"):
				inner.get_node("SampleMsg").add_theme_color_override("font_color", theme_data.ink)
