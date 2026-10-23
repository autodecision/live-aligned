# Coast, outflow, idle instrument and rear lamp

The October 18 repair removes flat gridded terrain aprons that sat at the sea's
mean height and appeared as jagged beige strips between moving waves. Only
vertices below -3 m change; 11,415 upper terrain vertices remain exactly intact.
The former sea-level shelf is now below -6.29 m, safely below the lowest wave
trough. The existing `south_garden_terrain.glb` contains the updated terrain and
its unchanged two landing banks, with runtime collision rebuilt from that mesh.

The temple sea outflow is a closed, rounded volume with 49 oval cross sections,
a tapered width and visible depth. Its separate flowing shader animates small
surface folds and broken foam strands, with forty small GPU spray particles at
the impact. Irregular foam replaces the perfect concentric sea rings at this
outlet. All thirteen existing animated water surfaces and the continuous pool /
channel join are retained.

The instrument shown as a scale is `Lab_Centrifuge`: its static `3200` decoration
represented RPM. The idle display now reads `0000`. It remains editable text in
both source scenes, with a scoped mesh replacement for Godot. The original lab
builder's default has also been updated.

`Coastal_Lantern_Main_05` moves from the rear plaza edge to the grassy bank at
Blender `(-2, 18.75, 6.7770935)`, fitted to its entire base footprint. Its shared
mesh, pole collision and existing night light remain in use.

## Saved sources and exports

- Artistic source: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Optimized companion: `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`
- Garden terrain library: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/south_garden.blend`
- Existing scoped terrain export: `assets/south_garden_terrain.glb`
- New two-mesh export: `assets/coast_outflow_detail.glb`
- Builder: `tools/repair_coast_outflow.py`

Run `build_and_export()` through Blender MCP in the optimized companion, then
`install_saved()` in the artistic source. The garden library's
`SouthGarden_Distant_Islands` uses the same saved terrain mesh. No base-map export
is needed. Scoped backups are outside Git at
`/home/allister/Backups/live-aligned/coast-outflow-20261018`.

## Verification

- Reopened both maps: matching terrain and waterfall geometry hashes, `0000`,
  and matching rear lamp placement. Reopened garden terrain hash also matches.
- Waterfall: 1,960 vertices; zero boundary or non-manifold edges.
- Godot import and actual game captures: shoreline, front/side outflow, idle
  instrument, and rear lamp. No render or script errors in the final capture.
- `check_coast_outflow.gd`: zero flat triangles at sea level, all thirteen water
  surfaces animated, twenty-four lamp footprint support samples, four real player
  walks across the rear plaza.
- `check_site_finish.gd`: twelve bridge arrival lane walks, thirteen matching
  pool/channel seam vertices, retained textured column fragments.
- Original `assets/mediterranean_temple.glb` is unchanged.

Checks, saved-source reports, and before/after images:
`/home/allister/Projects/live-aligned-previews/coast-outflow-2026-10-18/`.
