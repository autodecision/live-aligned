# Visual Lab saved looks

Start the Live Aligned walkthrough and press **F7** (or release the cursor with Esc and click **Visual Lab**).

1. Choose a starting look. The six art-direction presets are inspired by Warframe, Zelda: Breath of the Wild, The Witcher 3, Control, Alien: Isolation, and Red Dead Redemption 2.
2. Adjust the **Color**, **Light**, **Atmosphere**, **Lens**, and **Style** tabs. Sliders, number fields, and individual reset buttons all update the scene live. Hover a control for an explanation. Dependent controls become available when their effect is enabled.
3. Hold **F9**, or the **Hold original** button, to compare with the original scene. **Look enabled** bypasses the whole treatment. **Reset** restores all original dimensions.
4. Name the look and click **Save look**. This writes a complete, readable JSON file in this folder. Saving the same name updates that file atomically. Different names keep separate looks.
5. Click **Copy path** and send that path to Codex when you want the configuration implemented. Copy is disabled for unsaved edits so the exported file matches the preview.

Use the saved-look dropdown and **Load** to recall a configuration. The last explicitly saved or loaded look restores on the next launch. Changes made after that remain an unsaved preview until you save again. Closing the panel keeps the current preview for this run.

Each JSON records all **40 dimensions**, the original preset inspiration, shader/format version, timestamp, the player viewpoint, and the graphics mode used as a reference. Loading a look preserves the current F6 graphics choice. **Also restore the saved viewpoint** is optional; loading normally keeps you where you are.

`coastal_gold_example.json` is a complete editable example. It is available in the saved-look dropdown and is not selected automatically.

To bring in a compatible JSON file, copy it into this folder and reopen the panel. **Open folder** shows the actual save location; a packaged build uses its user-data folder if the project folder is not writable.

The default Original look has no full-screen pass. Bloom, sharpening, illustration, and lens effects add work; the live FPS readout helps evaluate the tradeoff. Film grain and scanlines are intentional retro effects, and their controls can be set to zero for a clean image. The existing F6 quality switch remains available.

## Implementation references

The native Godot controls are in `scripts/visual_lab.gd`, the versioned profile definitions and validation are in `scripts/visual_lab_profiles.gd`, and the screen shader is `shaders/visual_lab.gdshader`. Lighting, sky, camera field of view, and haze use real scene properties. The remaining treatment is one optional screen pass beneath the HUD, using [Godot's screen-reading shader API](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html).

Profiles are original combinations of adjustable effects inspired by the named games' art direction. Full-screen bloom is a lightweight highlight halo suited to the current Mobile renderer. Shader controls do not change tree LODs, grass placement, water animation, the bust collider, or movement geometry.

## Island lighting and world clock

The world now follows a repeating **600-second cycle**: five minutes with the sun above the horizon, five below it. Dawn and dusk blend within those periods. A new session begins at dawn. Warm lanterns fade on around sunset and off after sunrise; cool moonlight keeps the islands readable at night.

In **F7 → Light**, the **World clock** slider and Dawn / Day / Dusk / Night buttons preview any point immediately. **Pause** holds the clock while you tune a look. The world continues cycling while the panel is open unless paused.

Lighting dimensions compose with the clock. Sun / moon intensity scales the current celestial light; peak sun elevation is its midday height; noon sun direction is its midday heading. Ambient fill, sky colors, haze, and all screen effects remain adjustable. F9 compares against the original treatment at the current time. Choosing a preset or loading a look does not reset the clock.

Newly saved profiles include `world_clock_reference` with the phase, running state, and duration, so the lighting conditions can be reproduced from the file you share. That reference is descriptive: loading a look or restarting the game does not automatically jump to its saved time.

The cycle is implemented in `scripts/day_night_cycle.gd`. The 43 posts use a shared `assets/coastal_lantern.glb`, positions in `assets/island_lantern_positions.json`, and `scripts/island_lanterns.gd`. Local lantern lights have no shadow maps and fade with distance; the visible lanterns and glowing bulbs remain present. The day/night animation runs in Godot. Both editable Blender scenes also contain the placed lantern models.
