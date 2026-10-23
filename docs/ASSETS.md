# Asset pack boundary

The public repository includes application code, shaders, scene definitions, and JSON placement/collision plans. It excludes all asset binaries, images, Blender files, and the optional local Godot MCP add-on. Their redistribution licenses have not been established for this repository; in particular, downloading GScatter vegetation does not itself establish permission to publish extractable source assets.

`local_asset_manifest.json` records paths, sizes, and SHA-256 hashes of the existing local assets, without contents, credentials, or download URLs. Restore them from your own authorized copy into the same paths before importing/running. No automatic download uses the owner's account. The manifest is an inventory, not a license grant or promise that every historical asset is still required.

Core runtime dependencies include `assets/mediterranean_temple.glb`, `bridge_approach_terrain.glb`, `pagoda_sidewalk_terrain.glb`, `original_grass.glb`, `forecourt_rock_grounded.glb`, the three `assets/characters/*.glb` rigs, `olive_tree_render_lod.res`, `olive_tree_shadow_lod.res`, `temple_static_occlusion.scn`, `bust_collision_proxy.tres`, `bridge_landing_banks.glb`, `island_bridges.glb`, `coastal_lantern.glb`, `north_pagoda.glb`, and referenced textures. Editable Blender sources and their authoritative location are described in the workflow document.

`bridge_approach_terrain.glb` is a scoped export of the existing island terrain after grading the two bridge approaches. It inherits the existing map's redistribution boundary; it is not a new public asset pack. `bridge_approach_repairs.json` records the scoped repair and prop positions. The original optimized base-map binary remains unchanged.

`pagoda_sidewalk_terrain.glb` similarly exports the existing Distant_Islands and Main_North bank after grading the pagoda sidewalk. It inherits the same local asset restrictions. `pagoda_sidewalk_repairs.json` records this repair; the continuous paving itself is exported in `north_pagoda.glb`. Both authoritative Blender scenes contain the same geometry directly.

## Lab prop detail

The detailed lab props require `assets/lab_prop_detail.glb`. Their editable label
atlas is `assets/textures/lab_reagent_labels.png`; the runtime GLB embeds it.
`tools/detail_lab_props.py` creates this geometry and label artwork procedurally,
without external models or downloaded textures. The generated binaries remain
local. See `LAB_PROP_DETAIL.md` for the source scenes and scoped export workflow.

## South island garden

The south island additionally requires `assets/south_garden.glb`,
`south_garden_koi.glb`, and `south_garden_terrain.glb`, with
`south_garden.json`. `tools/build_south_garden.py` creates the pond, three koi
varieties, sand garden, deck, benches, and stone lanterns from mathematical
geometry with fixed seeds and no third-party assets or images. That provenance
applies to the new garden geometry; its terrain export and retained map props
inherit the existing map restrictions. Generated binaries remain local. See
`SOUTH_GARDEN.md` for source paths, runtime order, and verification.

## Original grass

The active meadow uses three original Blender meshes: short sward, meadow tuft, and dry seed-head grass. `tools/build_original_grass.py` constructs every vertex, seed, blade silhouette, and color from mathematical shapes with fixed random seeds. It reads no asset library, scan, image, or third-party input. `assets/original_grass_manifest.json` records this provenance and mesh budgets. All three meshes share one opaque vertex-color material and require no textures. Existing F6 MSAA settings smooth their geometric edges.

The editable library is `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/original_grass.blend`. Both authoritative map Blender sources have the same replacement geometry. Historical `GScatter_*` object names and placement keys remain for compatibility; they now select original geometry. The compact meadow tuft is a scaled use of the same original mesh. Neither the runtime nor the current meadow inspection/clearing scripts require `gscatter_ground_cover.glb` or its textures. That retired library is preserved only in an external local backup.

The generator is public source; the generated GLB and Blender binaries remain local under the existing publication boundary. This provenance applies to the grass set only, not the rest of the map's mixed-provenance assets.

Before publishing asset contents, establish provenance and exact redistribution terms, preserve attribution/license notices, and inspect embedded GLB/Blender data. Assets above GitHub's file-size limit would also require a deliberate LFS or release-pack strategy. No blanket open-source license is asserted over this mixed-provenance project.

The local `addons/godot_mcp` installation is optional and excluded. It remains on the owner's disk, but the editor plug-in is disabled in `project.godot` so a public checkout does not reference an absent plug-in. Re-enable locally in the editor when needed.

`forecourt_rock_grounded.glb` contains only the existing forecourt boulder with its lower shell fitted into the hill. It inherits the map asset restrictions. Its runtime mesh and convex collision replace the original node, preserving references and the portable rock material. `forecourt_rock_grounding.json` records placement and underside sampling.

## Garden polish and terrace guard

`assets/temple_terrace_guard.glb` is a procedural return for the existing stone
railing and inherits its local limestone material boundary. The garden retains
its original generated geometry and uses the same existing floor tile image as
the pagoda sidewalk. `assets/tree_clearance_repairs.json` records final tree
positions; the existing shared tree assets are preserved. Kestrel’s rounded
arm geometry is generated in the existing local character recipe and included
in `assets/characters/robot.glb`. See `GARDEN_POLISH.md`.

`assets/offshore_spectrum.glb` contains the existing nine offshore formations
with artistic vertex colors inspired by the supplied reference. The existing
`stair_pot_leaves.glb` contains raised leaves. These local binaries inherit the
existing map asset boundary; `assets/temple_clearance.json` and the builder are
public source. See `TEMPLE_CLEARANCE_REPAIRS.md`.

`temple_crown_detail.glb` is a local scoped temple crown export, generated by
`tools/detail_temple_crown.py` using the established stone textures. It remains
outside public source. The same recipe updates the local `offshore_spectrum.glb`
with eroded geometry and explicit reference colors; retain the existing texture
license boundaries. Placement changes remain public JSON plans.

## Pagoda furnishings and couch cushions

`tools/furnish_pagoda.py` generates the original furnishings, cushion panels and
corded seams, woven cloth atlas and furniture wood texture. The companion
`tools/detail_pagoda_furnishings.py` builds the detailed bonsai, cabinet joinery,
and original inset walnut and bark textures; the landscape relief was removed.
`tools/detail_pagoda_books.py` generates varied bound volumes and draws the
original cloth, tooling, title, and medallion atlas for their spines.
The local assets are `pagoda_interior.glb`, `couch_pillows.glb`,
`textures/couch_pillow_weave.png`, `textures/pagoda_furniture_wood.png`,
`textures/pagoda_walnut_inset.png`, `textures/pagoda_bonsai_bark.png`, and
`textures/pagoda_book_bindings.png`.
`pagoda_interior.json` contains public placement and simple collision data.
`bowl_outlet_detail.glb` contains a scoped repair of the existing fountain bowl
and spillway, inheriting its existing stone material boundary. Generated binaries
remain local; no redistribution change is implied. See `PAGODA_INTERIOR.md`.


The FPS pass also uses `olive_tree_render_lod_compact.res`,
`olive_tree_shadow_lod_compact.res`, `ocean_seabed_deep_compact.res`, and
`ocean_seabed_shoals_compact.res`. These local render-buffer caches can be rebuilt
from the original authorized assets using the commands in `FPS_OPTIMIZATION.md`.
They remain excluded from public Git; JSON reports describe the transformation.
