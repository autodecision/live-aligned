# South-island, pool and scientist repairs — October 18, 2026

The eastern garden lantern now clears the olive canopy. The west corner has a
wider grassy shoulder, with its lantern to the left when viewed from the garden
path. Both bridge thresholds flare to the full deck width. The arrival apron
uses continuous grades, replacing the old height clamp that creased the paving
at x=84.5. Its collision follows the same mesh. Grass is cleared from the widened
footprint and existing plants are reseated on the revised ground.
The four nearby coastal posts are seated across their full base footprints;
the third post moves just outside the widened apron to keep the paving clear.

The poolside column fragments have marble UVs, surface normals and worn edges.
The lower pool and outlet meet along thirteen shared edge samples at water
height 0.20 m. Their animation uses matching currents and bounds, avoiding a
moving seam. Godot compresses each imported mesh independently; corresponding
edge samples remain within 0.1 mm. Existing water hooks and thirteen surfaces
are retained.

Dr. Vale draws an original survey reader, raises it with her left hand, looks
down at its display, and stows it before walking. The reader follows the actual
hand bone. Its casing, screen, readings, graph and keys are original geometry.
Her ID card is relocated onto the breast of the coat, subdivided to follow its
curvature, and projected outside the actual subdivided cloth. Its printed
details retain their separate depth layers and follow the same skin weights.

## Saved editable files

- Artistic map: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Optimized map: `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`
- Garden library: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/south_garden.blend`
- Character lineup: `/home/allister/Projects/mcp-for-blender/output/ps3_character_pack/ps3_character_lineup.blend`
- Survey reader: `/home/allister/Projects/mcp-for-blender/output/ps3_character_pack/scientist_palm_pad.blend`

Scoped backups are in `/home/allister/Backups/live-aligned/site-finish-20261018`.
The optimized base runtime GLB is preserved. The two map sources were reopened;
terrain, banks, paving, fragments and water geometry fingerprints match.
All 6,735 northern terrain vertices match their respective pre-edit sources.

## Reproduction

`tools/repair_site_finish.py::build_and_export()` operates on the installed
optimized map. It exports the existing garden and terrain libraries plus
`assets/temple_pool_finish.glb`. Then run `install_saved()` in the artistic map,
and `tools/build_south_garden.py::save_standalone()` in a fresh optimized-map
read. `validate_saved()` checks each saved map. Apply this repair after the
historical garden/refinement builders if rebuilding those assets.

`scripts/island_site_repairs.gd` installs the three scoped pool meshes into the
existing runtime nodes. `scripts/animated_water.gd` unifies the pool/outlet
animation field. The garden runtime uses its existing mesh and collision hooks.

The local `build_characters.py` recipe beside the lineup contains the fitted
badge projection. Refresh only the scientist with
`tools/repair_character_fit.py::refresh(("female_scientist",))`.
`tools/build_scientist_palm_pad.py::build_and_export()` saves the independent
reader library and `assets/characters/palm_pad.glb`. Run it in a fresh background
read; it creates a standalone scene. `scripts/ps3_character_npc.gd` owns the
reader's draw/read/stow timing and bone attachment.

## Validation and previews

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://scripts/check_site_finish.gd
godot --headless --path . --script res://scripts/check_south_garden.gd
godot --headless --path . --script res://scripts/check_character_walking.gd
godot --path . --script res://scripts/capture_site_finish.gd
godot --path . --script res://scripts/check_scientist_accessories.gd -- --capture
```

The bridge check passes twelve full approach walks across three lanes in both
directions. The garden check passes fourteen routes, including four pond exits,
255 support samples and 50,400 fish checks. All three characters complete their
full circuits with no backward walking or unplanned recovery.

The scientist check verifies reader visibility, reading height, screen direction
and stowing, and exports 83 task/gait poses. Run
`tools/validate_scientist_accessories.py::validate()` in the reopened lineup:
71,878 probes confirm card clearance, with no card/coat intersections and a
minimum sampled gap of 12.8 mm.

Reports and before/after Godot screenshots are saved under
`/home/allister/Projects/live-aligned-previews/site-finish-2026-10-18/`.
The checks do not write the user's active look or graphics preferences.
