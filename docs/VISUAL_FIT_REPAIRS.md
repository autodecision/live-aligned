# Character and scene fit repairs

The professor's coat has more room over the hips and a lower skirt weighted to
the thighs, blending back into the waist. Kestrel's blue forearm inset and vents
share the armour shell's local frame and forearm bone. The Envoy has a real V
opening, a shirt front built from quad strips, folded collar points, and a tie
shaped to sit against the shirt.

The top pagoda landing has a cedar and bronze guard with a continuous collision
barrier. The spiral exit remains open. The forecourt boulder is seated lower and
its lower shell reaches into the terrain across its whole footprint.

Saved editable sources:

- Characters: `/home/allister/Projects/mcp-for-blender/output/ps3_character_pack/ps3_character_lineup.blend`
- Artistic map: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Optimized map: `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`
- Standalone pagoda: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/north_pagoda.blend`

The existing character recipe, `build_characters.py` beside the character source,
contains the fit changes. `tools/repair_character_fit.py` refreshes those three
characters using the current materials and presentation. The scoped scene tools
are `tools/repair_pagoda_stair_guard.py` and `tools/ground_forecourt_rock.py`.
Backups are outside Git at
`/home/allister/Backups/live-aligned/visual-fit-20261014-235708`.

Runtime exports are the three `assets/characters/*.glb` files, the existing
`assets/north_pagoda.glb`, and `assets/forecourt_rock_grounded.glb`. The base map
GLB is preserved. Source checks confirmed the rock geometry and guard meshes
match in both saved maps; the standalone pagoda retains its sidewalk and window
infill. No Visual Lab profile or F6 preference is saved by the checks.

Validation:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/check_visual_fit.gd
godot --path . --script res://scripts/check_visual_fit.gd -- --capture
godot --headless --path . --script res://scripts/check_character_walking.gd
godot --headless --path . --script res://scripts/check_pagoda_walkable.gd
godot --headless --path . --script res://scripts/check_bridge_approaches.gd
```

`tools/validate_character_fit.py::validate()` runs in the saved character Blender
file after the runtime check exports poses. It applies the actual Godot skinning
matrices and casts 91,374 rays from the rear trousers toward the coat across
291 poses on flat ground and stairs facing both ways, including half-strength
walking and idle. All sampled rear points remain covered, and no lower-coat
triangle intersects the trousers. In-game front, profile and walking views
complement the geometry checks.

The landing guard stops the real player at three radii. Both pagoda flights pass
ascent/descent and room-perimeter checks. Sixteen bridge approach/crossing walks
pass. Full character circuits pass 220 simulated seconds. The boulder underside
has no positive gap across 6,373 terrain samples (maximum gap -0.181 m).

Screenshots and runtime pose reports are written to `/tmp/live-aligned-fit/`.
A persistent delivery copy is saved under
`/home/allister/Projects/live-aligned-previews/visual-fit-repairs-2026-10-15/`.

The October 15 follow-up removes the Envoy's separate rigid trouser crease/fold
tubes. These were attached to the thigh while the trouser mesh blended across
the knee, making the strips peel away during walking. The doctor now has simple
fitted lapels, curved pocket meshes with weights sampled throughout their
surface, fitted buttons/badge, upper-trouser waist blending, and front tails with
enough hinge room for a raised thigh. A gently raised rear hem clears the trailing
calf. Both revised characters are saved in the same lineup source and GLBs.

`tools/repair_character_fit.py::refresh(("alien_suit",))` can now rebuild only one
character. `scripts/check_character_details.gd` verifies the Reset position HUD
button through actual GUI mouse events and captures the clothing details. Use
`godot --path . --script res://scripts/check_character_details.gd -- --capture`.
Follow-up captures and reports are stored at
`/home/allister/Projects/live-aligned-previews/envoy-trousers-2026-10-15/`.
