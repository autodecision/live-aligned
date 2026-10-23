# Character Personas, Sequential Daily Check-Ins, Face Zoom, and Memory Compaction

This document summarizes the character personality architecture, sequential full-speed daily check-in behavior, Skyrim-style dialogue face zoom, conversation wrap-up mechanics, and long-conversation RAG memory compaction.

---

## 1. Character Personas & Agendas (`scripts/ai/character_personas.gd`)

Each island resident has a distinct personality, system prompt, daily check-in agenda, and RAG role profile defined in `scripts/ai/character_personas.gd`:

### Check-In Order (`CHECKIN_ORDER`)
1. **Dr. Vale (`female_scientist`)** — *Lead Field Researcher*
   - **Personality**: Analytical, straightforward, skeptical, warm, and playfully witty.
   - **Purpose**: Keeps the player honest about daily obligations, concrete tasks, and commitments.
   - **Check-In Agenda**: Asks what the player has already done today and what they will do next, drawing on RAG memory to follow up on specific tasks, obligations, and goals mentioned previously.
2. **Kestrel-09 (`robot`)** — *Survey Automaton*
   - **Personality**: Stoic, composed, precise, and Spock-like; dryly logical and observant without being cold.
   - **Purpose**: Evaluates medium- and long-horizon planning and structural progress.
   - **Check-In Agenda**: Approaches after Dr. Vale has been seen that day. Asks about plans for the week and the future, and periodically (`goal_review_every_days = 2`) reviews larger life goals and progress on known objectives.
3. **The Envoy (`alien_suit`)** — *Off-World Traveler*
   - **Personality**: Far-out, gentle, cosmic hippy, and alien observer who speaks with unhurried warmth.
   - **Purpose**: Attends to emotional well-being, social connection, and broader life meaning.
   - **Check-In Agenda**: Approaches after both Dr. Vale and Kestrel-09 have been seen that day. Asks how the player has been feeling, asks how their friendships are going (adapting automatically via `get_friendship_status()`: if the player has indicated they do not have close friends, does not press them about it), and periodically (`goal_review_every_days = 3`) asks about broader life goals.

---

## 2. Sequential Full-Speed Approach & Navigation

### Runtime Navigation (`scripts/npc_navigation.gd`)
- `NPCNavigation` bakes a walkable `NavigationMesh` from static colliders on collision layer 1 (`AGENT_RADIUS = 0.25`, `AGENT_MAX_CLIMB = 0.5`, `AGENT_MAX_SLOPE = 55.0`), filtering out sea-floor, pond/pool, and raked zen-sand polygons so approaching characters route cleanly across islands and bridges.

### Full-Speed Check-In Locomotion (`scripts/ps3_character_npc.gd`, `scripts/ai/character_dialogue.gd`)
- `CharacterDialogue._update_daily_checkins()` queries `memory.get_next_unseen_character(Personas.CHECKIN_ORDER)` each frame.
- If the next character in sequence (`Dr. Vale` → `Kestrel-09` → `The Envoy`) has not yet spoken with the player on the current local calendar date (`YYYY-MM-DD`), that character enters `approaching_player` mode via `start_approach_player(player, npc_navigation)`.
- While `approaching_player` is active, `_target_walk_speed()` maintains full travel speed (`walk_speed * travel_speed_multiplier`, 3× normal walking speed) all the way to `approach_arrival_distance` (`2.15 m`) without slowing down inside the normal proximity radii (`5.0 m` / `2.5 m`).
- Upon reaching the player, the conversation opens automatically with a RAG-aware opening greeting (`Personas.build_opening_line(...)`) and records the daily check-in via `memory.mark_seen_today(...)`.

### In-Dialogue Posture & Gestures (`scripts/ps3_character_npc.gd`)
- While paused in conversation (`_dialogue_paused`), each character turns smoothly toward the player and animates a persona-specific talking pose:
  - **Dr. Vale**: Stows her palm pad, tilts her head inquisitively, and uses expressive one-handed gestures.
  - **Kestrel-09**: Holds an upright, symmetrical Spock-like posture with measured logical nods.
  - **The Envoy**: Breathes and sways gently with an open-handed, welcoming gesture.

---

## 3. Skyrim-Style Face Zoom (`scripts/player.gd`, `scripts/ai/character_dialogue.gd`, `scripts/ai/dialogue_ui.gd`)

- Whenever any dialogue opens (`CharacterDialogue.open_conversation`), whether initiated by a daily check-in or by pressing `E` near any character, `player.begin_dialogue_zoom(npc)` is triggered.
- The player camera smoothly interpolates (`DIALOGUE_ZOOM_SPEED = 6.5`):
  - **FOV**: Narrows from the default `68.0°` to `DIALOGUE_ZOOM_FOV = 38.0°`.
  - **Yaw & Pitch**: Rotates the player body yaw and head pitch to frame `npc.get_face_focus_position()` (`EyeLine` / head bone height) without displacing `player.global_position`.
- When the conversation closes (`CharacterDialogue.close_conversation`), `player.end_dialogue_zoom()` smoothly restores the pre-dialogue FOV and camera pitch.
- The backdrop shade in `scripts/ai/dialogue_ui.gd` uses a light alpha (`0.24`) so the zoomed character face remains clearly visible behind and above the dialogue sheet.

---

## 4. "Anything Else?" Continuation & Termination Mechanic (`scripts/ai/character_dialogue.gd`, `scripts/ai/character_personas.gd`)

Conversations track a three-stage phase state machine (`_conversation_phase`):
1. **`"agenda"`**: The character works through their daily check-in questions (minimum 2 player turns unless wrapped early). Once satisfied, the character asks if the player would like to talk about anything else and appends the `[[OFFER]]` tag (or matches `Personas.looks_like_offer(...)`), transitioning the phase to `"offer"`.
2. **`"offer"`**:
   - If the player replies in the negative (`Personas.is_clear_decline(player_text)`), the system instructs the character to give a brief in-character sign-off (`[[END]]`), sets `_close_after_reply = true`, and automatically closes the dialogue box and zooms out after `AUTO_CLOSE_DELAY_SECONDS` (`1.65 s`), queuing the next unseen character.
   - If the player brings up another topic or replies affirmatively, the phase transitions to `"open"`.
3. **`"open"`**: Free-form conversation continues for as long as the player wants. If the player later signals they are done or says goodbye (`is_clear_decline`), the character signs off with `[[END]]`, closes the dialogue, and zooms out.

---

## 5. Long-Conversation RAG Memory & Compaction (`scripts/ai/character_memory.gd`)

The persistent memory store (`user://character_memory.json`) supports extended conversations and multi-day progression without unbounded growth:

- **Structured Durable Notes (`notes`)**:
  - Automatically extracts and deduplicates up to `MAX_NOTES_PER_CHARACTER = 24` categorized notes (`obligation`, `plan`, `goal`, `feeling`, `friends`, `no_friends`) from player messages.
  - Tracks per-character daily check-in dates (`last_seen_date`, `last_goal_review_date`, `checkin_count`) under `checkin`.
- **Stem-Normalized Hybrid RAG Retrieval**:
  - `build_context(character_id, query, role_hint)` combines character-role focus terms (`ROLE_QUERY_TERMS`), stem-normalized 64-bucket hashed cosine similarity (`_vector`), keyword overlap, category bonuses, and recency weighting across both archived `recall` chunks and older `recent` turns outside the immediate tail window.
- **Multi-Tier Compaction**:
  - **In-Conversation Rolling**: `_roll_recent_into_recall` rolls oldest turn pairs into `recall` whenever `recent` exceeds `MAX_RECENT_MESSAGES = 14` **or** `MAX_RECENT_CHARS = 5600`.
  - **Neighbor-Merging Recall Compaction**: Before dropping low-value recall entries when `recall.size() > MAX_RECALL_ENTRIES` (`96`), `_prune_recall` folds unique clauses from the lowest-value entry into its closest lexical neighbor (`| Earlier: …` up to `MAX_CONSOLIDATED_RECALL_CHARS = 520`).
  - **Database Byte-Limit Guard**: `_save_result` monitors total serialized JSON bytes against `SOFT_STORAGE_BYTES = 196608` and `MAX_STORAGE_BYTES = 262144`, tightening recall and recent budgets automatically if the file approaches the cap.
  - **Live Compaction Trigger**: `auto_compact_if_needed` triggers rolling summary compaction during long active conversations when `recent` grows large or storage crosses `SOFT_STORAGE_BYTES`.

---

## 6. Verification Commands

Run the headless test suites from the project root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/check_character_memory.gd
godot --headless --path . --script res://scripts/check_character_dialogue.gd
godot --headless --path . --script res://scripts/check_character_world_context.gd
godot --headless --path . --script res://scripts/check_ai_providers.gd
godot --headless --path . --script res://scripts/check_character_walking.gd
```
