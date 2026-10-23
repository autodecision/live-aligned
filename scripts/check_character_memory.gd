extends SceneTree
## Isolated Linux QA: godot --headless --path . --script res://scripts/check_character_memory.gd
const Memory = preload("res://scripts/ai/character_memory.gd")
var failures := 0
var checks := 0
var test_root := "/tmp/live-aligned-memory-test-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _run() -> void:
	var memory := Memory.new()
	memory.configure(test_root.path_join("main"), {"recent_turns": 2, "recall_entries": 16, "context_chars": 1800, "recall_chars": 550})
	check(memory.last_error.is_empty(), "storage config succeeds")
	check(memory.append_turn("gardener", "My favorite flower is the purple orchid.", "I will remember the purple orchid.").ok, "append first turn")
	check(memory.append_turn("poet", "I enjoy scarlet poppies.", "Scarlet poppies are beautiful.").ok, "append isolated character")
	for index in range(6):
		check(memory.append_turn("gardener", "Tell me about garden path %d." % index, "The stone path bends toward pond %d." % index).ok, "append recent turn")
	var stats: Dictionary = memory.get_stats("gardener")
	check(stats.recent_turns == 2 and stats.recall_entries == 5, "old dialogue compacted to recall")
	check(memory.get_recent("gardener").size() == 4, "recent pairs remain bounded")
	var context: Array[Dictionary] = memory.build_context("gardener", "purple orchid")
	check(JSON.stringify(context).contains("purple orchid"), "old matching fact recalled")
	check(not JSON.stringify(context).contains("scarlet poppies"), "cross-character recall excluded")
	check(not JSON.stringify(memory.build_context("poet", "purple orchid")).contains("purple orchid"), "query itself is not appended")
	var length := 0
	for message in context:
		length += str(message.content).length()
	check(length <= 1800, "prompt context has independent cap")
	var reopened := Memory.new()
	reopened.configure(test_root.path_join("main"), {"recent_turns": 2})
	check(JSON.stringify(reopened.get_recent("gardener")) == JSON.stringify(memory.get_recent("gardener")), "restart persists recent dialogue")
	check(JSON.stringify(reopened.build_context("gardener", "purple orchid")).contains("purple orchid"), "restart persists compacted recall")
	check(reopened.compact("gardener").ok, "manual compaction succeeds")
	check(reopened.get_stats("gardener").recall_entries > 0, "manual compaction preserves recall")
	check(not reopened.append_turn("", "hello", "hi").ok, "blank ID rejected")
	check(not reopened.append_turn("a".repeat(161), "hello", "hi").ok, "overlong ID rejected")
	check(reopened.append_turn("../../outside", "safe path", "hashed name").ok, "path-like ID is safely hashed")
	check(not FileAccess.file_exists(test_root.path_join("outside.json")), "ID cannot escape storage root")
	var fake_secret := "sk-" + "testvalue".repeat(5)
	check(reopened.append_turn("secrets", "api_key=" + fake_secret, "Authorization: Bearer " + "testvalue".repeat(4)).ok, "credential-containing turn stored safely")
	check(not JSON.stringify(reopened.get_recent("secrets")).contains(fake_secret), "credentials are redacted")
	var broken_path := test_root.path_join("main").path_join("broken".sha256_text() + ".json")
	_write(broken_path, "{ damaged json")
	check(not reopened.append_turn("broken", "hello", "hi").ok, "corruption produces an actionable error")
	check(FileAccess.get_file_as_string(broken_path) == "{ damaged json", "corrupt data preserved until explicit clear")
	check(reopened.clear_character("broken").ok and reopened.append_turn("broken", "hello", "hi").ok, "clear recovers corrupt character")
	var temp_path := test_root.path_join("main").path_join("crash".sha256_text() + ".tmp")
	_write(temp_path, "unfinished")
	var cleanup := Memory.new()
	cleanup.configure(test_root.path_join("main"))
	check(not FileAccess.file_exists(temp_path), "interrupted staging file removed on reopen")
	var constrained := Memory.new()
	constrained.configure(test_root.path_join("pressure"), {"global_bytes": 8192, "character_bytes": 2048, "max_characters": 3, "recent_turns": 2, "recall_entries": 8})
	for character in range(10):
		for index in range(3):
			check(constrained.append_turn("person-%d" % character, ("界🦜%d" % index).repeat(300), ("Answer %d " % index).repeat(100)).ok, "Unicode pressure append fits budget")
		var pressure_stats: Dictionary = constrained.get_stats("person-%d" % character)
		check(pressure_stats.bytes <= 2048 and pressure_stats.global_bytes <= 8192, "both byte budgets enforced")
		check(pressure_stats.character_count <= 3, "character count bounded")
	check(constrained.get_stats().evicted_characters > 0, "global pressure evictions observable")
	check(constrained.set_limits({"max_characters": 1}).ok and constrained.get_stats().character_count == 1, "lowering count limit applies immediately")
	var shrink := Memory.new()
	shrink.configure(test_root.path_join("shrink"))
	check(shrink.append_turn("one", "History ".repeat(500), "Remember ".repeat(500)).ok, "large snapshot stored")
	check(shrink.set_limits({"character_bytes": 2048}).ok, "lowering byte limit compacts valid snapshot")
	check(shrink.get_recent("one").size() == 2 and shrink.get_stats("one").bytes <= 2048, "shrinking cap retains latest turn")
	var foreign := Memory.new()
	foreign.configure(test_root.path_join("foreign"))
	_write(test_root.path_join("foreign/unmanaged.bin"), "x".repeat(9000))
	check(not foreign.set_limits({"global_bytes": 8192}).ok, "foreign file accounting cannot bypass cap")
	check(not foreign.append_turn("new", "hello", "hi").ok, "foreign files prevent over-budget writes")
	_write(test_root.path_join("foreign/.hidden.bin"), "y".repeat(100))
	check(foreign.get_stats().global_bytes == 9100, "hidden unmanaged files count toward actual bytes")
	check(memory.clear_character("gardener").ok and memory.get_recent("gardener").is_empty(), "clear deletes selected character")
	check(not memory.get_recent("poet").is_empty(), "clear leaves other characters intact")
	_check_extra_cases()
	_remove_tree(test_root)
	check(not DirAccess.dir_exists_absolute(test_root), "temporary test tree fully removed")
	print("Character memory: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_extra_cases() -> void:
	var memory := Memory.new()
	var directory := test_root.path_join("extra")
	memory.configure(directory, {"recent_turns": 1, "recall_entries": 8, "max_characters": 2})
	check(memory.append_turn("alpha", "original", "preserved").ok, "failure-test initial memory")
	check(memory.append_turn("beta", "second", "retained").ok, "failure-test second memory")
	var before_alpha := JSON.stringify(memory.get_recent("alpha"))
	var before_beta := JSON.stringify(memory.get_recent("beta"))
	# Force a real staging-open failure, while already at the character limit.
	var blocked_stage := directory.path_join("gamma".sha256_text() + ".tmp")
	DirAccess.make_dir_absolute(blocked_stage)
	check(not memory.append_turn("gamma", "new", "turn").ok, "staging-open failure is reported")
	check(JSON.stringify(memory.get_recent("alpha")) == before_alpha and JSON.stringify(memory.get_recent("beta")) == before_beta, "failed staging never evicts another character")
	DirAccess.remove_absolute(blocked_stage)
	# Force rename failure after a successful write, with a directory collision.
	var blocked_commit := directory.path_join("gamma".sha256_text() + ".json")
	DirAccess.make_dir_absolute(blocked_commit)
	check(not memory.append_turn("gamma", "new", "turn").ok, "atomic rename failure is reported")
	check(JSON.stringify(memory.get_recent("alpha")) == before_alpha and JSON.stringify(memory.get_recent("beta")) == before_beta, "failed rename never evicts another character")
	check(not FileAccess.file_exists(blocked_stage), "failed commit removes its staging snapshot")
	DirAccess.remove_absolute(blocked_commit)
	check(memory.append_turn("gamma", "new", "turn").ok and memory.get_stats().character_count == 2, "successful commit alone evicts to count limit")
	var tiny := Memory.new()
	tiny.configure(test_root.path_join("tiny"), {"context_chars": 1})
	check(tiny.append_turn("one", "u".repeat(900), "a".repeat(900)).ok, "long turn for tiny prompt budget")
	check(tiny.build_context("one", "query").is_empty(), "one-character budget omits incomplete pairs")
	for limit in [0, 2, 3, 7, 1024]:
		check(tiny.set_limits({"context_chars": limit}).ok, "tiny context budget applies")
		var used := 0
		for message in tiny.build_context("one", "query"):
			used += str(message.content).length()
		check(used <= limit, "context respects exact tiny or odd character budget")
	var bounded := Memory.new()
	bounded.configure(test_root.path_join("records"), {"recent_turns": 1, "recall_entries": 8})
	check(bounded.append_turn("one", "Opening " + "padding ".repeat(160) + "My late fact is that I keep emerald parrots.", "I understand.").ok, "store fact at end of long message")
	check(bounded.append_turn("one", "next topic", "next answer").ok, "compact long message")
	check(JSON.stringify(bounded.build_context("one", "emerald parrots")).contains("emerald parrots"), "extraction retains trailing facts")
	for index in range(24):
		check(bounded.append_turn("one", "Topic%d " % index + "x".repeat(40), "Answer %d" % index).ok, "record-pressure append")
	var stats: Dictionary = bounded.get_stats("one")
	check(stats.recent_turns == 1 and stats.recall_entries <= 8 and stats.pruned_entries > 0, "record counts and observed pruning bounded")
	check(bounded.set_limits({"recall_entries": 20, "recent_turns": 4}).ok, "raise record allowance")
	for index in range(12):
		check(bounded.append_turn("one", "New topic %d" % index, "New answer %d" % index).ok, "fill higher record allowance")
	check(bounded.set_limits({"recall_entries": 8, "recent_turns": 1}).ok, "lower record allowance persisted")
	var bounded_reopened := Memory.new()
	bounded_reopened.configure(test_root.path_join("records"))
	check(bounded_reopened.get_stats("one").recent_turns == 1 and bounded_reopened.get_stats("one").recall_entries <= 8, "restart cannot resurrect records pruned by lower limits")
	var malformed := Memory.new()
	var malformed_directory := test_root.path_join("malformed")
	malformed.configure(malformed_directory)
	for bad_state in [
		{"schema": 9, "character_id": "one", "recent": [], "recall": []},
		{"schema": 1, "character_id": "different", "recent": [], "recall": []},
		{"schema": 1, "character_id": "one", "recent": [{"user": 12, "assistant": "hi"}], "recall": []},
		{"schema": 1, "character_id": "one", "recent": [], "recall": [{"text": {"bad": "shape"}}]},
	]:
		var path := malformed_directory.path_join("one".sha256_text() + ".json")
		_write(path, JSON.stringify(bad_state))
		check(not malformed.append_turn("one", "new", "turn").ok, "invalid schema/identity/field shape rejected")
		check(FileAccess.get_file_as_string(path) == JSON.stringify(bad_state), "invalid record is preserved")
	malformed.clear_character("one")
	check(malformed.append_turn("one", "界".repeat(40000), "🦜".repeat(40000)).ok, "overlong Unicode is bounded before serialization")
	check(str(malformed.get_recent("one")[0].content).length() <= 6000, "message character ceiling applied")
	check(malformed.set_limits({"character_bytes": 2 * 1024 * 1024 * 1024, "context_chars": NAN, "recall_entries": INF}).ok, "extreme/nonfinite numeric settings handled")
	check(malformed.get_stats("one").budget_bytes == 1024 * 1024, "actual snapshot safety ceiling exposed")
	var full := Memory.new()
	full.configure(test_root.path_join("full-cap"), {"recent_turns": 1})
	var complete := true
	for index in range(530):
		if not full.append_turn("one", "Topic %d flowers" % index, "A literal answer %d" % index).ok:
			complete = false
			break
	check(complete, "full-size retention workload stores successfully")
	stats = full.get_stats("one")
	check(stats.recall_entries == 512 and stats.recent_turns == 1 and stats.pruned_entries == 17, "default recall reaches hard512 cap then prunes")
	var global_shrink := Memory.new()
	global_shrink.configure(test_root.path_join("global-shrink"))
	for index in range(5):
		check(global_shrink.append_turn("person%d" % index, "x".repeat(3000), "y".repeat(3000)).ok, "store before lowering global limit")
	check(global_shrink.set_limits({"global_bytes": 8192, "character_bytes": 2048}).ok, "global cap reduction prunes immediately")
	stats = global_shrink.get_stats()
	check(stats.global_bytes <= stats.global_retained_budget_bytes and stats.global_bytes <= 8192, "reduced global cap includes reserved staging headroom")
	_check_long_conversation_and_notes()


func _check_long_conversation_and_notes() -> void:
	var memory := Memory.new()
	var dir := test_root.path_join("personas-and-compaction")
	memory.configure(dir, {"recent_turns": 6, "recall_entries": 12, "context_chars": 4000, "recall_chars": 1200})
	check(memory.append_turn("female_scientist", "Today I finished the calculus homework and tomorrow I need to submit my thesis outline by noon.", "Logged. I will check on that thesis outline tomorrow.").ok, "store obligation turn")
	check(memory.append_turn("female_scientist", "My goal this month is to run five kilometres without stopping.", "A measurable target.").ok, "store goal turn")
	var notes := memory.get_notes("female_scientist")
	check(notes.size() >= 2, "durable notes extracted from player turns")
	var role_ctx := JSON.stringify(memory.build_context("female_scientist", "Hey Vale", "today plan obligation thesis goal"))
	check(role_ctx.contains("thesis outline") and role_ctx.contains("remembered_player_notes"), "role-guided RAG surfaces notes even on short greeting")
	# Friendship sensitivity tracking for the Envoy.
	check(memory.get_friendship_status("alien_suit") == "unknown", "friendship status starts unknown")
	check(memory.append_turn("alien_suit", "I have been feeling a bit tired lately, and honestly I don't really have any friends right now.", "I hear you, friend.").ok, "store no-friends turn")
	check(memory.get_friendship_status("alien_suit") == "no_friends", "no-friends statement recorded accurately")
	check(memory.append_turn("alien_suit", "I met up with my new friend Marco for coffee today!", "That sounds warm.").ok, "store new friend turn")
	check(memory.get_friendship_status("alien_suit") == "has_friends", "new friendship updates status to has_friends")
	# Daily check-in state and goal review cadence across days.
	check(not memory.has_seen_today("female_scientist", "2026-10-21"), "unseen before mark_seen_today")
	check(memory.mark_seen_today("female_scientist", "2026-10-21", true).ok, "mark_seen_today saves")
	check(memory.has_seen_today("female_scientist", "2026-10-21"), "seen on marked day")
	check(not memory.has_seen_today("female_scientist", "2026-10-22"), "unseen on next day")
	check(memory.days_since_goal_review("female_scientist", "2026-10-25") == 4, "days_since_goal_review computes day delta")
	# Long conversation with logical compaction and clause folding.
	for turn_idx in range(40):
		var u := "Session turn %d: today I worked on module %d and planned milestone %d." % [turn_idx, turn_idx, turn_idx]
		var a := "Noted progress on module %d." % turn_idx
		check(memory.append_turn("female_scientist", u, a).ok, "long conversation turn %d stored" % turn_idx)
	var after_long := memory.get_stats("female_scientist")
	check(after_long.recent_turns <= 6 and after_long.recall_entries <= 12 and after_long.pruned_entries > 0, "long conversation stays within recent and recall caps")
	var recalled_digest := JSON.stringify(memory.build_context("female_scientist", "module milestone", "today obligation plan"))
	check(recalled_digest.contains("Earlier:") or after_long.notes_count > 0, "logical pruning folds clauses into surviving digests and notes")
	check(memory.auto_compact_if_needed("female_scientist").ok, "auto_compact_if_needed succeeds")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	for name in directory.get_directories():
		_remove_tree(path.path_join(name))
	for name in directory.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
