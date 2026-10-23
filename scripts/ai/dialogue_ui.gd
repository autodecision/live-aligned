class_name CharacterDialogueUI
extends Control
## Plain-text, touch-friendly conversation sheet. No model text is interpreted.
signal submitted(text: String)
signal close_requested
signal settings_requested
signal cancel_requested
signal retry_requested

const UIThemes = preload("res://scripts/ui_themes.gd")
const INK := Color("fff9e8")
const MUTED := Color("bbc9ed")
const ACCENT := Color("e2eaff")
static var _frame_textures: Dictionary = {}
var panel: PanelContainer
var title_label: Label
var model_label: Label
var transcript: VBoxContainer
var scroll: ScrollContainer
var composer: TextEdit
var status_label: Label
var send_button: Button
var cancel_button: Button
var retry_button: Button
const MAX_VISIBLE_MESSAGES := 48
const MAX_MESSAGE_CHARS := 16000
var _column: VBoxContainer
var _busy := false
var _last_keyboard := -1

static func box(color: Color, radius: int = 16, padding: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

## Nine-patch frame: thin silver bevel around a vertical gradient.
## Generated once per palette, with fixed-width edges at every window size.
static func dialogue_box(top: Color = Color("253f9b"), bottom: Color = Color("090f42"), padding: int = 18, bevel: Array = []) -> StyleBoxTexture:
	return UIThemes.get_dialogue_box(top, bottom, padding, bevel)

static func make_theme() -> Theme:
	return UIThemes.make_dialogue_theme()

static func label(text: String, font_size: int = 17, color: Color = INK) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return item

static func button(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 46
	item.pressed.connect(action)
	return item

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = make_theme()
	UIThemes.add_theme_listener(_on_theme_changed)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.06, 0.24)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var t := UIThemes.get_current()
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIThemes.get_dialogue_box(t.frame_top, t.frame_bottom, 18, t.bevel))
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(panel)
	panel.minimum_size_changed.connect(func(): _layout.call_deferred())
	var column := VBoxContainer.new()
	_column = column
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	title_label = label("Conversation", 24)
	titles.add_child(title_label)
	model_label = label("Choose a model to begin", 13, MUTED)
	titles.add_child(model_label)
	header.add_child(button("Close", func(): close_requested.emit()))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	transcript = VBoxContainer.new()
	transcript.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript.add_theme_constant_override("separation", 12)
	scroll.add_child(transcript)
	status_label = label("A quiet moment to talk.", 14, MUTED)
	status_label.max_lines_visible = 2
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(status_label)
	composer = TextEdit.new()
	composer.placeholder_text = "What would you like to say?"
	composer.custom_minimum_size.y = 84
	composer.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	composer.scroll_fit_content_height = false
	composer.virtual_keyboard_enabled = true
	composer.gui_input.connect(_composer_input)
	composer.text_changed.connect(func():
		if composer.text.length() > 8000:
			composer.text = composer.text.left(8000)
		send_button.disabled = _busy or composer.text.strip_edges().is_empty())
	column.add_child(composer)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	actions.add_child(button("Models", func(): settings_requested.emit()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	retry_button = button("Retry", func(): retry_requested.emit())
	retry_button.hide()
	actions.add_child(retry_button)
	cancel_button = button("Stop", func(): cancel_requested.emit())
	cancel_button.hide()
	actions.add_child(cancel_button)
	send_button = button("Send", _submit)
	send_button.disabled = true
	actions.add_child(send_button)
	resized.connect(_layout)
	_layout()
	hide()

func _process(_delta: float) -> void:
	if visible:
		var keyboard := keyboard_height()
		if keyboard != _last_keyboard:
			_last_keyboard = keyboard
			_layout()

func _exit_tree() -> void:
	UIThemes.remove_theme_listener(_on_theme_changed)

func _on_theme_changed(_id: String, theme_data: Dictionary) -> void:
	theme = UIThemes.make_dialogue_theme(theme_data)
	if is_instance_valid(panel):
		var scale_y := size.y / maxf(1, DisplayServer.window_get_size().y)
		var keyboard := keyboard_height() * scale_y
		var compact := (size.y - keyboard) < 420
		panel.add_theme_stylebox_override("panel", UIThemes.get_dialogue_box(theme_data.frame_top, theme_data.frame_bottom, 10 if compact else 20, theme_data.bevel))
	if is_instance_valid(model_label):
		model_label.add_theme_color_override("font_color", theme_data.muted)
	if is_instance_valid(status_label):
		status_label.add_theme_color_override("font_color", theme_data.muted)
	if is_instance_valid(transcript):
		for bubble in transcript.get_children():
			if bubble is PanelContainer:
				var is_user: bool = bubble.has_meta("role") and str(bubble.get_meta("role")) == "user"
				bubble.add_theme_stylebox_override("panel", UIThemes.get_bubble_style("user" if is_user else "assistant", theme_data, 14))
				if bubble.get_child_count() > 0 and bubble.get_child(0) is VBoxContainer:
					var vbox: VBoxContainer = bubble.get_child(0)
					if vbox.get_child_count() > 0 and vbox.get_child(0) is Label:
						vbox.get_child(0).add_theme_color_override("font_color", theme_data.accent)
					if vbox.get_child_count() > 1 and vbox.get_child(1) is Label:
						vbox.get_child(1).add_theme_color_override("font_color", theme_data.ink)

func _layout() -> void:
	if not panel:
		return
	var scale_y := size.y / maxf(1, DisplayServer.window_get_size().y)
	var keyboard := keyboard_height() * scale_y
	var available := maxf(180, size.y - keyboard)
	var compact := available < 420
	var margin := 6.0 if compact else (12.0 if size.x < 600 else 28.0)
	var width := minf(820, size.x - margin * 2)
	var height := minf(730, available - margin * 2)
	var t := UIThemes.get_current()
	panel.add_theme_stylebox_override("panel", UIThemes.get_dialogue_box(t.frame_top, t.frame_bottom, 10 if compact else 20, t.bevel))
	_column.add_theme_constant_override("separation", 6 if compact else 12)
	model_label.visible = not compact
	status_label.visible = available >= 260
	scroll.visible = available >= 300
	panel.position = Vector2((size.x - width) / 2, (available - height) / 2)
	panel.size = Vector2(width, height)
	composer.custom_minimum_size.y = 48 if available < 480 else 84
	composer.size_flags_vertical = Control.SIZE_EXPAND_FILL if available < 300 else Control.SIZE_FILL
	_scroll_to_end.call_deferred()
	title_label.add_theme_font_size_override("font_size", 20 if size.x < 600 else 24)

func _composer_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER and not event.shift_pressed:
		accept_event()
		_submit()

func _submit() -> void:
	var message := composer.text.strip_edges()
	if _busy or message.is_empty():
		return
	composer.text = ""
	hide_keyboard()
	submitted.emit(message)

func begin(character_name: String, model_name: String, messages: Array) -> void:
	title_label.text = character_name
	model_label.text = model_name
	clear_messages()
	for message in messages:
		add_message(str(message.get("role", "assistant")), str(message.get("content", "")))
	composer.text = ""
	set_busy(false)
	set_status("A quiet moment to talk. This character keeps their own memory.")
	show()
	_layout()
	if not OS.has_feature("mobile"):
		composer.grab_focus()

func clear_messages() -> void:
	for child in transcript.get_children():
		transcript.remove_child(child)
		child.queue_free()

func add_message(role: String, text: String) -> void:
	while transcript.get_child_count() >= MAX_VISIBLE_MESSAGES:
		var oldest := transcript.get_child(0)
		transcript.remove_child(oldest)
		oldest.queue_free()
	text = text.left(MAX_MESSAGE_CHARS)
	var t := UIThemes.get_current()
	var bubble := PanelContainer.new()
	bubble.set_meta("role", role)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override("panel", UIThemes.get_bubble_style(role, t, 14))
	transcript.add_child(bubble)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 6)
	bubble.add_child(contents)
	contents.add_child(label("YOU" if role == "user" else title_label.text.to_upper(), 13, t.accent))
	contents.add_child(label(text, 18, t.ink))
	_scroll_to_end.call_deferred()

func _scroll_to_end() -> void:
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func set_busy(busy: bool) -> void:
	_busy = busy
	composer.editable = not busy
	send_button.disabled = busy or composer.text.strip_edges().is_empty()
	cancel_button.visible = busy
	retry_button.hide()
	if busy:
		set_status("Thinking…")

func set_status(text: String, can_retry: bool = false) -> void:
	status_label.text = text
	status_label.tooltip_text = text
	retry_button.visible = can_retry and not _busy

func dismiss() -> void:
	hide_keyboard()
	hide()

static func keyboard_height() -> int:
	return DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0

static func hide_keyboard() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
