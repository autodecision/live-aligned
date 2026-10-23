class_name UIThemes
extends RefCounted
## Global manager for Live Aligned UI color themes.
## Provides ROYGBIV color themes, popular visual styles, and dynamic runtime re-theming.

const PREFERENCE_PATH := "user://ui_theme.json"

const THEMES: Array[Dictionary] = [
	# --- ROYGBIV Colors ---
	{
		"id": "ruby_red",
		"name": "Ruby Red",
		"category": "ROYGBIV",
		"roygbiv_letter": "R",
		"description": "Deep crimson and rich ruby wine with vivid rose highlights.",
		"accent": Color("ff5469"),
		"ink": Color("fff2f4"),
		"muted": Color("fca5a5"),
		"bg_panel": Color(0.12, 0.03, 0.05, 0.98),
		"panel_border": Color("801e2e"),
		"frame_top": Color("771726"),
		"frame_bottom": Color("2b070e"),
		"button_normal_top": Color("54121d"),
		"button_normal_bottom": Color("2e0910"),
		"button_hover_top": Color("851b2c"),
		"button_hover_bottom": Color("470d17"),
		"button_pressed_top": Color("2e0910"),
		"button_pressed_bottom": Color("54121d"),
		"bevel": [Color("1a0408"), Color("fecdd3"), Color("e11d48"), Color("4c0519")],
		"tab_normal_top": Color("3d0c15"),
		"tab_normal_bottom": Color("24060c"),
		"tab_selected_top": Color("661523"),
		"tab_selected_bottom": Color("380b13"),
		"input_top": Color("2b070e"),
		"input_bottom": Color("190307"),
		"slider_grabber": Color("a82339"),
		"slider_track": Color("3d0c15"),
		"bubble_user_top": Color("701524"),
		"bubble_user_bottom": Color("380912"),
		"bubble_npc_top": Color("57101b"),
		"bubble_npc_bottom": Color("2e070e"),
	},
	{
		"id": "amber_orange",
		"name": "Sunset Amber",
		"category": "ROYGBIV",
		"roygbiv_letter": "O",
		"description": "Warm terracotta and glowing sunset amber inspired by Mediterranean twilight.",
		"accent": Color("fb923c"),
		"ink": Color("fffaf0"),
		"muted": Color("fdba74"),
		"bg_panel": Color(0.11, 0.06, 0.03, 0.98),
		"panel_border": Color("853612"),
		"frame_top": Color("7c2d12"),
		"frame_bottom": Color("2b0e04"),
		"button_normal_top": Color("5c200b"),
		"button_normal_bottom": Color("2e1005"),
		"button_hover_top": Color("8a3111"),
		"button_hover_bottom": Color("4c1908"),
		"button_pressed_top": Color("2e1005"),
		"button_pressed_bottom": Color("5c200b"),
		"bevel": [Color("170702"), Color("ffedd5"), Color("ea580c"), Color("431407")],
		"tab_normal_top": Color("3b1507"),
		"tab_normal_bottom": Color("240c04"),
		"tab_selected_top": Color("66240c"),
		"tab_selected_bottom": Color("3b1507"),
		"input_top": Color("2b0e04"),
		"input_bottom": Color("190702"),
		"slider_grabber": Color("b44616"),
		"slider_track": Color("3b1507"),
		"bubble_user_top": Color("6e260c"),
		"bubble_user_bottom": Color("361205"),
		"bubble_npc_top": Color("541c08"),
		"bubble_npc_bottom": Color("2b0e04"),
	},
	{
		"id": "solar_gold",
		"name": "Solar Gold",
		"category": "ROYGBIV",
		"roygbiv_letter": "Y",
		"description": "Radiant golden sunshine with rich antique bronze and warm amber undertones.",
		"accent": Color("facc15"),
		"ink": Color("fffdeb"),
		"muted": Color("fde047"),
		"bg_panel": Color(0.10, 0.08, 0.02, 0.98),
		"panel_border": Color("735805"),
		"frame_top": Color("664d03"),
		"frame_bottom": Color("261c01"),
		"button_normal_top": Color("473602"),
		"button_normal_bottom": Color("261d01"),
		"button_hover_top": Color("705503"),
		"button_hover_bottom": Color("3d2e02"),
		"button_pressed_top": Color("261d01"),
		"button_pressed_bottom": Color("473602"),
		"bevel": [Color("140f00"), Color("fef9c3"), Color("ca8a04"), Color("422006")],
		"tab_normal_top": Color("332601"),
		"tab_normal_bottom": Color("1f1701"),
		"tab_selected_top": Color("543f02"),
		"tab_selected_bottom": Color("332601"),
		"input_top": Color("261c01"),
		"input_bottom": Color("140e00"),
		"slider_grabber": Color("997405"),
		"slider_track": Color("332601"),
		"bubble_user_top": Color("594402"),
		"bubble_user_bottom": Color("2e2201"),
		"bubble_npc_top": Color("473602"),
		"bubble_npc_bottom": Color("241a01"),
	},
	{
		"id": "emerald_green",
		"name": "Emerald Jade",
		"category": "ROYGBIV",
		"roygbiv_letter": "G",
		"description": "Lush botanical jade and deep pine forest with luminous mint accents.",
		"accent": Color("4ade80"),
		"ink": Color("f0fdf4"),
		"muted": Color("86efac"),
		"bg_panel": Color(0.04, 0.10, 0.06, 0.98),
		"panel_border": Color("1c6e3b"),
		"frame_top": Color("14532d"),
		"frame_bottom": Color("052010"),
		"button_normal_top": Color("124727"),
		"button_normal_bottom": Color("092614"),
		"button_hover_top": Color("166534"),
		"button_hover_bottom": Color("0f3d20"),
		"button_pressed_top": Color("092614"),
		"button_pressed_bottom": Color("124727"),
		"bevel": [Color("020f07"), Color("dcfce7"), Color("16a34a"), Color("052e16")],
		"tab_normal_top": Color("0e381f"),
		"tab_normal_bottom": Color("072111"),
		"tab_selected_top": Color("165730"),
		"tab_selected_bottom": Color("0e381f"),
		"input_top": Color("072412"),
		"input_bottom": Color("031209"),
		"slider_grabber": Color("1e7e43"),
		"slider_track": Color("0e381f"),
		"bubble_user_top": Color("165931"),
		"bubble_user_bottom": Color("0b2b18"),
		"bubble_npc_top": Color("114526"),
		"bubble_npc_bottom": Color("082112"),
	},
	{
		"id": "cobalt_blue",
		"name": "Classic Cobalt",
		"category": "ROYGBIV",
		"roygbiv_letter": "B",
		"description": "The original nautical cobalt gradient with silver bevels and crisp azure accents.",
		"accent": Color("e2eaff"),
		"ink": Color("fff9e8"),
		"muted": Color("bbc9ed"),
		"bg_panel": Color(0.055, 0.078, 0.10, 0.98),
		"panel_border": Color("41515d"),
		"frame_top": Color("253f9b"),
		"frame_bottom": Color("090f42"),
		"button_normal_top": Color("283f88"),
		"button_normal_bottom": Color("142154"),
		"button_hover_top": Color("4161b8"),
		"button_hover_bottom": Color("233b80"),
		"button_pressed_top": Color("142154"),
		"button_pressed_bottom": Color("283f88"),
		"bevel": [Color("101735"), Color("edf2ff"), Color("9daed5"), Color("3c5185")],
		"tab_normal_top": Color("172654"),
		"tab_normal_bottom": Color("101b48"),
		"tab_selected_top": Color("2c458e"),
		"tab_selected_bottom": Color("101b48"),
		"input_top": Color("111e57"),
		"input_bottom": Color("080f31"),
		"slider_grabber": Color("8b7253"),
		"slider_track": Color("31414a"),
		"bubble_user_top": Color("243e90"),
		"bubble_user_bottom": Color("101b50"),
		"bubble_npc_top": Color("263c9c"),
		"bubble_npc_bottom": Color("101b50"),
	},
	{
		"id": "deep_indigo",
		"name": "Midnight Indigo",
		"category": "ROYGBIV",
		"roygbiv_letter": "I",
		"description": "Deep nocturnal abyss and celestial twilight with electric periwinkle glow.",
		"accent": Color("818cf8"),
		"ink": Color("f5f3ff"),
		"muted": Color("c7d2fe"),
		"bg_panel": Color(0.06, 0.05, 0.12, 0.98),
		"panel_border": Color("3c387d"),
		"frame_top": Color("312e81"),
		"frame_bottom": Color("0f0c3d"),
		"button_normal_top": Color("2b2670"),
		"button_normal_bottom": Color("141142"),
		"button_hover_top": Color("4338ca"),
		"button_hover_bottom": Color("241f69"),
		"button_pressed_top": Color("141142"),
		"button_pressed_bottom": Color("2b2670"),
		"bevel": [Color("090724"), Color("e0e7ff"), Color("4f46e5"), Color("1e1b4b")],
		"tab_normal_top": Color("1e1a52"),
		"tab_normal_bottom": Color("110e3b"),
		"tab_selected_top": Color("3730a3"),
		"tab_selected_bottom": Color("1e1a52"),
		"input_top": Color("141142"),
		"input_bottom": Color("0a0826"),
		"slider_grabber": Color("4f46e5"),
		"slider_track": Color("1e1a52"),
		"bubble_user_top": Color("3730a3"),
		"bubble_user_bottom": Color("17134d"),
		"bubble_npc_top": Color("2d277d"),
		"bubble_npc_bottom": Color("120f3d"),
	},
	{
		"id": "amethyst_violet",
		"name": "Amethyst Violet",
		"category": "ROYGBIV",
		"roygbiv_letter": "V",
		"description": "Velvety imperial plum and crystalline amethyst with royal orchid radiance.",
		"accent": Color("c084fc"),
		"ink": Color("faf5ff"),
		"muted": Color("e9d5ff"),
		"bg_panel": Color(0.09, 0.04, 0.12, 0.98),
		"panel_border": Color("5a217d"),
		"frame_top": Color("581c87"),
		"frame_bottom": Color("1e0533"),
		"button_normal_top": Color("471370"),
		"button_normal_bottom": Color("210638"),
		"button_hover_top": Color("6b21a8"),
		"button_hover_bottom": Color("3b0d5e"),
		"button_pressed_top": Color("210638"),
		"button_pressed_bottom": Color("471370"),
		"bevel": [Color("120221"), Color("f3e8ff"), Color("9333ea"), Color("3b0764")],
		"tab_normal_top": Color("2e0b4a"),
		"tab_normal_bottom": Color("1b042e"),
		"tab_selected_top": Color("581c87"),
		"tab_selected_bottom": Color("2e0b4a"),
		"input_top": Color("210638"),
		"input_bottom": Color("10021c"),
		"slider_grabber": Color("7e22ce"),
		"slider_track": Color("2e0b4a"),
		"bubble_user_top": Color("5b188c"),
		"bubble_user_bottom": Color("28083e"),
		"bubble_npc_top": Color("48136e"),
		"bubble_npc_bottom": Color("1e062e"),
	},
	# --- Popular Themes ---
	{
		"id": "cyberpunk_neon",
		"name": "Cyberpunk Neon",
		"category": "Popular",
		"roygbiv_letter": "",
		"description": "High-contrast dark synth aesthetic with electric hot magenta and cyber cyan.",
		"accent": Color("ff007f"),
		"ink": Color("ffffff"),
		"muted": Color("00f0ff"),
		"bg_panel": Color(0.06, 0.02, 0.08, 0.98),
		"panel_border": Color("70104e"),
		"frame_top": Color("5e073c"),
		"frame_bottom": Color("14021f"),
		"button_normal_top": Color("47052c"),
		"button_normal_bottom": Color("1f021e"),
		"button_hover_top": Color("850954"),
		"button_hover_bottom": Color("3b0429"),
		"button_pressed_top": Color("1f021e"),
		"button_pressed_bottom": Color("47052c"),
		"bevel": [Color("0d0114"), Color("ff77c6"), Color("00e5ff"), Color("360420")],
		"tab_normal_top": Color("2e0322"),
		"tab_normal_bottom": Color("1a0219"),
		"tab_selected_top": Color("540636"),
		"tab_selected_bottom": Color("2e0322"),
		"input_top": Color("1c021c"),
		"input_bottom": Color("0e010e"),
		"slider_grabber": Color("ff007f"),
		"slider_track": Color("2e0322"),
		"bubble_user_top": Color("63083e"),
		"bubble_user_bottom": Color("24031d"),
		"bubble_npc_top": Color("4d0630"),
		"bubble_npc_bottom": Color("1a0215"),
	},
	{
		"id": "obsidian_slate",
		"name": "Obsidian Monochrome",
		"category": "Popular",
		"roygbiv_letter": "",
		"description": "Minimalist stealth dark theme with charcoal glass and pure titanium highlights.",
		"accent": Color("f8fafc"),
		"ink": Color("ffffff"),
		"muted": Color("94a3b8"),
		"bg_panel": Color(0.04, 0.04, 0.05, 0.98),
		"panel_border": Color("383842"),
		"frame_top": Color("26262b"),
		"frame_bottom": Color("0d0d10"),
		"button_normal_top": Color("222226"),
		"button_normal_bottom": Color("121215"),
		"button_hover_top": Color("383840"),
		"button_hover_bottom": Color("202025"),
		"button_pressed_top": Color("121215"),
		"button_pressed_bottom": Color("222226"),
		"bevel": [Color("060608"), Color("e2e8f0"), Color("64748b"), Color("1a1a1f")],
		"tab_normal_top": Color("1a1a1e"),
		"tab_normal_bottom": Color("0f0f12"),
		"tab_selected_top": Color("2e2e36"),
		"tab_selected_bottom": Color("1a1a1e"),
		"input_top": Color("141417"),
		"input_bottom": Color("0a0a0d"),
		"slider_grabber": Color("94a3b8"),
		"slider_track": Color("222228"),
		"bubble_user_top": Color("2b2b30"),
		"bubble_user_bottom": Color("141417"),
		"bubble_npc_top": Color("212126"),
		"bubble_npc_bottom": Color("101013"),
	},
	{
		"id": "sakura_blush",
		"name": "Sakura Quartz",
		"category": "Popular",
		"roygbiv_letter": "",
		"description": "Elegant cherry blossom blush, warm quartz rose, and delicate pastel contrast.",
		"accent": Color("fb7185"),
		"ink": Color("fff5f6"),
		"muted": Color("fca5a5"),
		"bg_panel": Color(0.10, 0.04, 0.06, 0.98),
		"panel_border": Color("692537"),
		"frame_top": Color("662235"),
		"frame_bottom": Color("260b13"),
		"button_normal_top": Color("471624"),
		"button_normal_bottom": Color("210810"),
		"button_hover_top": Color("732239"),
		"button_hover_bottom": Color("3d111e"),
		"button_pressed_top": Color("210810"),
		"button_pressed_bottom": Color("471624"),
		"bevel": [Color("14040a"), Color("ffe4e6"), Color("f43f5e"), Color("3b0c1b")],
		"tab_normal_top": Color("2e0d17"),
		"tab_normal_bottom": Color("1a060d"),
		"tab_selected_top": Color("521829"),
		"tab_selected_bottom": Color("2e0d17"),
		"input_top": Color("210810"),
		"input_bottom": Color("120308"),
		"slider_grabber": Color("e11d48"),
		"slider_track": Color("2e0d17"),
		"bubble_user_top": Color("591c2c"),
		"bubble_user_bottom": Color("290b14"),
		"bubble_npc_top": Color("421420"),
		"bubble_npc_bottom": Color("1e080f"),
	},
	{
		"id": "nord_frost",
		"name": "Arctic Frost",
		"category": "Popular",
		"roygbiv_letter": "",
		"description": "Scandinavian polar night slate with crisp glacial ice cyan highlights.",
		"accent": Color("7dd3fc"),
		"ink": Color("f0f9ff"),
		"muted": Color("94a3b8"),
		"bg_panel": Color(0.05, 0.07, 0.10, 0.98),
		"panel_border": Color("28394e"),
		"frame_top": Color("1e293b"),
		"frame_bottom": Color("090d14"),
		"button_normal_top": Color("1b263b"),
		"button_normal_bottom": Color("0e1624"),
		"button_hover_top": Color("293954"),
		"button_hover_bottom": Color("172236"),
		"button_pressed_top": Color("0e1624"),
		"button_pressed_bottom": Color("1b263b"),
		"bevel": [Color("06090e"), Color("e0f2fe"), Color("38bdf8"), Color("131c2b")],
		"tab_normal_top": Color("141e2e"),
		"tab_normal_bottom": Color("0b101a"),
		"tab_selected_top": Color("24334a"),
		"tab_selected_bottom": Color("141e2e"),
		"input_top": Color("0e1521"),
		"input_bottom": Color("070a10"),
		"slider_grabber": Color("0284c7"),
		"slider_track": Color("141e2e"),
		"bubble_user_top": Color("213047"),
		"bubble_user_bottom": Color("0d1521"),
		"bubble_npc_top": Color("182436"),
		"bubble_npc_bottom": Color("0a101a"),
	},
	{
		"id": "vaporwave_synth",
		"name": "Sunset Synth",
		"category": "Popular",
		"roygbiv_letter": "",
		"description": "Retro-futuristic dusk with deep purple shadow, sunset gold, and neon pink.",
		"accent": Color("f472b6"),
		"ink": Color("fef08a"),
		"muted": Color("c084fc"),
		"bg_panel": Color(0.07, 0.03, 0.11, 0.98),
		"panel_border": Color("5c1f7a"),
		"frame_top": Color("581c87"),
		"frame_bottom": Color("190b2b"),
		"button_normal_top": Color("431669"),
		"button_normal_bottom": Color("1f0a33"),
		"button_hover_top": Color("6d1e9e"),
		"button_hover_bottom": Color("371057"),
		"button_pressed_top": Color("1f0a33"),
		"button_pressed_bottom": Color("431669"),
		"bevel": [Color("0e0417"), Color("fdf4ff"), Color("db2777"), Color("350b52")],
		"tab_normal_top": Color("2b0c47"),
		"tab_normal_bottom": Color("170626"),
		"tab_selected_top": Color("4f167a"),
		"tab_selected_bottom": Color("2b0c47"),
		"input_top": Color("1f0a33"),
		"input_bottom": Color("0f041a"),
		"slider_grabber": Color("ec4899"),
		"slider_track": Color("2b0c47"),
		"bubble_user_top": Color("52197d"),
		"bubble_user_bottom": Color("240b38"),
		"bubble_npc_top": Color("3d125e"),
		"bubble_npc_bottom": Color("1c082b"),
	},
]

static var _themes_by_id: Dictionary = {}
static var _frame_textures: Dictionary = {}
static var _active_theme_id: String = ""
static var _initialized: bool = false
static var _callbacks: Array[Callable] = []

static func _build_index() -> void:
	if _themes_by_id.is_empty():
		for t in THEMES:
			_themes_by_id[t.id] = t

static func get_all_themes() -> Array[Dictionary]:
	return THEMES

static func get_theme(id: String) -> Dictionary:
	_build_index()
	if _themes_by_id.has(id):
		return _themes_by_id[id]
	return THEMES[4] # Default cobalt_blue

static func get_current_id() -> String:
	if not _initialized:
		_init_theme()
	return _active_theme_id

static func get_current() -> Dictionary:
	return get_theme(get_current_id())

static func _init_theme() -> void:
	_build_index()
	_initialized = true
	var saved := _load_preference()
	if not saved.is_empty() and _themes_by_id.has(saved):
		_active_theme_id = saved
	else:
		_active_theme_id = "cobalt_blue"

static func set_theme(id: String, save: bool = true) -> void:
	_build_index()
	if not _themes_by_id.has(id):
		return
	_active_theme_id = id
	_initialized = true
	if save:
		_save_preference(id)
	var data := get_theme(id)
	for cb in _callbacks:
		if cb.is_valid():
			cb.call(id, data)

static func cycle_theme(direction: int = 1) -> Dictionary:
	var current := get_current_id()
	var index := -1
	for i in THEMES.size():
		if THEMES[i].id == current:
			index = i
			break
	if index == -1:
		index = 4
	var next_index := posmod(index + direction, THEMES.size())
	var next_theme: Dictionary = THEMES[next_index]
	set_theme(next_theme.id)
	return next_theme

static func add_theme_listener(callback: Callable) -> void:
	if not _callbacks.has(callback):
		_callbacks.append(callback)

static func remove_theme_listener(callback: Callable) -> void:
	_callbacks.erase(callback)

static func _save_preference(theme_id: String) -> void:
	var path := ProjectSettings.globalize_path(PREFERENCE_PATH)
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"theme": theme_id}, "  "))
		file.close()

static func _load_preference() -> String:
	var path := ProjectSettings.globalize_path(PREFERENCE_PATH)
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("theme"):
		return str(parsed.theme)
	return ""

## Nine-patch beveled textured frame for dialogue, menus, and sheets.
static func get_dialogue_box(top: Color, bottom: Color, padding: int = 18, bevel: Array = []) -> StyleBoxTexture:
	var b: Array = bevel if bevel.size() >= 4 else [Color("101735"), Color("edf2ff"), Color("9daed5"), Color("3c5185")]
	var key := "%s_%s_%s_%s_%s_%s" % [top.to_html(), bottom.to_html(), b[0].to_html(), b[1].to_html(), b[2].to_html(), b[3].to_html()]
	if not _frame_textures.has(key):
		var pixels := Image.create(64, 256, false, Image.FORMAT_RGBA8)
		for y in 256:
			for x in 64:
				var edge := mini(mini(x, 63 - x), mini(y, 255 - y))
				pixels.set_pixel(x, y, b[edge] if edge < 4 else top.lerp(bottom, float(y - 4) / 247.0))
		_frame_textures[key] = ImageTexture.create_from_image(pixels)
	var style := StyleBoxTexture.new()
	style.texture = _frame_textures[key]
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 4)
		style.set_content_margin(side, padding)
	return style

## Flat rounded box helper
static func flat_box(color: Color, border: Color = Color.TRANSPARENT, radius: int = 8, padding: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1 if border != Color.TRANSPARENT else 0)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = maxi(padding - 4, 4)
	box.content_margin_bottom = maxi(padding - 4, 4)
	return box

## Message bubble style
static func get_bubble_style(role: String, theme_data: Dictionary = {}, padding: int = 14) -> StyleBoxTexture:
	var t := theme_data if not theme_data.is_empty() else get_current()
	var top: Color = t.bubble_user_top if role == "user" else t.bubble_npc_top
	var bottom: Color = t.bubble_user_bottom if role == "user" else t.bubble_npc_bottom
	return get_dialogue_box(top, bottom, padding, t.bevel)

## Constructs Godot Theme for CharacterDialogueUI and AISettingsUI
static func make_dialogue_theme(theme_data: Dictionary = {}) -> Theme:
	var t := theme_data if not theme_data.is_empty() else get_current()
	var result := Theme.new()
	result.default_font_size = 17
	for type_name in ["Label", "Button", "OptionButton", "LineEdit", "TextEdit", "PopupMenu"]:
		result.set_color("font_color", type_name, t.ink)
		result.set_color("font_hover_color", type_name, t.ink)
		result.set_color("font_pressed_color", type_name, t.ink)
		result.set_color("font_focus_color", type_name, t.ink)
		result.set_color("font_disabled_color", type_name, t.muted.darkened(0.25))
	result.set_color("font_shadow_color", "Label", t.frame_bottom.darkened(0.5))
	result.set_constant("shadow_offset_x", "Label", 1)
	result.set_constant("shadow_offset_y", "Label", 2)
	for type_name in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type_name, get_dialogue_box(t.button_normal_top, t.button_normal_bottom, 12, t.bevel))
		result.set_stylebox("hover", type_name, get_dialogue_box(t.button_hover_top, t.button_hover_bottom, 12, t.bevel))
		result.set_stylebox("pressed", type_name, get_dialogue_box(t.button_pressed_top, t.button_pressed_bottom, 12, t.bevel))
		result.set_stylebox("disabled", type_name, get_dialogue_box(t.button_normal_top.darkened(0.35), t.button_normal_bottom.darkened(0.35), 12, t.bevel))
		var focus := flat_box(Color(0, 0, 0, 0), t.accent, 0, 12)
		focus.set_border_width_all(2)
		result.set_stylebox("focus", type_name, focus)
	for type_name in ["LineEdit", "TextEdit"]:
		result.set_stylebox("normal", type_name, get_dialogue_box(t.input_top, t.input_bottom, 12, t.bevel))
		var focus := flat_box(Color(0, 0, 0, 0), t.accent, 0, 12)
		focus.set_border_width_all(2)
		result.set_stylebox("focus", type_name, focus)
		result.set_color("caret_color", type_name, t.ink)
		result.set_color("font_placeholder_color", type_name, t.muted)
		result.set_color("selection_color", type_name, t.accent.darkened(0.3))
	result.set_stylebox("panel", "TabContainer", get_dialogue_box(t.tab_normal_bottom, t.frame_bottom, 12, t.bevel))
	result.set_stylebox("panel", "PopupMenu", get_dialogue_box(t.frame_top, t.frame_bottom, 12, t.bevel))
	for state in ["tab_selected", "tab_unselected", "tab_hovered"]:
		var top_col: Color = t.tab_selected_top if state == "tab_selected" else (t.button_hover_top if state == "tab_hovered" else t.tab_normal_top)
		var bot_col: Color = t.tab_selected_bottom if state == "tab_selected" else t.tab_normal_bottom
		result.set_stylebox(state, "TabContainer", get_dialogue_box(top_col, bot_col, 10, t.bevel))
	result.set_color("font_selected_color", "TabContainer", t.accent)
	result.set_color("font_unselected_color", "TabContainer", t.muted)
	return result

## Constructs Godot Theme for VisualLab
static func make_visual_lab_theme(theme_data: Dictionary = {}) -> Theme:
	var t := theme_data if not theme_data.is_empty() else get_current()
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Inter", "Noto Sans", "DejaVu Sans"])
	theme.default_font = font
	theme.default_font_size = 14
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, flat_box(t.button_normal_bottom.lerp(t.bg_panel, 0.45), t.panel_border.darkened(0.2), 8, 12))
		theme.set_stylebox("hover", type, flat_box(t.button_hover_bottom.lerp(t.bg_panel, 0.2), t.accent, 8, 12))
		theme.set_stylebox("pressed", type, flat_box(t.button_pressed_bottom, t.accent, 8, 12))
		theme.set_stylebox("focus", type, flat_box(Color(0, 0, 0, 0), t.accent, 8, 12))
		theme.set_color("font_color", type, t.ink)
	theme.set_stylebox("panel", "PanelContainer", flat_box(t.bg_panel, t.panel_border, 14, 12))
	theme.set_stylebox("panel", "PopupMenu", flat_box(t.frame_bottom, t.panel_border, 8, 10))
	theme.set_color("font_color", "PopupMenu", t.ink)
	theme.set_stylebox("hover", "PopupMenu", flat_box(t.button_hover_bottom, Color.TRANSPARENT, 6, 8))
	for type in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", type, flat_box(t.input_bottom, t.panel_border.darkened(0.2), 8, 10))
		theme.set_color("font_color", type, t.ink)
		theme.set_stylebox("focus", type, flat_box(t.input_bottom.lightened(0.04), t.accent, 8, 10))
	theme.set_stylebox("panel", "TabContainer", flat_box(t.frame_bottom, t.panel_border.darkened(0.3), 8, 10))
	theme.set_stylebox("tab_selected", "TabContainer", flat_box(t.tab_selected_bottom, t.accent, 5, 8))
	theme.set_stylebox("tab_unselected", "TabContainer", flat_box(t.tab_normal_bottom, Color.TRANSPARENT, 5, 8))
	theme.set_stylebox("tab_hovered", "TabContainer", flat_box(t.button_hover_bottom, t.panel_border.lightened(0.2), 5, 8))
	theme.set_color("font_selected_color", "TabContainer", t.accent)
	theme.set_color("font_unselected_color", "TabContainer", t.muted)
	theme.set_font_size("font_size", "TabContainer", 12)
	var track := flat_box(t.slider_track, Color.TRANSPARENT, 4, 2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", flat_box(t.slider_grabber, Color.TRANSPARENT, 4, 2))
	theme.set_stylebox("grabber_area_highlight", "HSlider", flat_box(t.accent, Color.TRANSPARENT, 4, 2))
	return theme
