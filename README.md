# Live Aligned

A first-person island exploration project in Godot 4: a Mediterranean temple and science lab, olive groves, flowing water, three illuminated bridges, and a three-storey pagoda with walkable spiral stairs.

Features include a ten-minute day/night cycle, performance modes, and a Visual Lab with adjustable color, lighting, atmosphere, lens, and style settings that can be saved as JSON.

## Run locally

Use Godot 4.7 (developed with 4.7.2), Mobile renderer. This public repository contains source and scene definitions; **the third-party/local asset pack is not included**, so a fresh clone cannot run the complete scene until those files are restored. See [asset requirements](docs/ASSETS.md).

```sh
godot --headless --path . --editor --quit
godot --path .
```

WASD / arrow keys move, Shift sprints, Space jumps, Esc releases the cursor and shows **Reset position**, which returns you to the start if you get stuck. F6 changes graphics quality, F7 opens Visual Lab, and F9 compares the original look. See [saved looks](shader_profiles/README.md).

## Development

Read [AGENTS.md](AGENTS.md) and the [Blender–Godot workflow](docs/BLENDER_GODOT_WORKFLOW.md) before scene edits. Blender is the editable geometry source; Godot owns runtime rendering, physics, lighting, and UI. A Blender save alone does not update the playable scene.

The local working directory retains its old `mediterranean_temple_walkable` name for compatibility. The game title is Live Aligned. Frame rate varies by hardware and scene; there is no fixed 60 FPS claim.

## Publication

Caches, backups, downloaded models/textures, Blender files, private settings, and MCP editor tooling are deliberately excluded. Asset hashes and paths are documented without distributing their contents. Public visibility does not grant a blanket license to third-party content; see [asset notes](docs/ASSETS.md).
