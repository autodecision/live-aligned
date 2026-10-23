class_name AIProviderClient
extends Node
## Bounded, cancellable, native HTTP transports and optional public-client device OAuth.
## One operation per instance; callers may create independent clients for parallel work.

const Registry = preload("res://scripts/ai/ai_provider_registry.gd")
const Credentials = preload("res://scripts/ai/ai_credentials.gd")
const MAX_RESPONSE_BYTES := 2097152
const MAX_REQUEST_BYTES := 1048576
var _busy := false
var _epoch := 0
var _http: HTTPRequest
var _device: Dictionary = {}
static var _refreshing: Dictionary = {}

func _exit_tree() -> void:
	cancel()
	for binding in _refreshing.keys():
		if (_refreshing[binding] as WeakRef).get_ref() == self:
			_refreshing.erase(binding)

func cancel() -> void:
	_epoch += 1
	_device.clear()
	if is_instance_valid(_http):
		_http.cancel_request()

func is_busy() -> bool:
	return _busy

func fetch_models(profile: Dictionary) -> Dictionary:
	if _busy:
		return failure("busy", "A model request is already running.")
	var valid := Registry.validate_profile(profile, false)
	if not valid.ok:
		return valid
	_busy = true
	var epoch := _epoch
	var auth := await _headers(profile)
	var result: Dictionary = auth
	if auth.ok and epoch == _epoch:
		result = await _request(base_url(profile) + "/models", HTTPClient.METHOD_GET, auth.headers, "", timeout(profile))
		if result.ok:
			result = parse_models(result.data)
	_busy = false
	if epoch != _epoch:
		return failure("cancelled", "Request cancelled.")
	return result

func generate(profile: Dictionary, messages: Array) -> Dictionary:
	if _busy:
		return failure("busy", "A model request is already running.")
	var valid := Registry.validate_profile(profile)
	if not valid.ok:
		return valid
	var built := build_generation(profile, messages)
	if not built.ok:
		return built
	_busy = true
	var epoch := _epoch
	var auth := await _headers(profile)
	var result: Dictionary = auth
	if auth.ok and epoch == _epoch:
		result = await _request(base_url(profile) + built.path, HTTPClient.METHOD_POST, auth.headers, JSON.stringify(built.body), timeout(profile))
		if result.ok:
			result = parse_generation(str(profile.get("transport", "chat_completions")), result.data)
	_busy = false
	if epoch != _epoch:
		return failure("cancelled", "Request cancelled.")
	return result

func _headers(profile: Dictionary) -> Dictionary:
	Credentials.bind_profile(profile)
	var secret := Credentials.get_secret(str(profile.id))
	if profile.get("auth_mode", "") == "hermes_session":
		var imported := Credentials.get_oauth(str(profile.id))
		if not Credentials.is_nous_session_profile(profile) or float(imported.get("expires_at", 0)) <= Time.get_unix_time_from_system() + 5:
			Credentials.clear_secret(str(profile.id))
			return failure("authentication", "Import your current Nous session from Hermes. Sign in in Hermes again if it has expired.")
	if profile.get("auth_mode", "api_key") == "oauth_device":
		var refreshed := await _refresh_if_needed(profile)
		if not refreshed.ok:
			return refreshed
		secret = Credentials.get_secret(str(profile.id))
	if profile.get("auth_mode", "api_key") != "none" and secret.is_empty():
		return failure("authentication", "Enter an API key or sign in for this model profile.")
	if secret.length() > 32768 or secret.contains("\n") or secret.contains("\r"):
		return failure("authentication", "The credential contains an invalid newline.")
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if not secret.is_empty() and profile.get("auth_mode", "api_key") != "none":
		if profile.get("transport", "") == "anthropic_messages" and profile.get("auth_mode", "") != "oauth_device":
			headers.append("x-api-key: " + secret)
		else:
			headers.append("Authorization: Bearer " + secret)
	if profile.get("transport", "") == "anthropic_messages":
		headers.append("anthropic-version: 2023-06-01")
	return {"ok": true, "headers": headers}

static func build_generation(profile: Dictionary, messages: Array) -> Dictionary:
	var clean: Array[Dictionary] = []
	if messages.is_empty() or messages.size() > 256:
		return failure("context", "Conversation context must contain between 1 and 256 messages.")
	for message in messages:
		if not message is Dictionary or not message.get("content", "") is String:
			return failure("context", "Conversation messages must contain text.")
		var role := str(message.get("role", ""))
		if not role in ["system", "user", "assistant"]:
			return failure("context", "Conversation contains an unsupported message role.")
		clean.append({"role": role, "content": message.content})
	var tokens := Registry.bounded_int(profile.get("max_output_tokens", 512), 512, 64, 8192)
	var transport := str(profile.get("transport", "chat_completions"))
	var body := {"model": str(profile.get("model", "")), "stream": false}
	var path := "/chat/completions"
	match transport:
		"responses":
			path = "/responses"
			body["input"] = clean
			body["max_output_tokens"] = tokens
			body["store"] = false
		"anthropic_messages":
			path = "/messages"
			var system_parts: Array[String] = []
			var turns: Array[Dictionary] = []
			for message in clean:
				if message.role == "system":
					system_parts.append(message.content)
				else:
					turns.append(message)
			body["messages"] = turns
			body["max_tokens"] = tokens
			if not system_parts.is_empty():
				body["system"] = "\n\n".join(system_parts)
		"chat_completions":
			body["messages"] = clean
			body["max_tokens"] = tokens
		_:
			return failure("configuration", "Unsupported model transport.")
	if JSON.stringify(body).to_utf8_buffer().size() > MAX_REQUEST_BYTES:
		return failure("context", "Conversation context exceeds the request size limit. Compact memory and try again.")
	return {"ok": true, "body": body, "path": path}

static func parse_models(data: Variant) -> Dictionary:
	if not data is Dictionary or not data.get("data", []) is Array:
		return failure("models", "The provider returned an unsupported model list. Enter an exact model ID manually.")
	var models: Array[String] = []
	for row in data.get("data", []):
		if row is Dictionary and row.get("id", "") is String:
			var model: String = row.id
			if not model.is_empty() and model.length() <= 256 and not model in models:
				models.append(model)
		if models.size() >= 2048:
			break
	models.sort()
	if models.is_empty():
		return failure("models", "No models were listed. Enter an exact model ID manually.")
	return {"ok": true, "models": models}

static func parse_generation(transport: String, data: Variant) -> Dictionary:
	if not data is Dictionary:
		return failure("response", "The provider returned an invalid response.")
	var parts: Array[String] = []
	var truncated := false
	match transport:
		"responses":
			truncated = data.get("status", "") == "incomplete"
			var outputs: Variant = data.get("output", [])
			if outputs is Array:
				for item in outputs:
					if item is Dictionary and item.get("type", "") == "message":
						_append_text_parts(parts, item.get("content", []), "output_text")
		"anthropic_messages":
			truncated = data.get("stop_reason", "") == "max_tokens"
			_append_text_parts(parts, data.get("content", []), "text")
		_:
			var choices: Variant = data.get("choices", [])
			if choices is Array and not choices.is_empty() and choices[0] is Dictionary:
				truncated = choices[0].get("finish_reason", "") == "length"
				var message: Variant = choices[0].get("message", {})
				if message is Dictionary:
					var content: Variant = message.get("content", "")
					if content is String:
						parts.append(content)
					else:
						_append_text_parts(parts, content, "text")
	var text := "\n".join(parts).strip_edges()
	if text.is_empty():
		return failure("empty_response", "The model returned no dialogue text. Try a larger output limit or a different model.")
	return {"ok": true, "text": text, "truncated": truncated}

static func _append_text_parts(parts: Array[String], content: Variant, type: String) -> void:
	if not content is Array:
		return
	for block in content:
		if block is Dictionary and block.get("type", "") == type and block.get("text", "") is String:
			parts.append(block.text)

func _request(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String, seconds: float) -> Dictionary:
	if not is_inside_tree():
		return failure("unavailable", "The model client must be in the scene tree.")
	var check := Registry.validate_endpoint(url)
	if not check.ok:
		return check
	var epoch := _epoch
	var request := HTTPRequest.new()
	request.timeout = seconds
	request.body_size_limit = MAX_RESPONSE_BYTES
	request.max_redirects = 0 # Credentials never follow a provider redirect.
	add_child(request)
	_http = request
	var response: Array = []
	request.request_completed.connect(func(result: int, code: int, response_headers: PackedStringArray, bytes: PackedByteArray) -> void:
		response.assign([result, code, response_headers, bytes]))
	var start_error := request.request(url, headers, method, body)
	if start_error != OK:
		request.queue_free()
		return failure("network", "Could not start the connection. Check the API URL and network permissions.")
	while response.is_empty() and epoch == _epoch:
		await get_tree().process_frame
	request.queue_free()
	if epoch != _epoch:
		return failure("cancelled", "Request cancelled.")
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		if response[0] == HTTPRequest.RESULT_TIMEOUT:
			return failure("timeout", "The model request timed out. Try again or increase the timeout.")
		if response[0] in [HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR]:
			return failure("response_size", "The provider response exceeded the size limit.")
		return failure("network", "Could not reach the provider. Check the connection, TLS certificate, and API URL.")
	var status: int = response[1]
	var parser := JSON.new()
	var parsed_ok := parser.parse((response[3] as PackedByteArray).get_string_from_utf8()) == OK
	var data: Variant = parser.data if parsed_ok else null
	if status < 200 or status >= 300:
		var failed := http_failure(status)
		# Only machine OAuth codes are passed through, never provider body/error text.
		if data is Dictionary and data.get("error", null) is String:
			var oauth_code: String = data.error
			if oauth_code in ["authorization_pending", "slow_down", "access_denied", "expired_token", "invalid_grant"]:
				failed["oauth_code"] = oauth_code
		return failed
	if not parsed_ok or not data is Dictionary:
		return failure("response", "The provider returned invalid JSON.")
	return {"ok": true, "data": data, "status": status}

func begin_device_login(profile: Dictionary) -> Dictionary:
	if _busy:
		return failure("busy", "A model request is already running.")
	var check := Registry.validate_profile(profile, false)
	if not check.ok:
		return check
	if profile.get("auth_mode", "") != "oauth_device":
		return failure("configuration", "Choose a configured device OAuth profile first.")
	_busy = true
	_device.clear()
	var result := await _form(str(profile.oauth_device_url), {"client_id": str(profile.oauth_client_id), "scope": str(profile.get("oauth_scope", ""))})
	_busy = false
	if not result.ok:
		return result
	var data: Dictionary = result.data
	var uri := str(data.get("verification_uri", ""))
	if not Registry.validate_verification_url(uri).ok:
		return failure("oauth", "The authorization server returned an invalid verification URL.")
	if str(data.get("device_code", "")).is_empty() or str(data.get("user_code", "")).is_empty():
		return failure("oauth", "The authorization server did not return device and user codes.")
	var expiry := Registry.bounded_int(data.get("expires_in", 600), 600, 1, 1800)
	_device = {"binding": oauth_binding(profile), "device_code": str(data.device_code),
		"expires_at": Time.get_ticks_msec() + expiry * 1000, "interval": Registry.bounded_int(data.get("interval", 5), 5, 1, 1800)}
	return {"ok": true, "verification_uri": uri, "user_code": str(data.user_code), "expires_in": expiry, "interval": _device.interval}

func complete_device_login(profile: Dictionary) -> Dictionary:
	if _busy:
		return failure("busy", "A model request is already running.")
	if _device.is_empty() or _device.get("binding", "") != oauth_binding(profile):
		return failure("oauth", "Start a new device sign-in for this profile.")
	_busy = true
	var epoch := _epoch
	var state := _device.duplicate(true)
	var result := failure("oauth_expired", "The sign-in code expired. Start sign-in again.")
	while Time.get_ticks_msec() < state.expires_at and epoch == _epoch:
		var until := mini(Time.get_ticks_msec() + int(state.interval) * 1000, int(state.expires_at))
		while Time.get_ticks_msec() < until and epoch == _epoch:
			await get_tree().process_frame
		if epoch != _epoch or Time.get_ticks_msec() >= state.expires_at:
			break
		var remaining_seconds := maxf(0.1, float(int(state.expires_at) - Time.get_ticks_msec()) / 1000.0)
		result = await _form(str(profile.oauth_token_url), {"client_id": str(profile.oauth_client_id), "device_code": state.device_code, "grant_type": "urn:ietf:params:oauth:grant-type:device_code"}, minf(30.0, remaining_seconds))
		var code := str(result.get("oauth_code", ""))
		if result.ok:
			if epoch != _epoch or Time.get_ticks_msec() >= state.expires_at:
				break
			result = _accept_tokens(profile, result.data)
			break
		if code == "authorization_pending":
			continue
		if code == "slow_down":
			state.interval = int(state.interval) + 5
			continue
		if result.get("error_code", "") == "timeout":
			state.interval = mini(3600, int(state.interval) * 2)
			continue
		if code == "access_denied":
			result = failure("oauth_denied", "Sign-in was declined. You can try again.")
		break
	_device.clear()
	_busy = false
	if epoch != _epoch:
		return failure("cancelled", "Sign-in cancelled.")
	if Time.get_ticks_msec() >= state.expires_at:
		return failure("oauth_expired", "The sign-in code expired. Start sign-in again.")
	return result

func _refresh_if_needed(profile: Dictionary) -> Dictionary:
	var binding := oauth_binding(profile)
	var epoch := _epoch
	while _refreshing.has(binding) and epoch == _epoch:
		var owner: Variant = (_refreshing[binding] as WeakRef).get_ref()
		if not is_instance_valid(owner) or not owner.is_inside_tree():
			_refreshing.erase(binding)
			break
		await get_tree().process_frame
	if epoch != _epoch:
		return failure("cancelled", "Sign-in refresh cancelled.")
	var tokens := Credentials.get_oauth(str(profile.id))
	if tokens.get("binding", "") != binding:
		return failure("authentication", "Sign in again for this OAuth profile.")
	if float(tokens.get("expires_at", 0)) > Time.get_unix_time_from_system() + 60:
		return {"ok": true}
	if str(tokens.get("refresh_token", "")).is_empty():
		return failure("authentication", "Your sign-in expired. Sign in again.")
	_refreshing[binding] = weakref(self)
	var result := await _form(str(profile.oauth_token_url), {"client_id": str(profile.oauth_client_id), "refresh_token": tokens.refresh_token, "grant_type": "refresh_token"})
	_refreshing.erase(binding)
	if not result.ok:
		return result
	return _accept_tokens(profile, result.data, str(tokens.refresh_token))

func _accept_tokens(profile: Dictionary, data: Dictionary, previous_refresh: String = "") -> Dictionary:
	if data.has("error"):
		return oauth_failure(str(data.get("error", "")))
	var token: Variant = data.get("access_token", "")
	if not token is String or token.is_empty() or token.length() > 32768 or token.contains("\n") or token.contains("\r") or str(data.get("token_type", "Bearer")).to_lower() != "bearer":
		return failure("oauth", "The authorization server returned no supported bearer token.")
	Credentials.bind_profile(profile)
	Credentials.set_oauth(str(profile.id), {"access_token": str(data.access_token),
		"refresh_token": str(data.get("refresh_token", previous_refresh)), "binding": oauth_binding(profile),
		"expires_at": Time.get_unix_time_from_system() + Registry.bounded_int(data.get("expires_in", 3600), 3600, 1, 604800)})
	return {"ok": true}

func _form(url: String, fields: Dictionary, seconds: float = 30.0) -> Dictionary:
	var parts: Array[String] = []
	for key in fields:
		parts.append(str(key).uri_encode() + "=" + str(fields[key]).uri_encode())
	var result := await _request(url, HTTPClient.METHOD_POST, PackedStringArray(["Content-Type: application/x-www-form-urlencoded", "Accept: application/json"]), "&".join(parts), seconds)
	if result.get("data") is Dictionary and result.data.has("error"):
		return oauth_failure(str(result.data.get("error", "")))
	return result

static func oauth_failure(code: String) -> Dictionary:
	var result := failure("oauth", "The authorization server rejected the sign-in request. Check your application registration and try again.")
	if code in ["authorization_pending", "slow_down", "access_denied", "expired_token", "invalid_grant"]:
		result["oauth_code"] = code
	return result

static func oauth_binding(profile: Dictionary) -> String:
	return Credentials.profile_binding(profile)

static func http_failure(status: int) -> Dictionary:
	var message := "The provider rejected the request (HTTP %d). Check model ID, transport, and output limit." % status
	var code := "provider"
	match status:
		401, 403:
			message = "Authentication or model access was denied. Check the credential and provider permissions."
			code = "authentication"
		402:
			message = "The provider needs credit or an eligible account before it can answer."
			code = "billing"
		404:
			message = "The model or API route was not found. Check the model ID, base URL, and transport. Model discovery may be unavailable; a manual ID can still work."
		429:
			message = "The provider is rate limited or its quota is exhausted. Wait before retrying."
			code = "rate_limit"
		500, 502, 503, 504:
			message = "The provider is temporarily unavailable. Try again later."
	return {"ok": false, "error": message, "error_code": code, "status": status}

static func failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": message, "error_code": code}

static func base_url(profile: Dictionary) -> String:
	return str(profile.get("base_url", "")).trim_suffix("/")

static func timeout(profile: Dictionary) -> float:
	return float(Registry.bounded_int(profile.get("timeout_seconds", 60), 60, 5, 180))
