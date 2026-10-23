# Coastal planting and garden support — October 18, 2026

The shoreline slope pass lowered the southeast corner beneath the square garden
paving. `tools/finish_shore_planting.py` raises 327 existing south-terrain vertices
to support the east/south edge, adds a 0.9 m grassy shoulder, and feathers the
addition into the existing slope over 4.5 m. The square paving, pond, garden
furniture and northern terrain vertices retain their geometry.

There are 1,979 new slope-aligned grass tufts: 302 on the main island, 1,091 on
the north island, and 586 on the south island. Existing shoulder roots were
reseated where the soil rose. New roots use Blender's explicit triangle
tessellation, matching exported Godot collision on non-planar terrain quads.
The distribution retains existing grass, excludes paths and solid props, and
fades out before the lower beach. Runtime retains three shared meshes and one
shared opaque material; total placements are 52,231.

Six spectrum formations that overlapped the expanded land were moved offshore:
East_Headland_Stack, East_Reef, North_Reef, North_Satellite, South_Cove_Rock and
South_Satellite. The other three retain their positions. Final transforms are
in `assets/temple_clearance.json`; the existing runtime installer moves each
mesh together with its inexpensive collision. Geometry, weathering and approved
vertex colors are preserved. The southern formation clears the beach walking
corridor, and the existing sea-extension parameter now reaches Godot Z=110 m
so the relocated formation has water around its whole footprint.

## Saved sources

- Artistic map: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Optimized companion: `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`
- Garden terrain library: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/south_garden.blend`
- Shared terrain library: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/pagoda_sidewalk_terrain.blend`

All four files were reopened. Their south terrain has identical vertex hashes;
the two full maps contain all 52,231 meadow points and final rock transforms.
The pagoda structural library is preserved; its runtime meadow comes from the
separate placement JSON. The standalone garden retains its separate placement
inputs. All 964 unrelated optimized mesh geometries match the scoped backup.

Only `south_garden_terrain.glb`, `pagoda_sidewalk_terrain.glb` and
`offshore_spectrum.glb` are re-exported. Base-map, pagoda, garden furniture, fish,
main-terrain, bridge, character and original grass GLBs remain unchanged.

## Reproduction and verification

Run `build()` through Blender MCP in the optimized companion after restoring
this pass's scoped inputs; it rejects duplicate installation. `install()` copies
only the changed terrain, meadow points and rock transforms into the artistic
map, and terrain into the standalone garden. `finalize_roots_and_sites()` was
the installed-scene correction for exported triangle roots and the southern
beach corridor. Placement copies beside the source libraries are synchronized.

`check_shore_planting.gd` verifies 25 corner soil samples, all 1,979 new grass
roots, 41,435 exposed runtime rock vertices and six real player walks around
the corner and shoulder. The existing garden check passes 18 walks and 50,400
fish checks. The shoreline check passes all 12 plateau/beach/seabed walks.
The windowed grass check verifies all 52,231 saved transforms, shared resources,
both MSAA modes, 91 trees and 13 animated water surfaces. Captures use unsaved
Original/Balanced settings and preserve user preferences.

Evidence: `/home/allister/Projects/live-aligned-previews/shore-planting-2026-10-18/`.
Backup: `/home/allister/Backups/live-aligned/shore-planting-support-20261018-172433/`.
