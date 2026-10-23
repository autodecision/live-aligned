# Temple prop clearance and offshore colors

The loose `Fern_Pool_1` and `Fern_Pool_2` plants intersected the lower pool stonework. They are hidden in both editable maps and at runtime; the potted plants remain. The left stair planter moves 0.30 m inward and 0.35 m toward the forecourt. Low broad leaves are tipped upward, retaining their UVs and fixed attachment points. Their minimum pavement clearance is 8.28 cm; an exact triangle check finds no broad-leaf intersections with the stair, curb, or courtyard meshes. The existing shared repaired leaf export also updates the matching right stair and pool planter foliage.

`Vase_Stairs_Plinth` now sits on the clear upper terrace at Blender `(5.6, 5.9, 3.54855)`, away from the stairs and fountain. Its base has floor support, with no triangle intersections against the nearby stair/fountain architecture. Placement changes are applied after earlier site repairs using `assets/temple_clearance.json`.

The terrace return previously used a concave triangle collider whose underside caught a player landing on it. In the baseline reproduction, the player settled inside the beam at Y 0.962 and could move less than 4 cm in 90 movement ticks. It now uses continuous box collision with the top at Y 1.0. The original lower and upper rail segments receive matching solid collision. All three rail shapes follow their visible dimensions and preserve the water outlet. This is a physics repair in Godot; the visible rail and player controller are unchanged.

Nine offshore stacks, reefs, satellites and skerries use the supplied reference's blue/cyan/green/yellow/red palette. Broad blue fields cross warmer branching seams. Colors are artistic, with no thickness or analysis meaning. Vertex colors and a dedicated Blender material replace the plain white surfaces. Subdivision only adds color samples on existing triangles; the original runtime collision is retained.

## Sources and scoped export

Use Blender MCP to run `tools/repair_temple_clearance.py::build()` in:

- `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`

Then run `install()` in:

- `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`

This writes only `assets/offshore_spectrum.glb`, the existing `assets/stair_pot_leaves.glb`, and the placement/collision plan. Both maps were saved, reopened, and checked for identical edited mesh/color hashes and prop positions. No base-map export is needed. The new builder supersedes `repair_stair_pots.py` for the repaired foliage.

## Verification

- `godot --headless --path . --editor --import --quit`
- `godot --headless --path . --script res://scripts/check_temple_clearance.gd`: 10 rail jumps/landings/exits, including three jumps from the terrace onto the rail; eight player walks; all nine formations have blue, green, and red vertex colors; hidden ferns and supported urn verified.
- `godot --headless --path . --script res://scripts/check_temple_details.gd`: 14 two-way stair/temple walks, existing architectural collision retained.
- `godot --headless --path . --script res://scripts/check_character_walking.gd`: 800 simulated seconds for all three NPCs, no backward walking or recovery resets; scientist completed 16 stair circuits.
- `godot --path . --script res://scripts/capture_temple_clearance.gd`: inspect the cleared pool wall, planter, old and new urn sites, rail, and offshore colors in day and night light. It uses an unsaved preview and does not save graphics settings.

Evidence and reopened-source reports: `/home/allister/Projects/live-aligned-previews/temple-clearance-2026-10-18/`.

Affected-file backups: `/home/allister/Backups/live-aligned/temple-clearance-20261018/`.
