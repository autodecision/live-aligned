# Ocean ground and foundations

The collidable seabed is one continuous rolling surface, replacing the former
vertical island skirts. Boundary samples from the six existing island/bank meshes
form overlapping, uneven sediment aprons that round corners and merge into a
low basin. The 1 m lattice has 86,427 vertices and 171,680 triangles. Elevation
varies from -12.01 to -5.48 m; every new apron stays below the -5 m ocean. Visible
land, coastlines, vegetation, bridges and landmarks retain their geometry.
Blender bounds remain X -96..200, Y -150..140.

Thirty limestone sleeves retain their original footprints and overlap the old
piers by 0.025 m. Their lower ends follow the new floor with at least 0.28 m embed.
Nine existing spectrum-rock roots are reseated in the new floor with 0.25 m embed.
The original offshore rock silhouettes, placements and reference colors remain.

A separate visual water ring continues the existing ocean to a distant horizon;
it adds no land or collision. Its inner vertices exactly match the delivered
runtime ocean boundary, including its stretched transform. Both ocean meshes
use the same shader and wave phase. The ocean-ground node processes after AnimatedWater to
keep their time uniforms synchronized. The existing thirteen animated surfaces
and all saved Visual Lab and F6 preferences remain intact.

Underwater rendering adds blue-green distance scattering, with red light fading
faster than green and blue. Far views converge to water haze before the finite
floor ends. Haze also increases near the playable ocean boundary. Immersion
blends across the waterline and follows the existing day/night daylight value.
Above water the overlay is hidden; the distant water ring uses the normal world
lighting and fog. No global environment or saved look is overwritten.

## Sources and rebuilding

- Optimized scene: `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`
- Artistic scene: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Scoped scene: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/ocean_ground.blend`
- Rock installation library: `improvements/ocean_rock_sources.blend`
- Runtime: `assets/ocean_ground.glb` and `scripts/ocean_ground.gd`
- Shaders: `ocean_sediment.gdshader`, `ocean_horizon.gdshader`, `ocean_atmosphere.gdshader`
- Contact plan: `assets/ocean_ground.json`, copied beside the scoped scene
- Exact existing water edge samples: `assets/ocean_horizon_edges.json` (Blender coordinates)
- Builder: `tools/build_seabed.py`, executed through Blender MCP

For an existing installation run `rebuild()` on the optimized scene and
`reinstall()` on the artistic scene. Fresh installations use `build()` and
`install()`. These replace only **Ocean Ground and Foundations**. Keep that
collection out of base-map exports. The optimized base GLB is preserved.
The scoped object library is written during build; reopen it, link its mesh
objects to the active scene collection, and save so it is directly viewable.

Godot import settings for `ocean_ground.glb`: set
`meshes/force_disable_compression=true` and `meshes/generate_lods=false`.
The kilometre-wide horizon otherwise quantizes its near edge by centimetres,
opening a bright seam. The builder preserves these settings when the local
import configuration exists. After restoring assets into a fresh project,
apply them before validation. Exact imported edge positions are checked.

Backups before this refinement:
`/home/allister/Backups/live-aligned/natural-ocean-20261019-005419/`.
The earlier vertical-skirt version is also recoverable there. The original
foundation backup is `seabed-foundations-20261019-002731` in the same parent.

## Validation

Run `godot --headless --path . --editor --quit`, then
`godot --headless --path . --script res://scripts/check_ocean_ground.gd`.
Run the same check without `--headless` for final day/night views. Preview
settings do not save user graphics preferences.

The runtime check verifies 2,915 floor rays, all 120 footing corners and original
sleeve overlaps, 2,590 rounded-apron contacts, all nine rock roots and 116 actual
rock mesh samples, eight buried retaining-wall corners, and 1,070 exact water
edge vertices. It rejects remaining vertical skirts and horizon collision.
Twelve actual seabed/slope walks and six bridge-deck walks pass in both directions.
Native views cover island slopes, piers, rock roots, opposing underwater map
edges, the above-water horizon, and underwater night lighting.

All three saved scenes were reopened. The final ocean geometry digest is
`76ffb7602a36dcbf04bb53012dfdb78557eb62fe6a506a03475e5c39b77d2123`.
The optimized scene preserves 978 other mesh objects and the artistic scene
1,259, including their transforms and topology. Both retain 78,185 grass points.
Evidence: `/home/allister/Projects/live-aligned-previews/natural-ocean-2026-10-19/`.

## Ocean surface refinement

`shaders/ocean_horizon.gdshader` now shades both the original Mediterranean_Sea
and the distant ring. Four crossing swells, warped small ripples and larger calm
patches replace the uniform fine-wave field. Pixel derivatives fade small detail
in distant views. Height above the bottom controls the deep-blue to turquoise
transition; broken foam washes toward the actual shores, rock bases and piers.
The existing waterfall impact remains. The other twelve fountain/pool surfaces
keep their existing materials and connected flows.

Water-side normals are selected using camera height rather than triangle winding:
the original sea and independently exported ring have different winding, and
using front-face flags introduces an otherwise geometrically sealed lighting
seam. Both ocean meshes have a 0.6 m cull margin and do not cast shadows. They
still receive the scene's bridge, island and rock shadows.

The local `assets/ocean_contact_field.exr` stores signed ground height in red and
distance to the waterline in green. It covers Godot X -64..176, Z -112..128 at
1024² resolution (0.234375 m per texel). It samples the final runtime collision
from Y -3.3 down to -20, avoiding bridge decks. Character bodies are excluded.
Keep its import lossless (`compress/mode=0`), HDR compression disabled, raw linear
channels (`process/hdr_as_srgb=false`), and `detect_3d/compress_to=0`. It is data,
not a color texture. No new raycasts or contact-field generation run during play.

Rebuild this field after shoreline, offshore-rock or footing geometry changes:

```sh
godot --headless --path . --script res://scripts/bake_ocean_contact_field.gd
godot --headless --path . --editor --quit
godot --path . --script res://scripts/check_ocean_surface.gd
```

This refinement changes Godot shading only; it needs no Blender mesh export.
The native check verifies signed imported data, 1,070 matching horizon vertices,
one shared shader and synchronized clocks, all thirteen animated materials, and
visible water movement at three viewpoints. Captures cover shores, rock wash,
open water, horizon, day/dusk/night, underwater and both F6 modes without saving
preferences. Evidence: `live-aligned-previews/ocean-surface-2026-10-19/final/`
beside this project. Source backups:
`/home/allister/Backups/live-aligned/ocean-surface-20261019-020314/`.
