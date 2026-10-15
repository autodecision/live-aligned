# Asset pack boundary

The public repository includes application code, shaders, scene definitions, and JSON placement/collision plans. It excludes all asset binaries, images, Blender files, and the optional local Godot MCP add-on. Their redistribution licenses have not been established for this repository; in particular, downloading GScatter vegetation does not itself establish permission to publish extractable source assets.

`local_asset_manifest.json` records paths, sizes, and SHA-256 hashes of the existing local assets, without contents, credentials, or download URLs. Restore them from your own authorized copy into the same paths before importing/running. No automatic download uses the owner's account. The manifest is an inventory, not a license grant or promise that every historical asset is still required.

Core runtime dependencies include `assets/mediterranean_temple.glb`, `gscatter_ground_cover.glb`, `olive_tree_render_lod.res`, `olive_tree_shadow_lod.res`, `temple_static_occlusion.scn`, `bust_collision_proxy.tres`, `bridge_landing_banks.glb`, `island_bridges.glb`, `coastal_lantern.glb`, `north_pagoda.glb`, and referenced textures. Editable Blender sources and their authoritative location are described in the workflow document.

Before publishing asset contents, establish provenance and exact redistribution terms, preserve attribution/license notices, and inspect embedded GLB/Blender data. Assets above GitHub's file-size limit would also require a deliberate LFS or release-pack strategy. No blanket open-source license is asserted over this mixed-provenance project.

The local `addons/godot_mcp` installation is optional and excluded. It remains on the owner's disk, but the editor plug-in is disabled in `project.godot` so a public checkout does not reference an absent plug-in. Re-enable locally in the editor when needed.
