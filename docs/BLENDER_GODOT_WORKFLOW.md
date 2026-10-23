# Blender → Godot workflow

## Project boundaries and authoritative sources

The game is **Live Aligned**, currently at `/home/allister/Projects/live-aligned`. Some historical scripts still refer to `/home/allister/Projects/mediterranean_temple_walkable`; inspect those paths before running them. Blender MCP supports both the live editor and background Blender Python (`bpy`) tools.

| Role | Current local path |
| --- | --- |
| Artistic scene (user-requested original) | `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend` |
| Optimized editable companion | `assets/mediterranean_temple.blend` in this project |
| Actual base runtime map | `assets/mediterranean_temple.glb` |
| Original grass library | `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/original_grass.blend` |
| Active scoped grass export | `assets/original_grass.glb` |
| Asset builders, plans, reports, screenshots | `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/` |
| Runtime entry point | `scenes/main.tscn` |

**Do not use `assets/mediterranean_temple_improved.blend`: it is a stale historical copy.** Blender saves do not automatically update the game. Godot runtime fixes may also override imported map materials/positions/collision.

## Runtime composition

The original map is composed with `island_site_repairs.gd`, `island_bridges.gd`, `north_pagoda.gd`, `south_garden.gd`, `island_ground_cover.gd`, `animated_water.gd`, `scene_render_optimization.gd`, `visual_lab.gd`, `island_lanterns.gd`, and `day_night_cycle.gd`. Preserve initialization order in `main.tscn`.

Independent additions: `bridge_landing_banks.glb`, `island_bridges.glb` + plan, `coastal_lantern.glb` + positions, `north_pagoda.glb` + plan/cover, and the `south_garden*.glb` assets + plan. A full-map export MUST exclude **Island Bridges**, **Island Lanterns**, **Bridge Landing Banks**, **North Pagoda**, **South Koi and Zen Garden**, and **South Garden Koi Library**, including descendant collections and generated meadow points. Inspect actual collection names in the loaded scene, rather than relying only on these display names.

The large-island bridge approaches use a scoped `bridge_approach_terrain.glb` override. `island_site_repairs.gd` replaces the existing `Cliff_Terrain` mesh and collider before ground-cover/render initialization; the optimized base-map GLB is unchanged. Both editable sources contain the graded terrain directly. `bridge_approach_repairs.json` records affected props. The small-island bridge starts at Blender `(-1,-22,2.35)`, clear of the temple forecourt. Two coastal lamps were reseated outside its approaches.

The pagoda sidewalk has a separate continuous mesh in `north_pagoda.glb`, with flush landings for Main_North and North_South and a square, flared stair approach. `north_pagoda.gd` installs `pagoda_sidewalk_terrain.glb` into the existing Distant_Islands and Main_North landing-bank nodes, replacing their collision from the same geometry. `pagoda_sidewalk_repairs.json` records grounded props. The remaining pagoda structure and spiral stair collision are preserved.

Blender `(x,y,z)` maps to Godot `(x,z,-y)`. Blender Z yaw and Godot Y yaw have the same sign. Ground props with transformed mesh/base samples, not object origins. Account for the entire grass mesh footprint when clearing paths.

The expanded south island and its koi pond/sand garden are documented in `SOUTH_GARDEN.md`. Their terrain override follows the pagoda override, preserves every northern terrain vertex, and fits both independent south landing banks. `south_garden.gd` owns transparent pond water and fish animation separately from the existing thirteen water surfaces. Keep its day/night hook in `day_night_cycle.gd`.

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

Pagoda rebuild order: build from artistic source → run `tools/repair_pagoda_sidewalk.py::build_and_export()` through Blender MCP → `scripts/clear_pagoda_meadow.gd` → run the repair tool's `install_saved()` in both Blender sources → import → player/visual checks. The historical builder rewrites plans and cover data; the repair pass restores the continuous sidewalk and corrected riser UVs. Keep the cumulative grass-clearing mask. Current north path lamp is `Coastal_Lantern_North_05`, Blender `(74.75,45.1,5.201481323)`.

Pagoda floors: world Godot Y 6.5 / 10.9 / 15.3, center `(92,5.5,-64)`, yaw -0.88. Two 32-tread spiral flights, 1.97 m clear width, eight ceiling-mounted lamps. Collision plan triangles are Blender CCW; `north_pagoda.gd` reverses them for Godot physics. Do not remove that reversal.

## Checks and viewing

Run from the Godot project with the local asset pack present:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/check_pagoda_walkable.gd
godot --headless --path . --script res://scripts/check_pagoda_window_walls.gd
godot --headless --path . --script res://scripts/check_pagoda_sidewalk.gd
godot --path . --script res://scripts/check_pagoda_sidewalk.gd -- --views-only
godot --headless --path . --script res://scripts/check_bridge_landing_repairs.gd
godot --headless --path . --script res://scripts/check_bridge_approaches.gd
godot --path . --script res://scripts/preview_bridge_approaches.gd
godot --headless --path . --script res://scripts/check_day_night.gd
godot --path .
# Optional temporary pagoda entrance spawn:
godot --path . --script res://scripts/preview_north_pagoda.gd
```

Diagnostics/capture scripts still contain original-machine output paths; inspect/adapt them before running elsewhere. Some captures modify preview looks; never overwrite the user's active-look pointer during QA. `capture_visual_lab_saved.gd` writes that pointer and requires a backup. Keep screenshot windows focused so capture results are fresh.

## Rendering and settings to preserve

91 shared olive trees, 13 animated water surfaces, 43 coastal/bridge posts plus eight pagoda lamps. Last verified meadow count was 48,776; these are a dated baseline, not invariants for future edits. Shared tree leaf geometry stays visible; no sudden leaf LOD pop. Grass uses three original meshes, one shared opaque vertex-color material, and geometric silhouettes smoothed by the existing 2x/4x MSAA. Bust uses a small convex proxy. Local lamp lights have no shadow maps and fade by distance. Bridges use anisotropic wood and two sun-shadow cascades. Performance depends on hardware/view; no 60 FPS guarantee.

Grass updates: run `tools/build_original_grass.py` functions through Blender MCP to build the standalone library and scoped GLB, then install its meshes into both authoritative map sources. Preserve the legacy source-object/placement names, existing distribution points, and compact tuft scale (0.40). A base-map export is unnecessary. `scripts/check_original_grass.gd` verifies shared resources and placement counts; its windowed run additionally checks all MultiMesh transforms and captures ground-level views. The headless renderer does not retain MultiMesh transform buffers. Reopen the saved Blender files and check their meadow sources as well.

Bridge grading: `tools/reshape_bridge_approaches.py` supplies Blender MCP functions for sculpting/export, closing newly exposed underwater terrain edges, and installation into both saved sources. Build the independent bridges with the local `build_island_bridges.py` recipe after updating its sites, rebuild its far landing banks, then install. Preserve the scoped terrain library at `improvements/bridge_approach_terrain.blend`. Installation also clears/reseats the editable meadow point meshes to match runtime rows. The October 14 approach repair removed 485 obstructing plants; total runtime meadow count is now 48,291. Verify both large-island approaches and all far landings after changing a bridge direction, since a previously clear lamp can obstruct an outer lane.

The subsequent pagoda sidewalk repair cleared another 228 plants and reseated the affected meadow, leaving 48,063 runtime plants. Main path widths flare from 4.2 m at the bridge to 2.24 m along the route and 3.8 m at the pagoda steps. The branch from North_South is stored alongside the main route in `sidewalk_routes`; grass clearing checks both routes and their varying widths. `check_pagoda_sidewalk.gd` checks ground support across both routes and walks three lanes each way. Its windowed `--views-only` run captures both bridge joins, the junction, and the steps without modifying saved looks.

F6 switches Balanced/Performance. F7 opens Visual Lab; F9 compares Original. Day/night is 600 seconds (five minutes each, smooth transitions). Explicitly saved/loaded looks persist; unsaved previews do not. The display name is Live Aligned, but `config/custom_user_dir_name` intentionally retains `Mediterranean Temple Walkable` so existing graphics/active-look settings keep working. New saved profiles identify Live Aligned; old profile metadata remains loadable.

## Public repository boundary

Public source does not include the local asset pack, Blender scenes, backups, MCP editor add-on, or Godot cache. See `ASSETS.md`. Review credentials and asset rights before expanding that boundary. GitHub authentication remains in the system credential store, never in a remote URL or project file.

## Character fit, top stair guard, and forecourt rock

For the connected microscope optics and individually labelled reagent bottles,
see `LAB_PROP_DETAIL.md`. The scoped lab export adds three visual meshes and
retains the original bench and microscope collision.

For the sea-level shoreline aprons, rounded sea outflow, idle centrifuge display,
and rear lamp placement, see `COAST_OUTFLOW_REPAIRS.md`.

For the detailed temple pillars and podium, see `TEMPLE_ARCHITECTURE_DETAIL.md`.
Its scoped export substitutes three visual meshes while retaining the original
architectural collision and the optimized base-map GLB.

For the October 18 south-island arrival grades, western shoreline/lantern,
temple pool connection and scientist accessories, see `SITE_FINISH_REPAIRS.md`.
The additional scoped pool export replaces only three existing runtime meshes;
the survey reader is an independent hand-attached character prop.

See `VISUAL_FIT_REPAIRS.md` for the saved sources and validation. Character fit is
built in the existing character pack recipe, then exported individually with
`tools/repair_character_fit.py`. This does not replace locomotion or its rigs.

`tools/repair_pagoda_stair_guard.py` adds two small batched meshes to the existing
standalone pagoda and installs them in both maps. Its continuous 1.08 m barrier
protects the far radial edge of the top landing. Keep the incoming stair edge
open. The middle landing shares this edge with the ascending second flight, so a
horizontal guard across it would obstruct the stairs. Preserve the sidewalk and
window infill when exporting the landmark.

`tools/ground_forecourt_rock.py` seats `Large_Rock_Main_02` 0.65 m lower and closes
its upper shell down into the terrain, with 0.20 m embed. Its scoped GLB replaces
only that runtime mesh and convex proxy. Both editable maps contain the same
geometry and placement. Position overrides remain in `bridge_approach_repairs.json`.
The optimized `.blend` is kept out of Godot's direct importer with its local
`.blend.import` set to `keep`; runtime continues to use the existing base GLB
and the scoped additions.

## Garden composition and Kestrel arms

See `GARDEN_POLISH.md` for the paired stone lanterns, pagoda-matched paving,
terrace guard return, downward outfall UV transport, final tree clearances,
varied reagent shelves, and curved Kestrel arm shells. These use scoped assets;
the original optimized base GLB remains intact.

For the pool ferns, stair planter clearance, side urn, snag-free terrace rail
collision, and reference-colored offshore rocks, see `TEMPLE_CLEARANCE_REPAIRS.md`.
These use scoped exports and preserve the optimized base map.

For the carved roof/pediments, weathered spectrum stone, second fountain urn,
and rear tree-pair spacing, see `TEMPLE_CROWN_DETAIL.md`. Keep the crown as a
scoped visual export and explicitly export the named spectrum vertex colors.

For the seated cloth couch cushions, three furnished pagoda floors, and
continuous bowl spillway, see `PAGODA_INTERIOR.md`. Their three scoped exports
preserve the existing base map and landmark GLBs. Keep the furnishing collection
separate from structural landmark exports to avoid duplicating its runtime
instance.

The enclosed pagoda rooms have eight continuous window collision slabs installed
by `north_pagoda.gd`, blocking all sixteen lattice apertures with concealed
sill/lintel overlap. Keep these when changing the runtime structure. The window
check includes actual player jumps from sill height at straight and diagonal
angles. The open ground-floor veranda and entrance are separate from these walls.

## Ocean floor and submerged foundations

See `OCEAN_GROUND.md` for the rolling seabed and rounded submerged island aprons,
thirty pier extensions, nine fitted offshore rock roots, distant water horizon
and underwater boundary haze. `ocean_ground.glb` is independently
instantiated by `ocean_ground.gd`; exclude **Ocean Ground and Foundations** from
future base-map exports. `tools/build_seabed.py` uses the active
`offshore_spectrum.glb` silhouette, not an older buried apron. Both editable maps
now contain that active rock geometry, with backups retaining the former meshes.
Keep the independently exported rock asset and its existing runtime transforms.

The ocean-ground GLB requires mesh compression and generated LODs disabled to
retain its exact water-edge vertices across the distant ring. Keep its water
time synchronized with AnimatedWater, and preserve the day/night-aware
underwater overlay without overwriting saved environment settings.

The original sea and distant ring now share `ocean_horizon.gdshader`, including
world-space swells, distance-filtered ripples, depth color and shore foam. Rebuild
`assets/ocean_contact_field.exr` with `scripts/bake_ocean_contact_field.gd` after
changing coastal terrain, offshore rocks or pier foundations. Preserve its raw,
signed, lossless import settings. See `OCEAN_GROUND.md` for the bake and native
`check_ocean_surface.gd` checks. Surface shading changes alone need no Blender export.

The western pagoda beach continues below the water through the scoped
`pagoda_shore.glb` override. `north_pagoda.gd` uses that mesh for both appearance
and collision. Keep this override after rebuilding the pagoda; see
`PAGODA_SHORE.md` for source paths, the buried shoreline edges and movement checks.

The October 20 pagoda coast supersedes the western-toe-only patch with one
continuous north terrain surface and removes the old overlapping northern
Distant_Islands faces. SouthGarden calls `NorthPagoda.install_coastal_base()`
after its ground installation; preserve that order and refresh the retained
south geometry in `pagoda_shore.glb` if the south island changes. The historical
Main_North landing bank is hidden/disabled because this terrain includes its
upper surface. See `PAGODA_SHORE.md` and `tools/refine_pagoda_coast.py`; use the
new coast and sidewalk checks after rebuilding. Both full Blender sources now
contain 81,325 meadow points.


For the October 20 quality-preserving FPS changes, see `FPS_OPTIMIZATION.md`.
The two compact tree resources preserve all rendered triangles and LODs. Ocean
floor buffers separate visible shoals from guaranteed submerged geometry; the
full original collider remains active while deep rendering is hidden above
water. Regenerate these derived caches after changing their source tree/ocean
assets, and revisit the -5.56 m cutoff if wave amplitudes or sea heights change.
