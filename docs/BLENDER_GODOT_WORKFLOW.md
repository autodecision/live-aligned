# Blender → Godot workflow

## Project boundaries and authoritative sources

The game is **Live Aligned**. The existing local folder is deliberately retained at `/home/allister/Projects/mediterranean_temple_walkable` to preserve build scripts and references. Blender MCP is an optional control interface; this pipeline has used background Blender Python (`bpy`), not a required live MCP connection.

| Role | Current local path |
| --- | --- |
| Artistic scene (user-requested original) | `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend` |
| Optimized editable companion | `assets/mediterranean_temple.blend` in this project |
| Actual base runtime map | `assets/mediterranean_temple.glb` |
| Asset builders, plans, reports, screenshots | `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/` |
| Runtime entry point | `scenes/main.tscn` |

**Do not use `assets/mediterranean_temple_improved.blend`: it is a stale historical copy.** Blender saves do not automatically update the game. Godot runtime fixes may also override imported map materials/positions/collision.

## Runtime composition

The original map is composed with `island_site_repairs.gd`, `island_bridges.gd`, `north_pagoda.gd`, `island_ground_cover.gd`, `animated_water.gd`, `scene_render_optimization.gd`, `visual_lab.gd`, `island_lanterns.gd`, and `day_night_cycle.gd`. Preserve initialization order in `main.tscn`.

Independent additions: `bridge_landing_banks.glb`, `island_bridges.glb` + plan, `coastal_lantern.glb` + positions, `north_pagoda.glb` + plan/cover. A full-map export MUST exclude **Island Bridges**, **Island Lanterns**, **Bridge Landing Banks**, and **North Pagoda**, including descendant collections and generated meadow points. Inspect actual collection names in the loaded scene, rather than relying only on these display names.

Blender `(x,y,z)` maps to Godot `(x,z,-y)`. Blender Z yaw and Godot Y yaw have the same sign. Ground props with transformed mesh/base samples, not object origins. Account for the entire grass mesh footprint when clearing paths.

## Safe edit sequence

1. Inspect the named object, its runtime overrides, and the relevant builder. Make scoped backups outside Git; preserve unrelated work and user settings.
2. For geometry edits, load the correct Blender file and edit/build through `bpy`. Save the artistic and optimized companion sources as appropriate. Runtime-only shaders/UI do not require Blender exports.
3. Export only the affected asset and update its JSON plan or instance data. Preserve existing optimized base-map meshes and shared resources. Historical `export_from_blender.py` / `create_updated_blend.py` are NOT a safe one-command rebuild of the current scene.
4. Import: `godot --headless --path . --editor --quit`. Run relevant checks below, inspect logs, and confirm the exact reported issue with in-game views. Do not claim a screenshot proves movement or that movement proves appearance.
5. Reopen saved Blender files when they changed; confirm source and runtime agree. Report exact saved paths and any FPS measurements, without claiming a fixed FPS across hardware.

## Existing local builder recipes

The improvements directory above contains the authoritative existing scripts and their sibling inputs. Run them there; they commonly resolve files relative to `__file__`. They are not a clean-room scene generator and depend on licensed assets and existing source scenes.

| Addition | Builder / installer in improvements directory |
| --- | --- |
| Three bridges | `build_island_bridges.py`, `install_island_bridges.py` |
| Coastal/bridge lamps | `install_island_lanterns.py`, `island_lantern_positions.json` |
| Landing banks / portable boulder materials | `build_bridge_landing_banks.py`, `install_bridge_site_repairs.py`, `sync_saved_site_positions.py` |
| Pagoda / north island / sidewalk | `build_north_pagoda.py`, `clear_pagoda_lamp_site.py`, `install_north_pagoda.py` |
| Saved pagoda check | `check_saved_walkable_pagoda.py` |

Pagoda rebuild order: build from artistic source → `scripts/clear_pagoda_meadow.gd` → install into both Blender sources → import → player/visual checks. The builder rewrites plans and cover data: rerun grass clearing after building. Keep its cumulative clearing mask. Current north path lamp is `Coastal_Lantern_North_05`, Blender `(74.75,43.75,5.379094696)`.

Pagoda floors: world Godot Y 6.5 / 10.9 / 15.3, center `(92,5.5,-64)`, yaw -0.88. Two 32-tread spiral flights, 1.97 m clear width, eight ceiling-mounted lamps. Collision plan triangles are Blender CCW; `north_pagoda.gd` reverses them for Godot physics. Do not remove that reversal.

## Checks and viewing

Run from the Godot project with the local asset pack present:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/check_pagoda_walkable.gd
godot --headless --path . --script res://scripts/check_bridge_landing_repairs.gd
godot --headless --path . --script res://scripts/check_day_night.gd
godot --path .
# Optional temporary pagoda entrance spawn:
godot --path . --script res://scripts/preview_north_pagoda.gd
```

Diagnostics/capture scripts still contain original-machine output paths; inspect/adapt them before running elsewhere. Some captures modify preview looks; never overwrite the user's active-look pointer during QA. `capture_visual_lab_saved.gd` writes that pointer and requires a backup. Keep screenshot windows focused so capture results are fresh.

## Rendering and settings to preserve

91 shared olive trees, 13 animated water surfaces, 43 coastal/bridge posts plus eight pagoda lamps. Last verified meadow count was 48,776; these are a dated baseline, not invariants for future edits. Shared tree leaf geometry stays visible; no sudden leaf LOD pop. Grass uses opaque short sward and alpha-to-coverage for taller plants. Bust uses a small convex proxy. Local lamp lights have no shadow maps and fade by distance. Bridges use anisotropic wood and two sun-shadow cascades. Performance depends on hardware/view; no 60 FPS guarantee.

F6 switches Balanced/Performance. F7 opens Visual Lab; F9 compares Original. Day/night is 600 seconds (five minutes each, smooth transitions). Explicitly saved/loaded looks persist; unsaved previews do not. The display name is Live Aligned, but `config/custom_user_dir_name` intentionally retains `Mediterranean Temple Walkable` so existing graphics/active-look settings keep working. New saved profiles identify Live Aligned; old profile metadata remains loadable.

## Public repository boundary

Public source does not include the local asset pack, Blender scenes, backups, MCP editor add-on, or Godot cache. See `ASSETS.md`. Review credentials and asset rights before expanding that boundary. GitHub authentication remains in the system credential store, never in a remote URL or project file.
