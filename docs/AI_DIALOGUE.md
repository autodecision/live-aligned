# Character conversations

All three island characters can use a player-selected AI model. Walk within 3.2
metres with a clear line of sight and press **E**, or use the **Talk** button.
**AI settings** at the top right and **F8** open model and memory settings.
Close or **Esc** returns to the world. Player movement and the active character's
route pause while talking; their existing route state resumes on close.

Conversation and settings windows use classic RPG-inspired blue gradients,
thin silver frames, square corners, and warm white text. Both windows stay
centered horizontally and vertically in the available viewport, including the
space above a software keyboard. Message frames fill the centered transcript;
text stays left-aligned for reading. Short viewports retain the compact composer.

The conversation sheet accepts plain text. **Enter** sends; **Shift+Enter** adds a
line. **Stop** cancels an in-flight request. **Retry** retries the last failed or
cancelled prompt without duplicating it in saved memory. Changing character or
closing cancels the pending reply. Failed, empty, cancelled, and stale replies
never become saved exchanges.

## Character Personalities, Face Zoom, and Daily Check-ins

Whenever any conversation opens (whether initiated by a daily check-in, pressing **E**, or clicking **Talk**), the camera smoothly zooms into the active character's face in a Skyrim-style close-up while the character turns to face the player with personality-specific posture and gestures. Closing or finishing the conversation smoothly zooms the camera back out to the player's normal field of view.

Each day, the three characters check in with the player sequentially, approaching at full travel speed (`walk_speed * travel_speed_multiplier`, without slowing down when close):

1. **Dr. Vale (`female_scientist`) — First Daily Check-in**:
   - **Personality**: Analytical, straightforward, skeptical, and fun.
   - **Purpose**: Helps ensure the player is living up to their obligations and goals in life.
   - **Check-in flow**: Approaches the player at full speed if she has not seen them that day, zooms into her face, and opens dialogue asking what they have done today and what they will do next while drawing on her RAG memory and extracted notes to follow up on past commitments. When the check-in wraps up, she asks if the player would like to talk about anything else. A negative reply ends the conversation and zooms out; otherwise the conversation continues until the player ends it.
2. **Kestrel-09 (`robot`) — Second Daily Check-in (after Dr. Vale)**:
   - **Personality**: Stoic, robotlike, and logical in the manner of Spock.
   - **Check-in flow**: After the player finishes speaking with Dr. Vale, if Kestrel-09 has not spoken to the player that day, he approaches next at full speed, zooms into his face, and asks about the player's plans for the week and the future. Periodically he also asks about the player's larger goals and progress on goals he knows about in general, then asks if the player would like to talk about anything else using the same termination/continuation mechanic.
3. **The Envoy (`alien_suit`) — Third Daily Check-in (after Kestrel-09)**:
   - **Personality**: Far-out, gentle, hippy-like alien traveler.
   - **Check-in flow**: After Kestrel-09, if the Envoy has not spoken to the player that day, he approaches at full speed, zooms into his face, and asks how the player has been feeling and how their friendships are going (if they have friends; if the player's memory indicates they do not have friends, he does not bother them about friendships), and occasionally asks about broader goals in life before offering to talk about anything else with the same termination/continuation mechanic.

## UI Color Themes

Live Aligned includes 12 UI color themes covering the full ROYGBIV spectrum plus
popular alternative palettes. Themes dynamically update conversation sheets,
settings dialogs, Visual Lab panels, and the player HUD in real time:

- **ROYGBIV Themes**:
  - **[R] Ruby Red**: Deep crimson and rich ruby wine with vivid rose highlights.
  - **[O] Sunset Amber**: Warm terracotta and glowing sunset amber inspired by Mediterranean twilight.
  - **[Y] Solar Gold**: Radiant golden sunshine with rich antique bronze and warm amber undertones.
  - **[G] Emerald Jade**: Lush botanical jade and deep pine forest with luminous mint accents.
  - **[B] Classic Cobalt**: The original nautical cobalt gradient with silver bevels and azure accents.
  - **[I] Midnight Indigo**: Deep nocturnal abyss and celestial twilight with electric periwinkle glow.
  - **[V] Amethyst Violet**: Velvety imperial plum and crystalline amethyst with royal orchid radiance.
- **Popular Themes**:
  - **★ Cyberpunk Neon**: High-contrast dark synth aesthetic with electric hot magenta and cyber cyan.
  - **★ Obsidian Monochrome**: Minimalist stealth dark theme with charcoal glass and pure titanium highlights.
  - **★ Sakura Quartz**: Elegant cherry blossom blush, warm quartz rose, and delicate pastel contrast.
  - **★ Arctic Frost**: Scandinavian polar night slate with crisp glacial ice cyan highlights.
  - **★ Sunset Synth**: Retro-futuristic dusk with deep purple shadow, sunset gold, and neon pink.

### Switching Themes
1. **AI Settings → Appearance**: Choose any theme from the dropdown, preview its color swatches and sample chat bubble, or use the **◀ Prev** and **Next ▶** buttons.
2. **Visual Lab (F7) → Style tab**: The top of the Style tab features the **UI COLOR THEME** selector and description.
3. **F10 Shortcut**: Press **F10** at any time during gameplay or while in conversation to instantly cycle to the next theme.
4. **Persistence**: Selected UI theme preferences are automatically saved to `user://ui_theme.json` and restored across game launches.

## Model setup

1. Open **AI settings → Models**. Choose a provider and supply its exact model ID,
   or use **Discover models**. Local Ollama and LM Studio endpoints are supported.
2. Enter an API key if needed, then **Save profile**. Keys remain only in this
   application's session; they must be entered again after restart. A change to
   endpoint, provider, transport, authentication, or OAuth registration invalidates
   the old session credential.
3. **Use this as the default** chooses the shared fallback. In **Characters &
   memory**, choose a character and assign a different profile, or **Use default**.
   Assignments do not merge memories.

Custom endpoints offer Chat Completions, Responses, or Anthropic Messages API
formats. Each profile also exposes the maximum reply tokens and request timeout.
Remote endpoints require HTTPS; unencrypted HTTP is restricted to loopback.
Requests may incur charges under the chosen provider account.

**Nous Portal → Existing Hermes session** has an explicit desktop-only **Use
Hermes session (Nous)** button. This imports an eligible cached Nous inference token (`agent_key` or access token) only
when clicked. Sign into Hermes separately first and re-import after expiry. The
game does not run Hermes, silently inspect its credentials, or share its refresh
token. Mobile uses API-key authentication instead.

Custom OAuth device sign-in requires a provider-approved public client ID, device
authorization URL, token URL, and scopes with inference access. This is a generic
protocol integration; it does not imply that any named provider supplies a public
Live Aligned registration. The sign-in code and progress remain visible at the
bottom of settings. **Cancel sign-in**, changing profile, or closing settings
invalidates pending results. Tokens remain in session memory.

## Independent, bounded memory

Stable IDs are `alien_suit` (The Envoy), `female_scientist` (Dr. Vale), and `robot`
(Kestrel-09). Their separate local files persist complete successful pairs. Recent
exchanges and word-matched older excerpts provide bounded context for each request.
Only the selected character's private dialogue context, the current prompt, and a
shared public world snapshot go to its selected provider. Other characters' private
memories are never read for that request. Plain-text memory is not encrypted. No private bot memory or persona was
copied from the reference Discord bot.

The implementation takes the reference bot's complete-turn persistence and bounded
retrieval pattern, using portable Godot storage. It does not require Python,
Chroma, Hermes, or a vector database at runtime. Recall matches words; compaction
keeps extracts, so this is neither unlimited memory nor learned semantic recall.
See [character memory details](CHARACTER_MEMORY.md) for limits and pruning.

The default total budget is 128 MiB, including a 1 MiB staging reserve. Each
character has a maximum 1 MiB snapshot. Settings expose total budgets up to 2 GiB,
current usage, manual compaction, and confirmed character-specific deletion.
Reducing a budget with stored data requires confirmation because old recall or entire oldest character memories may
be removed. Limits persist with the non-secret model settings.

The live transcript separately caps itself at 48 messages and 16,000 characters
per message. The input is capped at 8,000 characters; stored messages and prompt
context have their own smaller memory limits. Model text uses plain `Label`
controls: it cannot execute markup, links, commands, or game actions.

## Live world awareness

Each request and retry receives a fresh, bounded snapshot of the player, the
speaking character, and all three characters' live positions. Dr. Vale can answer
where Kestrel-09 is even when Kestrel is out of sight. The snapshot uses the
positions at the instant the request starts; characters can move while a model
answers. It is explicitly authoritative over location claims in older dialogue.

Locations use named runtime landmarks: the temple interior, altar, forecourt,
central stairs courtyard, lower pool, fountain, all three bridges, the north
pagoda entrance and floors, and the south garden pond, sand garden, timber deck,
and perimeter path. Mesh bounds, installed collision, and the runtime placement
plans anchor these names; bridge proximity uses the entire deck path. North is
Godot -Z and east is +X. Reported distances are approximate straight-line metres,
with elevation differences, and are not walkable route instructions across water.

The snapshot reports motion or conversation pause without inventing an activity
from an NPC's retained route state. Missing characters or map anchors are marked
unknown. It adds no persona, control of characters, or access to their thoughts or
private conversations. The snapshot is capped at 6,500 characters and eight live
characters. It is transient system context and is never written to character
memory; successful conversation text is still saved by the existing pair policy.

## Files and verification

The controller is `scripts/ai/character_dialogue.gd`; the conversation and settings
views are `dialogue_ui.gd` and `ai_settings_ui.gd`. Provider transport, credentials,
registry, memory, and `character_world_context.gd` are independent modules in the same folder. The scene adds
one CanvasLayer. Player and NPC changes only add scoped dialogue pause hooks.
Visual Lab and dialogue modals are mutually exclusive while dialogue is active.
No Blender assets or runtime map exports are needed.

State lives under the project's existing `user://ai/` directory, retaining the
legacy custom user-data directory. `model_settings.json` contains profiles,
assignments, and memory limits, never keys. `memory/` contains bounded character
snapshots. Keys and sign-in tokens remain in the process until exit.

Run the controller integration check with isolated user data:

```sh
XDG_DATA_HOME=/tmp/live-aligned-dialogue-xdg godot --headless --path . --script res://scripts/check_character_dialogue.gd
XDG_DATA_HOME=/tmp/live-aligned-dialogue-xdg godot --path . --script res://scripts/check_character_dialogue.gd -- --capture
XDG_DATA_HOME=/tmp/live-aligned-world-context-xdg godot --headless --path . --script res://scripts/check_character_world_context.gd
```

The check loads the actual map, uses an injected asynchronous deterministic model
stub, and writes a report and viewport captures to `/tmp/live-aligned-dialogue-check/`.
It exercises proximity, E and Talk, pause/resume, profile selection, isolation,
failure/retry/cancel, stale response rejection, transcript bounds, and composer
reachability. Desktop, portrait, short landscape, and a simulated remaining
keyboard viewport are checked. These captures do not certify a physical mobile
keyboard or an Android/iOS build. Provider transport and memory checks are separate;
no real paid API call is needed for the checks.

The world-context check loads the real map and verifies its named anchors and
roster, relocated Kestrel positions in Dr. Vale's outgoing request, retries and
transport waits, cardinal directions, missing nodes, context bounds, private
memory isolation, and absence of the transient snapshot from saved memory. Its
mock request report and sample snapshot go to `/tmp/live-aligned-world-context-check/`.

For an Android export, enable the **INTERNET** permission in the Godot export
preset. The native HTTP client is portable, but physical Android/iOS builds,
soft keyboards, provider accounts, and platform signing/export setup have not
been tested by this desktop integration check.
