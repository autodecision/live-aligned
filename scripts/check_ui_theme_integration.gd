extends SceneTree
const UIThemes = preload("res://scripts/ui_themes.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- BEGIN UI THEMES INTEGRATION TEST ---")
	var themes := UIThemes.get_all_themes()
	assert(themes.size() == 12, "Expected exactly 12 themes")
	
	# Verify ROYGBIV coverage
	var roygbiv_expected := {
		"R": "ruby_red",
		"O": "amber_orange",
		"Y": "solar_gold",
		"G": "emerald_green",
		"B": "cobalt_blue",
		"I": "deep_indigo",
		"V": "amethyst_violet"
	}
	for letter in roygbiv_expected:
		var expected_id: String = roygbiv_expected[letter]
		var found := false
		for t in themes:
			if t.category == "ROYGBIV" and t.roygbiv_letter == letter:
				assert(t.id == expected_id, "Theme ID mismatch for letter " + letter)
				found = true
				break
		assert(found, "Missing ROYGBIV theme for letter: " + letter)
	print("✓ All 7 ROYGBIV color themes verified (Red, Orange, Yellow, Green, Blue, Indigo, Violet)")
	
	# Verify popular themes coverage
	var popular_expected := ["cyberpunk_neon", "obsidian_slate", "sakura_blush", "nord_frost", "vaporwave_synth"]
	for pid in popular_expected:
		var found := false
		for t in themes:
			if t.category == "Popular" and t.id == pid:
				found = true
				break
		assert(found, "Missing popular theme: " + pid)
	print("✓ All 5 popular themes verified (Cyberpunk, Obsidian, Sakura, Nord/Arctic, Vaporwave/Synth)")
	
	# Instantiate Main scene
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 6: await process_frame
	
	var player: CharacterBody3D = main.get_node("Player")
	var visual_lab: CanvasLayer = main.get_node("VisualLab")
	var dialogue_controller: CanvasLayer = main.get_node("CharacterDialogue")
	var dialogue_ui: Control = dialogue_controller.dialogue
	var settings_ui: Control = dialogue_controller.settings_ui
	
	assert(player != null, "Player node missing")
	assert(visual_lab != null, "VisualLab node missing")
	assert(dialogue_ui != null, "Dialogue UI missing")
	assert(settings_ui != null, "Settings UI missing")
	
	# Verify Settings UI Appearance Tab (Tab 2)
	assert(settings_ui.tabs.get_child_count() >= 3, "Settings UI should have at least 3 tabs")
	var appearance_tab: ScrollContainer = settings_ui.tabs.get_child(2) as ScrollContainer
	assert(appearance_tab != null and appearance_tab.name == "Appearance", "Tab 2 must be 'Appearance'")
	assert(is_instance_valid(settings_ui.theme_picker), "Settings theme_picker must be valid")
	assert(settings_ui.theme_picker.item_count == 12, "Settings theme_picker must have 12 items")
	assert(is_instance_valid(settings_ui.theme_preview_panel), "Preview panel must be valid")
	assert(is_instance_valid(settings_ui.theme_swatches_container), "Swatches container must be valid")
	assert(settings_ui.theme_swatches_container.get_child_count() == 5, "Swatches container should have 5 chips")
	print("✓ AI Settings UI Appearance tab (Tab 2) verified with theme picker, preview card, and swatches")
	
	# Verify Visual Lab Style Tab has UI Theme Section
	assert(visual_lab._tabs.get_child_count() >= 5, "VisualLab must have 5 tabs")
	var style_col: VBoxContainer = visual_lab._tabs.get_child(4).get_child(0)
	var theme_sec: VBoxContainer = style_col.get_node_or_null("UIThemeSection")
	assert(theme_sec != null, "VisualLab Style tab must contain UIThemeSection")
	assert(is_instance_valid(visual_lab._theme_picker), "VisualLab _theme_picker must be valid")
	assert(visual_lab._theme_picker.item_count == 12, "VisualLab _theme_picker must have 12 items")
	print("✓ Visual Lab Style tab verified with UI Color Theme controls")
	
	# Test cycle through all 12 themes and check real-time reaction across all components
	for step in 12:
		var cycled: Dictionary = UIThemes.cycle_theme(1)
		for i in 2: await process_frame
		
		# Check UIThemes current
		assert(UIThemes.get_current_id() == cycled.id)
		
		# Check Settings UI updated
		assert(settings_ui.theme_picker.get_item_metadata(settings_ui.theme_picker.selected) == cycled.id)
		assert(settings_ui.theme_desc_label.text == cycled.description)
		
		# Check Visual Lab updated
		assert(visual_lab._theme_picker.get_item_metadata(visual_lab._theme_picker.selected) == cycled.id)
		assert(visual_lab._theme_desc.text == cycled.description)
		
		# Check Player HUD updated
		var title: Label = player.get_node("CanvasLayer/HUD/TitleLabel")
		assert(title.get_theme_color("font_color") == cycled.accent)
	
	print("✓ Real-time theme synchronization tested across all 12 themes")
	
	# Test F10 input handling in player and dialogue controller
	var initial_id := UIThemes.get_current_id()
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_F10
	key_event.keycode = KEY_F10
	key_event.pressed = true
	player._unhandled_input(key_event)
	for i in 2: await process_frame
	assert(UIThemes.get_current_id() != initial_id, "F10 should cycle theme in Player")
	
	var cur_id := UIThemes.get_current_id()
	dialogue_controller._input(key_event)
	for i in 2: await process_frame
	assert(UIThemes.get_current_id() != cur_id, "F10 should cycle theme in CharacterDialogue")
	print("✓ F10 shortcut verified in both player and dialogue controller")
	
	# Test persistence
	UIThemes.set_theme("ruby_red", true)
	var loaded := UIThemes._load_preference()
	assert(loaded == "ruby_red", "Saved theme preference must match ruby_red")
	
	# Restore to cobalt_blue
	UIThemes.set_theme("cobalt_blue", true)
	print("✓ UI theme preference persistence verified")
	
	print("ALL UI THEMES INTEGRATION TESTS PASSED!")
	quit()
