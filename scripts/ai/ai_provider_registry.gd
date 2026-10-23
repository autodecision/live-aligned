class_name AIProviderRegistry
extends RefCounted
## Hermes-style registry / profile / transport separation, implemented natively for Godot.
## No CLI dependency, environment import, fixed encryption key, or persisted credentials.

const SETTINGS_PATH := "user://ai/model_settings.json"
const MAX_SETTINGS_BYTES := 262144
const PROFILE_FIELDS := ["id", "name", "provider_id", "model", "base_url", "transport", "auth_mode", "max_output_tokens", "timeout_seconds", "oauth_client_id", "oauth_device_url", "oauth_token_url", "oauth_scope"]
const TRANSPORTS := ["responses", "chat_completions", "anthropic_messages"]

static func list_providers() -> Array[Dictionary]:
	return [
		_row("openai", "OpenAI", "https://api.openai.com/v1", "responses"),
		_row("anthropic", "Anthropic", "https://api.anthropic.com/v1", "anthropic_messages"),
		_row("google", "Google AI Studio", "https://generativelanguage.googleapis.com/v1beta/openai", "chat_completions"),
		_row("openrouter", "OpenRouter", "https://openrouter.ai/api/v1", "chat_completions"),
		_row("deepseek", "DeepSeek", "https://api.deepseek.com/v1", "chat_completions"),
		_row("groq", "Groq", "https://api.groq.com/openai/v1", "chat_completions"),
		_row("mistral", "Mistral", "https://api.mistral.ai/v1", "chat_completions"),
		_row("nous", "Nous Portal", "https://inference-api.nousresearch.com/v1", "chat_completions"),
		_row("ollama", "Ollama (local server)", "http://127.0.0.1:11434/v1", "chat_completions", true),
		_row("lmstudio", "LM Studio (local server)", "http://127.0.0.1:1234/v1", "chat_completions", true),
		_row("custom", "Custom compatible endpoint", "", "chat_completions", true),
	]

static func _row(id: String, title: String, url: String, transport: String, optional_key: bool = false) -> Dictionary:
	var modes := ["api_key", "none", "oauth_device"] if id == "custom" else (["api_key", "none"] if optional_key else ["api_key"])
	if id == "nous" and OS.get_name() in ["Linux", "macOS", "Windows"]:
		modes.append("hermes_session")
	return {"id": id, "name": title, "base_url": url, "transport": transport,
		"auth_modes": modes,
		"available": true, "oauth_available": id == "custom",
		"oauth_note": "Device sign-in requires your own registered public OAuth client and a provider-supported inference grant.",
		"key_optional": optional_key, "supports_model_discovery": true}

static func provider(provider_id: String) -> Dictionary:
	for row in list_providers():
		if row.id == provider_id:
			return row
	return {}

static func default_profile(provider_id: String = "openai") -> Dictionary:
	var entry := provider(provider_id)
	return {"id": "default", "name": "My model", "provider_id": provider_id,
		"model": "", "base_url": entry.get("base_url", ""),
		"transport": entry.get("transport", "chat_completions"),
		"auth_mode": "none" if entry.get("key_optional", false) else "api_key",
		"max_output_tokens": 512, "timeout_seconds": 60}

static func default_settings() -> Dictionary:
	return {"version": 1, "default_profile_id": "default", "character_profiles": {}, "profiles": [default_profile()], "memory_limits": sanitize_memory_limits({})}

static func sanitize_memory_limits(raw: Variant) -> Dictionary:
	var limits: Dictionary = raw if raw is Dictionary else {}
	var global_bytes := bounded_int(limits.get("global_bytes"), 128 * 1048576, 8192, 2 * 1073741824)
	var context_chars := bounded_int(limits.get("context_chars"), 18000, 0, 64000)
	return {"global_bytes": global_bytes,
		"character_bytes": bounded_int(limits.get("character_bytes"), mini(1048576, global_bytes / 2), 2048, mini(1048576, global_bytes / 2)),
		"max_characters": bounded_int(limits.get("max_characters"), 512, 1, 512),
		"recent_turns": bounded_int(limits.get("recent_turns"), 12, 1, 64),
		"recall_entries": bounded_int(limits.get("recall_entries"), 512, 8, 512),
		"message_chars": bounded_int(limits.get("message_chars"), 6000, 256, 16000),
		"context_chars": context_chars,
		"recall_chars": bounded_int(limits.get("recall_chars"), mini(4800, context_chars / 3), 0, context_chars / 3),
		"recall_results": bounded_int(limits.get("recall_results"), 6, 1, 12)}

static func validate_profile(profile: Dictionary, require_model: bool = true) -> Dictionary:
	if str(profile.get("id", "")).is_empty():
		return _error("A model profile ID is required.")
	var entry := provider(str(profile.get("provider_id", "")))
	if entry.is_empty():
		return _error("Choose a supported provider or Custom compatible endpoint.")
	if not str(profile.get("auth_mode", "api_key")) in entry.auth_modes:
		return _error("This authentication method is unavailable for the selected provider.")
	if not str(profile.get("transport", entry.transport)) in TRANSPORTS:
		return _error("Choose Responses, Chat Completions, or Anthropic Messages transport.")
	var endpoint := validate_endpoint(str(profile.get("base_url", entry.base_url)))
	if not endpoint.ok:
		return endpoint
	if profile.get("auth_mode", "") == "hermes_session" and (str(profile.get("base_url", "")).trim_suffix("/") != "https://inference-api.nousresearch.com/v1" or profile.get("transport", "") != "chat_completions"):
		return _error("Hermes sessions can only be used with the built-in Nous inference endpoint and Chat Completions transport.")
	if profile.get("auth_mode", "") == "oauth_device":
		if str(profile.get("oauth_client_id", "")).strip_edges().is_empty():
			return _error("Device sign-in needs your registered public OAuth client ID.")
		for field in ["oauth_device_url", "oauth_token_url"]:
			var url := str(profile.get(field, ""))
			if not url.begins_with("https://") or not validate_endpoint(url).ok:
				return _error("Device sign-in requires HTTPS device authorization and token endpoints.")
	if require_model and str(profile.get("model", "")).strip_edges().is_empty():
		return _error("Choose a model or enter its exact model ID.")
	if str(profile.get("model", "")).length() > 256:
		return _error("The model ID is too long.")
	return {"ok": true}

static func bounded_int(value: Variant, fallback: int, minimum: int, maximum: int) -> int:
	# Config files are untrusted JSON: int(Dictionary/Array/null) produces runtime errors.
	if value is int:
		return clampi(value, minimum, maximum)
	if value is float:
		return clampi(int(clampf(value, float(minimum), float(maximum))), minimum, maximum) if is_finite(value) else fallback
	if value is String and value.is_valid_int():
		return clampi(value.to_int(), minimum, maximum)
	return fallback

static func validate_verification_url(url: String) -> Dictionary:
	# The browser verification URL may legitimately carry an opaque query.
	if url.length() > 4096 or not url.begins_with("https://") or url.contains("#"):
		return _error("Use an HTTPS verification URL.")
	for index in range(url.length()):
		if url.unicode_at(index) <= 32 or url.unicode_at(index) == 127:
			return _error("Verification URLs cannot contain control characters or spaces.")
	return validate_endpoint(url.split("?", true, 1)[0])

static func validate_endpoint(url: String) -> Dictionary:
	if url.is_empty() or url.length() > 2048 or url.contains("\n") or url.contains("\r"):
		return _error("Enter a valid API base URL.")
	for index in range(url.length()):
		if url.unicode_at(index) <= 32 or url.unicode_at(index) == 127:
			return _error("API URLs cannot contain control characters or spaces.")
	if url.contains("@") or url.contains("?") or url.contains("#") or url.contains(" "):
		return _error("API base URLs cannot include credentials, queries, fragments, or spaces.")
	var parser := RegEx.new()
	parser.compile("^https?://(\\[[0-9a-fA-F:]+\\]|[a-zA-Z0-9.-]+)(:[0-9]{1,5})?(/[^\\s]*)?$")
	if parser.search(url) == null:
		return _error("Use an HTTPS API base URL, including the API version path.")
	var authority := url.split("://", true, 1)[1].split("/")[0]
	var port_text := authority.substr(authority.find("]") + 1).trim_prefix(":") if authority.begins_with("[") else (authority.split(":")[1] if authority.contains(":") else "")
	if not port_text.is_empty() and (port_text.to_int() < 1 or port_text.to_int() > 65535):
		return _error("API URL port must be between 1 and 65535.")
	if url.begins_with("http://"):
		var host := url.trim_prefix("http://").split("/")[0].split(":")[0]
		var local := host == "localhost" or host == "127.0.0.1" or url.begins_with("http://[::1]")
		if not local:
			return _error("Remote endpoints require HTTPS. Plain HTTP is allowed only on this device's loopback address.")
	return {"ok": true}

static func load_settings(path: String = SETTINGS_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return default_settings()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_SETTINGS_BYTES:
		return default_settings()
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return default_settings()
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return default_settings()
	return sanitize_settings(parsed)

static func sanitize_settings(settings: Dictionary) -> Dictionary:
	var profiles: Array[Dictionary] = []
	var seen: Dictionary = {}
	var rows: Variant = settings.get("profiles", [])
	if rows is Array:
		for raw in rows.slice(0, 32):
			if not raw is Dictionary:
				continue
			var clean: Dictionary = {}
			for field in PROFILE_FIELDS:
				if raw.has(field):
					clean[field] = raw[field]
			var identifier := str(clean.get("id", "")).substr(0, 128)
			if identifier.is_empty() or seen.has(identifier):
				continue
			clean["id"] = identifier
			if not clean.has("name") and raw.has("label"):
				clean.name = str(raw.label)
			for field in ["name", "provider_id", "model", "base_url", "transport", "auth_mode", "oauth_client_id", "oauth_device_url", "oauth_token_url", "oauth_scope"]:
				clean[field] = str(clean.get(field, default_profile().get(field, ""))).substr(0, 2048)
			# Never persist credentials embedded in a URL either.
			if not validate_endpoint(clean.base_url).ok:
				clean.base_url = str(provider(clean.provider_id).get("base_url", ""))
			for field in ["oauth_device_url", "oauth_token_url"]:
				if not str(clean[field]).is_empty() and (not str(clean[field]).begins_with("https://") or not validate_endpoint(str(clean[field])).ok):
					clean[field] = ""
			clean.max_output_tokens = bounded_int(clean.get("max_output_tokens", 512), 512, 64, 8192)
			clean.timeout_seconds = bounded_int(clean.get("timeout_seconds", 60), 60, 5, 180)
			profiles.append(clean)
			seen[identifier] = true
	if profiles.is_empty():
		var defaults := default_settings()
		defaults.memory_limits = sanitize_memory_limits(settings.get("memory_limits", {}))
		return defaults
	var active := str(settings.get("default_profile_id", settings.get("active_profile_id", profiles[0].id)))
	if not seen.has(active):
		active = profiles[0].id
	var assignments: Dictionary = {}
	var raw_assignments: Variant = settings.get("character_profiles", {})
	if raw_assignments is Dictionary:
		for character_id in raw_assignments.keys().slice(0, 256):
			var profile_id := str(raw_assignments[character_id])
			if seen.has(profile_id):
				assignments[str(character_id).substr(0, 128)] = profile_id
	return {"version": 1, "default_profile_id": active, "character_profiles": assignments, "profiles": profiles, "memory_limits": sanitize_memory_limits(settings.get("memory_limits", {}))}

static func save_settings(settings: Dictionary, path: String = SETTINGS_PATH) -> Dictionary:
	var clean := sanitize_settings(settings)
	var encoded := JSON.stringify(clean, "\t")
	if encoded.to_utf8_buffer().size() > MAX_SETTINGS_BYTES:
		return _error("Model settings exceed the storage size limit. Remove unused profiles or shorten their fields.")
	var folder := ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return _error("Could not create the model settings folder.")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return _error("Could not save model settings.")
	file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
		return _error("Could not finish writing model settings. Check available storage.")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		return _error("Could not replace model settings.")
	return {"ok": true, "settings": clean}

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "error_code": "configuration"}
