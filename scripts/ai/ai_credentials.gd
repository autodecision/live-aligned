class_name AICredentials
extends RefCounted
## Session-only credentials. Optional explicit desktop Nous import reads only
## the current Hermes access token; it never refreshes or writes the shared store.
## Mobile Keychain/Keystore integration can replace this API without changing callers.

static var _secrets: Dictionary = {}
static var _oauth: Dictionary = {}
static var _bindings: Dictionary = {}

static func profile_binding(profile: Dictionary) -> String:
	var parts: Array[String] = []
	for field in ["id", "provider_id", "base_url", "transport", "auth_mode", "oauth_client_id", "oauth_device_url", "oauth_token_url", "oauth_scope"]:
		var value := str(profile.get(field, ""))
		parts.append(value.trim_suffix("/") if field == "base_url" else value)
	return JSON.stringify(parts).sha256_text()

static func bind_profile(profile: Dictionary) -> void:
	var id := str(profile.get("id", ""))
	var binding := profile_binding(profile)
	if _bindings.get(id, "") != binding:
		clear_secret(id)
	_bindings[id] = binding

static func matches_profile(profile: Dictionary) -> bool:
	return _bindings.get(str(profile.get("id", "")), "") == profile_binding(profile)

static func set_secret(profile_id: String, secret: String) -> void:
	if secret.is_empty():
		clear_secret(profile_id)
	else:
		_secrets[profile_id] = secret.strip_edges()
		_oauth.erase(profile_id)

static func get_secret(profile_id: String) -> String:
	return str(_secrets.get(profile_id, ""))

static func has_secret(profile_id: String) -> bool:
	return not get_secret(profile_id).is_empty()

static func clear_secret(profile_id: String) -> void:
	_secrets.erase(profile_id)
	_oauth.erase(profile_id)

static func set_oauth(profile_id: String, tokens: Dictionary) -> void:
	_oauth[profile_id] = tokens.duplicate(true)
	_secrets[profile_id] = str(tokens.get("access_token", ""))

static func get_oauth(profile_id: String) -> Dictionary:
	return _oauth.get(profile_id, {}).duplicate(true)

static func clear_all() -> void:
	_secrets.clear()
	_oauth.clear()
	_bindings.clear()

static func import_hermes_session(profile: Dictionary) -> Dictionary:
	if not OS.get_name() in ["Linux", "macOS", "Windows"]:
		return {"ok": false, "error": "Hermes session import is desktop only. Use an API key on mobile."}
	if not is_nous_session_profile(profile):
		return {"ok": false, "error": "Choose Nous Portal with Use Hermes session and the built-in inference URL."}
	var home_path := OS.get_environment("USERPROFILE") if OS.get_name() == "Windows" else OS.get_environment("HOME")
	if home_path.is_empty():
		return {"ok": false, "error": "Could not locate this desktop's home folder."}
	# Deliberately do not resolve CLI config, environment overrides, or run Hermes.
	var file := FileAccess.open(home_path.path_join(".hermes/auth.json"), FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return {"ok": false, "error": "No readable Hermes session. Sign in to Nous using Hermes, then import again."}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	return import_hermes_data(profile, parser.data if parse_error == OK else null)

static func is_nous_session_profile(profile: Dictionary) -> bool:
	return profile.get("provider_id", "") == "nous" and profile.get("auth_mode", "") == "hermes_session" and str(profile.get("base_url", "")).trim_suffix("/") == "https://inference-api.nousresearch.com/v1" and profile.get("transport", "") == "chat_completions"

static func import_hermes_data(profile: Dictionary, parsed: Variant) -> Dictionary:
	# Pure data entry point also allows QA against synthetic data, without real auth.
	if not is_nous_session_profile(profile):
		return {"ok": false, "error": "Hermes access tokens are restricted to the built-in Nous inference endpoint."}
	if not parsed is Dictionary or not parsed.get("providers") is Dictionary or not parsed.providers.get("nous") is Dictionary:
		return {"ok": false, "error": "No Nous session found. Sign in using Hermes, then import again."}
	var state: Dictionary = parsed.providers.nous
	var token := ""
	var expires_at := 0.0
	# Current Hermes may cache an inference agent_key separately from its
	# connectors/account access_token. Import only a cached inference-scoped JWT.
	for field in ["agent_key", "access_token"]:
		var candidate: Variant = state.get(field, "")
		if not candidate is String or candidate.is_empty() or candidate.length() > 32768 or candidate.contains("\n") or candidate.contains("\r"):
			continue
		var claims := _token_claims(candidate)
		var scopes := _scope_values(state.get("scope"))
		scopes.append_array(_scope_values(claims.get("scope")))
		scopes.append_array(_scope_values(claims.get("scp")))
		var expiry: Variant = claims.get("exp", 0)
		if not "inference:invoke" in scopes or not (expiry is float or expiry is int) or not is_finite(float(expiry)) or float(expiry) <= Time.get_unix_time_from_system() + 30:
			continue
		token = candidate
		expires_at = float(expiry)
		break
	if token.is_empty():
		return {"ok": false, "error": "Hermes has no unexpired inference-scoped Nous token. Refresh your Nous sign-in in Hermes, then import again. Account/connector tokens cannot run models."}
	bind_profile(profile)
	# Intentionally omit refresh_token and every other shared-store field.
	set_oauth(str(profile.id), {"access_token": token, "expires_at": expires_at, "binding": profile_binding(profile), "source": "hermes_session"})
	return {"ok": true}

static func _scope_values(value: Variant) -> Array[String]:
	var scopes: Array[String] = []
	if value is String:
		for part in value.replace(",", " ").replace("\t", " ").replace("\n", " ").split(" ", false):
			scopes.append(part)
	elif value is Array:
		for part in value:
			if part is String:
				scopes.append_array(_scope_values(part))
	return scopes

static func _token_claims(token: String) -> Dictionary:
	var pieces := token.split(".")
	if pieces.size() != 3:
		return {}
	var payload := pieces[1].replace("-", "+").replace("_", "/")
	while payload.length() % 4 != 0:
		payload += "="
	var parser := JSON.new()
	if parser.parse(Marshalls.base64_to_utf8(payload)) != OK:
		return {}
	var claims: Variant = parser.data
	return claims if claims is Dictionary else {}

static func persistence_description() -> String:
	return "Keys stay in memory for this session. Enter them again after restarting."
