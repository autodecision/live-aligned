# Asset pack boundary

The public repository includes application code, shaders, scene definitions, and JSON placement/collision plans. It excludes all asset binaries, images, Blender files, and the optional local Godot MCP add-on. Their redistribution licenses have not been established for this repository; in particular, downloading GScatter vegetation does not itself establish permission to publish extractable source assets.

`local_asset_manifest.json` records paths, sizes, and SHA-256 hashes of the existing local assets, without contents, credentials, or download URLs. Restore them from your own authorized copy into the same paths before importing/running. No automatic download uses the owner's account. The manifest is an inventory, not a license grant or promise that every historical asset is still required.

Core runtime dependencies include `assets/mediterranean_temple.glb`, `bridge_approach_terrain.glb`, `pagoda_sidewalk_terrain.glb`, `original_grass.glb`, `olive_tree_render_lod.res`, `olive_tree_shadow_lod.res`, `temple_static_occlusion.scn`, `bust_collision_proxy.tres`, `bridge_landing_banks.glb`, `island_bridges.glb`, `coastal_lantern.glb`, `north_pagoda.glb`, and referenced textures. Editable Blender sources and their authoritative location are described in the workflow document.

`bridge_approach_terrain.glb` is a scoped export of the existing island terrain after grading the two bridge approaches. It inherits the existing map's redistribution boundary; it is not a new public asset pack. `bridge_approach_repairs.json` records the scoped repair and prop positions. The original optimized base-map binary remains unchanged.

`pagoda_sidewalk_terrain.glb` similarly exports the existing Distant_Islands and Main_North bank after grading the pagoda sidewalk. It inherits the same local asset restrictions. `pagoda_sidewalk_repairs.json` records this repair; the continuous paving itself is exported in `north_pagoda.glb`. Both authoritative Blender scenes contain the same geometry directly.

## Original grass

The active meadow uses three original Blender meshes: short sward, meadow tuft, and dry seed-head grass. `tools/build_original_grass.py` constructs every vertex, seed, blade silhouette, and color from mathematical shapes with fixed random seeds. It reads no asset library, scan, image, or third-party input. `assets/original_grass_manifest.json` records this provenance and mesh budgets. All three meshes share one opaque vertex-color material and require no textures. Existing F6 MSAA settings smooth their geometric edges.

The editable library is `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/original_grass.blend`. Both authoritative map Blender sources have the same replacement geometry. Historical `GScatter_*` object names and placement keys remain for compatibility; they now select original geometry. The compact meadow tuft is a scaled use of the same original mesh. Neither the runtime nor the current meadow inspection/clearing scripts require `gscatter_ground_cover.glb` or its textures. That retired library is preserved only in an external local backup.

The generator is public source; the generated GLB and Blender binaries remain local under the existing publication boundary. This provenance applies to the grass set only, not the rest of the map's mixed-provenance assets.

Before publishing asset contents, establish provenance and exact redistribution terms, preserve attribution/license notices, and inspect embedded GLB/Blender data. Assets above GitHub's file-size limit would also require a deliberate LFS or release-pack strategy. No blanket open-source license is asserted over this mixed-provenance project.

The local `addons/godot_mcp` installation is optional and excluded. It remains on the owner's disk, but the editor plug-in is disabled in `project.godot` so a public checkout does not reference an absent plug-in. Re-enable locally in the editor when needed.
