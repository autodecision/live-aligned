# Rounded temple shoreline and fuller island meadows — October 18, 2026

The narrow fin beside the main island's south bridge came from the abrupt join
between the beach extension and the protected bridge approach. The final pass
regrades 3,736 existing terrain vertices into a broad continuous slope. The
crest follows the inland elevation and falls toward the sea instead of rising
into a thin outward ridge. The bridge landing and all ground north of Blender
Y=-25.4 retain their geometry. The lower shore fades into the previous beach
before reaching the relocated offshore formations.

The previous planting pass excluded higher new land (north above 3.9 m and south
above 4.62 m). The new distribution covers those dry plateaus as well as the
slopes, using the existing original grass library and a jittered 0.28 m grid.
Spacing exclusions preserve established dense planting, solid props, paths,
pond and sand garden. Density fades into the lower beach. All roots follow the
exported triangle surface, with their bases embedded 0.028 m and their blades
aligned to its normal.

New tufts: main 3,211; north 15,788; south 6,960, totaling 25,959. Five older
upper-beach tufts were removed where the rounded grade became lower beach.
The final total is 78,185. Runtime still shares three grass meshes and one
material, grouped into 637 spatial batches. The geometry library, grass shaders,
MSAA behavior and saved user preferences are preserved.

## Saved files and scope

- Artistic source: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Optimized companion: `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`
- Terrain library: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/bridge_approach_terrain.blend`

All three files were reopened; their main-terrain vertex digest is
`738da92814323924f8862412407ed7e5066f25b5661f5c20396afb1172226f0d`.
Both full maps contain all 78,185 meadow points. Grass placement JSON copies
beside the source scenes are synchronized. Only `bridge_approach_terrain.glb`
is exported; the optimized base GLB and independent structures stay intact.
`assets/coastal_meadow.json` records counts and the final terrain digest.

`tools/refine_coastal_meadow.py` contains the Blender MCP build/install functions.
The installed refinement used `finalize_grade()` to reset only the main terrain
from the scoped pre-pass backup, apply the final grade, and reseat the affected
roots. It reads `/tmp/coastal-meadow-backup.txt`; point that file at the recorded
backup before reproducing this installed correction. `plant()` rejects already
installed new planting. Do not run the historical full-map exporter.

Backup: `/home/allister/Backups/live-aligned/coastal-meadow-20261018-174628/`.
Evidence: `/home/allister/Projects/live-aligned-previews/coastal-meadow-2026-10-18/`.

## Verification

- Godot import succeeds with no errors or warnings.
- `check_coastal_meadow.gd` verifies every new root against runtime terrain and
  performs six shoulder walks plus eight south-bridge walks, including full
  crossings in both directions. Its windowed run captures the reported coast
  and the new garden/pagoda grass coverage.
- `check_island_shore_slopes.gd` passes all twelve plateau/beach/seabed walks.
- `check_shore_planting.gd` passes six garden-corner/shoulder walks, the retained
  1,974 earlier coastal roots, all 25 corner support samples and all 41,435
  exposed rock-vertex checks. Colored rocks remain offshore.
- The windowed original-grass check verifies the shared resources, both MSAA
  modes, tree/water counts and all saved transforms.

The older `check_bridge_approaches.gd` also reported a Main_North threshold
assertion (gap -2.3 m). Its sampled north-bank vertices are outside this pass's
changed region and retain their pre-pass values. The current south crossing
is exercised directly by the new movement check; this pass does not alter the
north bridge or its landing.
