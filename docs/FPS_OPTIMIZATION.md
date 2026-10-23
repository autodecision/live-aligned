# FPS optimization — October 20, 2026

The delivered changes preserve the rendered geometry and existing graphics
settings. They remove unused tree-buffer vertices and skip only ocean-floor
geometry that the opaque water fully conceals.

## Changes

`scene_render_optimization.gd` loads two compact tree resources. The visible mesh
retains all 39,959 triangles, its original materials, every native wood LOD and
the complete canopy without distance LODs. Shared render vertices fall from
228,041 to 70,312; shadow vertices fall from 228,041 to 24,742. The builder copies
packed attribute bytes and remaps indices, preserving triangle order and LOD
thresholds. Native before/after images verify the unchanged result.

`ocean_ground.gd` partitions the original 171,680 seabed triangles into 170,086
deep triangles and 1,594 potentially exposed shoal triangles. Positions, normals,
UVs and materials are retained. Shoals remain visible through wave troughs. The
deep floor, submerged rock roots and pier sleeves are hidden only above water.
They return before the camera reaches the highest possible wave crest. The full
original seabed collider stays active at every camera height.

The visibility cutoff is -5.56 m: the original sea's -0.16 m trough plus four
swells totaling 0.38 m cannot expose geometry below it. The camera restoration
threshold is -4.4 m, above the possible -4.46 m crest. If sea geometry or swell
amplitudes change, revisit these bounds and regenerate the partition.

Tree placements, grass density, leaf visibility, materials, sun shadows,
anisotropic filtering, graphics presets, saved preferences and source Blender
geometry are unchanged. These resources are derived render-buffer caches; no
Blender export or geometry-authoring change is needed.

## Measurements

Measured with Godot 4.7.2 Mobile/Vulkan on this AMD Radeon Graphics (RADV RENOIR),
1280×720 output, 65° FOV, VSync disabled. Balanced retains native scale and 4× MSAA;
Performance retains its existing 0.75 scale and 2× MSAA. Each paired measurement
warms for one second and samples for four seconds. Before/after order alternates
between views, within one process. Actors, lighting phase and water time are
held fixed to isolate rendering cost. These are local rendering measurements,
not an FPS guarantee for every device or gameplay state.

| View | Balanced FPS | Gain | Performance FPS | Gain |
| --- | ---: | ---: | ---: | ---: |
| meadow | 25.7 → 30.2 | +17.4% | 39.3 → 44.6 | +13.6% |
| temple | 23.2 → 26.5 | +14.3% | 33.1 → 38.1 | +15.0% |
| laboratory | 43.7 → 56.6 | +29.5% | 45.5 → 60.2 | +32.2% |
| water | 27.4 → 30.0 | +9.4% | 38.1 → 41.2 | +8.2% |
| pagoda coast | 31.7 → 32.9 | +3.7% | 66.4 → 74.7 | +12.6% |
| garden | 37.8 → 42.9 | +13.3% | 57.7 → 69.6 | +20.5% |
| pagoda arrival | 51.3 → 56.1 | +9.2% | 89.2 → 97.5 | +9.3% |

The median per-view gain is about 13% in each preset. GPU timings also improve.
`paired/report.json` contains the raw timings and draw/primitive counters;
`paired/comparison.json` summarizes them. The always-rendered native SubViewport
uses one explicit render submission per frame. This avoids timing CPU-only
frames when the desktop occludes the benchmark window. Initial `baseline` and
`before` runs were invalidated for that reason; their reports say so. Use the
paired measurements above.

## Quality and behavior checks

All 32 native A/B pairs cover both presets, dusk, night and three waterline/
underwater camera heights at four water times. No pixel changes by more than
3/255 in any channel; the largest mean error is 0.0000011/255. Most pairs are
pixel-identical. The first waterline diagnostic incorrectly left baseline fog
frozen; the final `quality` run updates atmosphere state in both variants.

`check_fps_optimization.gd` verifies shallow/deep visibility transitions, full
floor collision, the unchanged canopy, both MSAA/scaling modes, 91 trees, 81,325
grass instances and thirteen existing water surfaces. The original-grass check
passes, retaining three shared grass meshes and one material. The ocean-ground
check passes 2,915 floor rays, foundation contacts and eighteen player walks
(twelve seabed/slope walks and six bridge-deck walks).

Evidence: `/home/allister/Projects/live-aligned-previews/fps-2026-10-20/`.
Backup: `/home/allister/Backups/live-aligned/fps-20261020-035959/`.

## Rebuilding the caches

Keep the original tree resources and `ocean_ground.glb` as inputs. Regenerate
these caches whenever their source assets change, then run the checks:

```sh
godot --headless --path . --script res://tools/compact_tree_buffers.gd
godot --headless --path . --script res://tools/partition_seabed_buffers.gd
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/check_fps_optimization.gd
godot --headless --path . --script res://scripts/check_original_grass.gd
godot --headless --path . --script res://scripts/check_ocean_ground.gd
godot --path . --script res://scripts/benchmark_fps.gd -- paired 4.0
godot --path . --script res://scripts/benchmark_fps.gd -- quality
```

The compact resources are local asset binaries, excluded from public Git. Their
hashes are in `local_asset_manifest.json`; the two JSON build reports retain
counts and provenance. The partition builder removes its intermediate buffers.
