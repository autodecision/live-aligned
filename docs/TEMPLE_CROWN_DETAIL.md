# Temple crown and coastal stone detail

The October 18 follow-up adds a carved stone crown to the existing temple and
weathering to the nine reference-colored offshore formations. The optimized base
map GLB is preserved. `tools/detail_temple_crown.py` runs through Blender MCP.

## Source and runtime

- Artistic source: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Optimized companion: `assets/mediterranean_temple.blend`
- Crown export: `assets/temple_crown_detail.glb` replaces only
  `Temple_Entablature` in `island_site_repairs.gd`; original collision stays intact.
- Offshore export: `assets/offshore_spectrum.glb` replaces the same nine meshes,
  preserving original broad collision. Stone geometry has eroded ledges and
  varied relief; projected rock grain and normals retain the blue-to-red spectrum.
  Export `Reference spectrum` explicitly by name so later material-node changes
  cannot silently drop the palette. Keep the albedo factor white; multiplying
  the colors by a dark stone texture obscures the approved colors.

The crown has stepped architrave fasciae, a triglyph frieze, dentils, layered
cornice moldings, triangular frames, original sun/olive reliefs on both pediments,
480 individual overlapping roof tiles, a ridge cap, and two restrained finials.
It reuses the established stone textures and keeps the existing column footprint.

## Corrected urn and rear trees

The reported urn is `Fountain_Offering_Vase`, a different object from the earlier
`Vase_Stairs_Plinth` repair. Its old mesh intersected the podium foundation and
terrace mesh. Its new Blender position is `(4.30, 5.40, 3.5476567)`; Godot reads
that placement from `assets/temple_clearance.json`. It clears the foundation and
steps and stands on the continuous upper terrace.

`Olive_Ridge_BG_2` was crowded against `Olive_Temple_Back_R`. It now stands at
Blender `(10.9, 18.5, 5.7015972)` on existing soil, with 7.21 m horizontal trunk
spacing. The shared tree meshes and original collision proxies are preserved.
`assets/tree_clearance_repairs.json` remains the final runtime placement authority.
The validation explicitly compares woody tree geometry against neighboring trees;
the earlier solid-obstacle audit excluded tree-to-tree intersections.

## Rebuilding and validation

Run `build()` in the optimized companion, then `install()` in the artistic source.
The saved pre-weathering vertex attribute makes offshore displacement repeatable.
Reopen both sources and call `report()` to compare crown/rock fingerprints, verify
urn clearance against nearby solids, and inspect woody tree intersections.

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/check_temple_crown.gd
godot --headless --path . --script res://scripts/check_temple_clearance.gd
godot --path . --script res://scripts/capture_temple_crown.gd
```

Captures use unsaved Original/Balanced preview settings and do not overwrite saved
Visual Lab looks or F6 preferences. Evidence is under
`/home/allister/Projects/live-aligned-previews/temple-crown-2026-10-18/after/`.
Backups precede these changes under
`/home/allister/Backups/live-aligned/temple-crown-20261018-061856/`.

Final checks: four two-way walks around the fountain urn, five base support
samples, fourteen temple stair/colonnade walks, and ten rail jump/landing/exit
trials passed. Reopened Blender sources match in crown and rock geometry,
reference colors, urn placement and rear tree placement. All 89 active trees
clear solid scene props in the full audit.
The final 800-second NPC route simulation also passed after the tree move.
