# Temple pillars and podium detail — October 18, 2026

The temple's twenty-four pillars now have twenty stopped flutes each, a gentle
shaft taper and swelling, fine drum joints, turned base rings, shaped capitals,
and eased square footings and abaci. The existing pillar locations and overall
height are preserved.

The formerly plain foundation has six staggered courses of fitted stone, small
recessed joints, eased block edges, and shallow socle/string courses. Each of the
three podium steps has jointed stone risers and a fine upper rim. New UV maps,
the existing local stone diffuse/roughness/normal images, and subtle stone tints
give the pillars and base readable surface detail.

## Saved editable sources

- Artistic scene: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Optimized companion: `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`

Both saved files were reopened and their three detailed meshes have matching
world-space vertex/topology hashes. The artistic scene keeps its original names
without the optimized companion's `-col` suffix.

The builder is `tools/detail_temple_architecture.py`. Run `build_and_export()`
through Blender MCP in the optimized companion, then `install_saved()` in the
artistic source. The recipe stores the recovered original pillar centers for
repeatable builds. Backups of both original scenes and the affected integration
script are under `/home/allister/Backups/live-aligned/temple-detail-20261018/`.

## Runtime integration

`assets/temple_architecture_detail.glb` contains only the colonnade, stylobate,
and foundation. `island_site_repairs.gd` substitutes their existing runtime
meshes and applies the matching Blender stone tints and anisotropic filtering.
The original continuous walking collision and cheap architectural proxies stay
in place. No detail collision, new map nodes, or duplicate bridges/lamps are
installed. This adds no independent per-frame script processing.

The three meshes contain 134,688, 26,028, and 32,076 triangles respectively,
batched into eight material surfaces. These are visual meshes; their triangles
are not used to rebuild player collision. The original base-map GLB still has
SHA-256 `9f73360bbdcb1da33ad6ca75b971950fe9be04848291b14ba5ed3e303417f254`.

## Verification

- Godot editor import and windowed runtime captures completed without errors.
- `godot --headless --path . --script res://scripts/check_temple_details.gd`
  passed fourteen player walks: three stair lanes converging through the
  original central pillar gap, the front porch, doorway/interior, and both long
  colonnade passages, in both directions.
- All three architectural collision resources and local transforms match the
  original base-map scene. All eight new material surfaces have UVs, diffuse
  maps, and normal maps.
- Both saved Blender scenes match the scoped export build's geometry hashes.

Before/after captures, source checks, build statistics, and the runtime report
are under `/home/allister/Projects/live-aligned-previews/temple-detail-2026-10-18/`.
Reproduce current views with `godot --path . --script res://scripts/capture_temple_details.gd`.
The capture uses the unsaved Original Visual Lab preset and does not change
the saved active-look pointer.

The new geometry is procedural; retained local stone images inherit the
existing asset boundary. The GLB and Blender files remain local binaries.
