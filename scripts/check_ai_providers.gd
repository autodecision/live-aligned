extends SceneTree
## Offline unit checks plus optional local HTTP fixture; never reads real auth.
const Registry = preload("res://scripts/ai/ai_provider_registry.gd")
const Credentials = preload("res://scripts/ai/ai_credentials.gd")
const Client = preload("res://scripts/ai/ai_provider_client.gd")
var failures := 0
var checks := 0
var fixture_url := ""
var tmp := "/tmp/live-aligned-provider-test-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]

class OAuthFixture extends AIProviderClient:
	var replies: Array[Dictionary] = []
	var calls := 0
	func _request(_url: String, _method: HTTPClient.Method, _headers_value: PackedStringArray, _body: String, _seconds: float) -> Dictionary:
		await get_tree().process_frame
		calls += 1
		return replies.pop_front() if not replies.is_empty() else {"ok": true, "data": {"error": "authorization_pending"}}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-url="):
			fixture_url = argument.trim_prefix("--fixture-url=")
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _run() -> void:
	check(Registry.validate_endpoint("http://127.0.0.1:1234/v1").ok, "loopback HTTP allowed")
	check(Registry.validate_endpoint("http://[::1]:1234/v1").ok, "IPv6 loopback HTTP allowed")
	for url in ["http://example.com/v1", "https://" + "user:password@example.com/v1", "https://example.com?token=secret", "https://example.com:99999/v1", "https://example.com/\nsecret"]:
		check(not Registry.validate_endpoint(url).ok, "unsafe endpoint rejected")
	check(Registry.validate_verification_url("https://login.example/device?code=opaque%20query").ok, "verification query accepted")
	check(not Registry.validate_verification_url("https://" + "user:pass@login.example/device?code=x").ok, "verification userinfo rejected")
	check(not Registry.validate_verification_url("http://127.0.0.1/device?code=x").ok, "verification HTTPS required")
	var profile := Registry.default_profile("custom")
	profile.model = "fixture-model"
	profile.base_url = "http://127.0.0.1:1234/v1"
	profile.max_output_tokens = {"bad": 1}
	profile.timeout_seconds = []
	var clean := Registry.sanitize_settings({"profiles": [profile], "memory_limits": {"global_bytes": 1048576, "context_chars": 2048}, "secret": "test-only-not-real", "api_key": "test-only-not-real"})
	check(clean.profiles[0].max_output_tokens == 512 and clean.profiles[0].timeout_seconds == 60, "malformed numeric values default safely")
	check(clean.memory_limits.global_bytes == 1048576 and clean.memory_limits.context_chars == 2048, "memory limit envelope retained")
	check(not JSON.stringify(clean).contains("test-only-not-real"), "unknown secret fields dropped")
	var dirty := profile.duplicate(true)
	dirty.oauth_device_url = "https://" + "name:secret@example.com/device"
	dirty.oauth_token_url = "https://example.com/token?secret=bad"
	clean = Registry.sanitize_settings({"profiles": [dirty]})
	check(clean.profiles[0].oauth_device_url == "" and clean.profiles[0].oauth_token_url == "", "OAuth credential URLs not persisted")
	var saved := Registry.save_settings({"profiles": [profile]}, tmp.path_join("settings.json"))
	check(saved.ok and Registry.load_settings(tmp.path_join("settings.json")).profiles[0].model == "fixture-model", "nonsecret settings round trip")
	var oversized: Array = []
	for index in range(32):
		var large := profile.duplicate(true)
		large.id = str(index)
		for field in ["name", "model", "oauth_scope", "oauth_client_id"]:
			large[field] = "x".repeat(2048)
		oversized.append(large)
	check(not Registry.save_settings({"profiles": oversized}, tmp.path_join("too-large.json")).ok, "oversized settings blocked before write")
	Credentials.bind_profile(profile)
	Credentials.set_secret(profile.id, "fixture-secret")
	check(Credentials.matches_profile(profile) and Credentials.get_secret(profile.id) == "fixture-secret", "credential bound to profile")
	var changed := profile.duplicate(true)
	changed.base_url = "https://elsewhere.example/v1"
	Credentials.bind_profile(changed)
	check(not Credentials.has_secret(profile.id), "changed endpoint forgets credential")
	for field in ["provider_id", "auth_mode", "transport", "oauth_client_id"]:
		Credentials.bind_profile(profile)
		Credentials.set_secret(profile.id, "fixture-secret")
		changed = profile.duplicate(true)
		changed[field] = "changed"
		Credentials.bind_profile(changed)
		check(not Credentials.has_secret(profile.id), "changed security field forgets credential")
	var nous := Registry.default_profile("nous")
	nous.auth_mode = "hermes_session"
	var header := Marshalls.utf8_to_base64('{"alg":"none"}').trim_suffix("=").trim_suffix("=")
	var claims := Marshalls.utf8_to_base64(JSON.stringify({"exp": Time.get_unix_time_from_system() + 600, "scope": "inference:invoke"})).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	var token := header + "." + claims + ".fixture-signature"
	check(Credentials.import_hermes_data(nous, {"providers": {"nous": {"access_token": token, "refresh_token": "must-not-copy"}}}).ok, "explicit synthetic Hermes access token import")
	check(not Credentials.get_oauth(nous.id).has("refresh_token"), "Hermes refresh token never copied")
	changed = nous.duplicate(true)
	changed.base_url = "https://elsewhere.example/v1"
	check(not Credentials.import_hermes_data(changed, {"providers": {"nous": {"access_token": token}}}).ok, "Hermes token cannot be imported for alternate endpoint")
	check(not Credentials.import_hermes_data(nous, {"providers": {"nous": {"access_token": "opaque"}}}).ok, "Hermes unbounded expiry rejected")
	var connector_claims := Marshalls.utf8_to_base64(JSON.stringify({"exp": Time.get_unix_time_from_system() + 600, "scope": "connectors:read"})).trim_suffix("=").trim_suffix("=")
	var connector_token := header + "." + connector_claims + ".fixture-signature"
	check(not Credentials.import_hermes_data(nous, {"providers": {"nous": {"access_token": connector_token}}}).ok, "connectors-only token cannot be used for inference")
	check(Credentials.import_hermes_data(nous, {"providers": {"nous": {"access_token": connector_token, "agent_key": token}}}).ok and Credentials.get_secret(nous.id) == token, "eligible cached agent key preferred to connectors token")
	Credentials.clear_all()
	var response := Client.parse_generation("responses", {"output": [{"type": "reasoning", "content": [{"type": "output_text", "text": "hidden"}]}, {"type": "message", "content": [{"type": "output_text", "text": "Hello"}]}]})
	check(response.ok and response.text == "Hello", "Responses exposes dialogue only")
	response = Client.parse_generation("anthropic_messages", {"content": [{"type": "thinking", "thinking": "hidden"}, {"type": "text", "text": "Hello"}]})
	check(response.ok and response.text == "Hello", "Anthropic exposes dialogue only")
	response = Client.parse_generation("chat_completions", {"choices": [{"message": {"content": "Hello", "reasoning_content": "hidden"}}]})
	check(response.ok and response.text == "Hello", "Chat exposes dialogue only")
	check(not Client.parse_generation("chat_completions", {"choices": [{"message": {"reasoning_content": "hidden"}}]}).ok, "reasoning-only reply reported empty")
	var oauth := OAuthFixture.new()
	root.add_child(oauth)
	var device := Registry.default_profile("custom")
	device.auth_mode = "oauth_device"
	device.base_url = "https://inference.example/v1"
	device.oauth_client_id = "fixture-public-client"
	device.oauth_device_url = "https://login.example/device"
	device.oauth_token_url = "https://login.example/token"
	oauth.replies = [{"ok": true, "data": {"error": "authorization_pending"}}]
	var result: Dictionary = await oauth._form(device.oauth_token_url, {})
	check(not result.ok and result.oauth_code == "authorization_pending", "HTTP200 OAuth pending normalized to failure")
	oauth.replies = [{"ok": true, "data": {"error": "unrecognized_error", "access_token": "must-not-accept"}}]
	result = await oauth._form(device.oauth_token_url, {})
	check(not result.ok, "every HTTP200 OAuth error normalized to failure")
	check(not oauth._accept_tokens(device, {"error": "authorization_pending", "access_token": "must-not-accept"}).ok, "OAuth error never accepted as token")
	oauth.replies = [{"ok": true, "data": {"device_code": "fixture-device", "user_code": "USER-CODE", "verification_uri": "https://login.example/device?code=query", "expires_in": 2, "interval": 1}}]
	result = await oauth.begin_device_login(device)
	check(result.ok and result.verification_uri.contains("?code="), "device login accepts query-bearing verification URL")
	result = await oauth.complete_device_login(device)
	check(not result.ok and result.error_code == "oauth_expired" and not Credentials.has_secret(device.id), "pending until expiry cannot report success or store token")
	oauth.replies = [{"ok": true, "data": {"device_code": "fixture-device", "user_code": "USER-CODE", "verification_uri": "https://login.example/device", "expires_in": 15, "interval": 1}}, {"ok": true, "data": {"access_token": "fixture-access", "token_type": "bearer", "expires_in": 300}}]
	check((await oauth.begin_device_login(device)).ok, "second device grant starts")
	result = await oauth.complete_device_login(device)
	check(result.ok and Credentials.get_secret(device.id) == "fixture-access", "successful device grant stores session token")
	oauth.replies = [{"ok": true, "data": {"device_code": "fixture-device", "user_code": "USER-CODE", "verification_uri": "https://login.example/device", "expires_in": 15, "interval": 120}}]
	result = await oauth.begin_device_login(device)
	check(result.ok and result.interval == 120, "server poll interval greater than one minute preserved")
	create_timer(0.1).timeout.connect(oauth.cancel)
	result = await oauth.complete_device_login(device)
	check(not result.ok and result.error_code == "cancelled" and not oauth.is_busy(), "device polling cancels while waiting")
	var other := OAuthFixture.new()
	root.add_child(other)
	Credentials.bind_profile(device)
	Credentials.set_oauth(device.id, {"access_token": "old-access", "refresh_token": "fixture-refresh", "expires_at": 0, "binding": Client.oauth_binding(device)})
	oauth.calls = 0
	other.calls = 0
	oauth.replies = [{"ok": true, "data": {"access_token": "refreshed-access", "expires_in": 300}}]
	other.replies = oauth.replies.duplicate(true)
	var refreshed_results: Array[Dictionary] = []
	_collect_headers.call_deferred(oauth, device, refreshed_results)
	_collect_headers.call_deferred(other, device, refreshed_results)
	while refreshed_results.size() < 2:
		await process_frame
	check(refreshed_results[0].ok and refreshed_results[1].ok and oauth.calls + other.calls == 1, "concurrent clients share one refresh and reuse rotated token")
	other.queue_free()
	Credentials.clear_all()
	oauth.queue_free()
	if not fixture_url.is_empty():
		await _network_checks()
	DirAccess.remove_absolute(tmp.path_join("settings.json"))
	DirAccess.remove_absolute(tmp)
	print("AI providers: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _network_checks() -> void:
	var client := Client.new()
	root.add_child(client)
	var profile := Registry.default_profile("custom")
	profile.model = "fixture-model"
	profile.base_url = fixture_url
	profile.auth_mode = "api_key"
	var messages := [{"role": "system", "content": "Be kind."}, {"role": "user", "content": "Hello"}]
	for transport in ["responses", "chat_completions", "anthropic_messages"]:
		profile.transport = transport
		Credentials.bind_profile(profile)
		Credentials.set_secret(profile.id, "fixture-secret")
		var result: Dictionary = await client.generate(profile, messages)
		check(result.ok and result.get("text") == transport + " fixture", "real loopback HTTP transport " + transport)
	var models: Dictionary = await client.fetch_models(profile)
	check(models.ok and models.models == ["fixture-a", "fixture-z"], "real model discovery normalizes list")
	profile.base_url = fixture_url + "/changed"
	check(not (await client.fetch_models(profile)).ok and not Credentials.has_secret(profile.id), "changed URL cannot forward stored key")
	profile.auth_mode = "none"
	for route in ["unauthorized", "rate-limit", "bad-json", "redirect", "huge"]:
		profile.base_url = fixture_url + "/" + route
		profile.auth_mode = "api_key" if route == "redirect" else "none"
		Credentials.bind_profile(profile)
		if route == "redirect":
			Credentials.set_secret(profile.id, "fixture-secret")
		var result: Dictionary = await client.fetch_models(profile)
		check(not result.ok, "real loopback failure " + route)
		check(not str(result.get("error", "")).contains("must never echo"), "provider error text sanitized")
	var timed_out: Dictionary = await client._request(fixture_url + "/slow/models", HTTPClient.METHOD_GET, PackedStringArray(), "", 0.1)
	check(not timed_out.ok and timed_out.error_code == "timeout", "real loopback request timeout reported")
	profile.base_url = fixture_url + "/slow"
	profile.auth_mode = "none"
	create_timer(0.1).timeout.connect(client.cancel)
	var cancelled: Dictionary = await client.fetch_models(profile)
	check(not cancelled.ok and cancelled.error_code == "cancelled" and not client.is_busy(), "inflight request cancels without hanging")
	profile.base_url = fixture_url
	check((await client.fetch_models(profile)).ok, "client reusable after cancellation")
	Credentials.clear_all()
	client.queue_free()

func _collect_headers(client: AIProviderClient, profile: Dictionary, results: Array[Dictionary]) -> void:
	results.append(await client._headers(profile))
