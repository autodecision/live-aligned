# Garden composition, lab assortment and Kestrel arms

October 18 repair of the screenshot defects:

- The two bottle shelves use different vessel orders and upper-row proportions.
  Individual specimen labels and liquid levels remain intact.
- The temple terrace guard now turns the corner along the existing transverse
  cement edge, reaching Blender x=-2.5 at y=-11.8. Its scoped export adds real
  collision without replacing the original terrace or architectural collision.
- The sea outfall shader converts imported glTF V to downstream travel with
  `t=1-UV.y`. Moving folds, highlights and foam now follow increasing t toward
  the sea. The pool/channel seam remains connected.
- The unsupported `Large_Rock_South_02` is hidden in the editable maps and
  disabled visually and physically in Godot.
- Garden paving uses the exact pagoda limestone material image and world UV
  scale of 0.3 repeats per metre. The gravel override has been removed.
- Six stone lanterns form three mirrored pairs about Blender y=-34. Existing
  bridge approach lighting remains. The new footprints cleared 36 grass tufts.
- All 89 active trees were checked against 398 solid scene meshes. Thirty-two
  trees moved onto nearby dry, supported soil; the final triangle intersection
  audit found no tree intersections with scene props or architecture. Terrain,
  grass and foliage-to-foliage crown overlap are excluded from that audit.
- Kestrel has domed shoulders, tapered oval arm castings, curved flush inserts,
  and cooling slots following the forearm curvature. All 20 rig bones and
  non-arm vertices remain identical to the previous asset.

The existing island has sufficient land for the paired lanterns and supported
new tree positions; the terrain geometry is unchanged in this pass.

## Saved sources and local assets

- Artistic map:
  `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Optimized map: `assets/mediterranean_temple.blend`
- Garden library:
  `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/south_garden.blend`
- Kestrel source:
  `/home/allister/Projects/mcp-for-blender/output/ps3_character_pack/ps3_character_lineup.blend`
- Existing character recipe: sibling `build_characters.py`, including the new
  `robot_arm_shell()` helper. Rebuild only `robot` through
  `tools/repair_character_fit.py::refresh(assets=('robot',))`.
- `tools/detail_lab_props.py` exports `assets/lab_prop_detail.glb`.
- `tools/polish_garden_site.py` builds the paired lantern composition, tiled
  paving and `assets/temple_terrace_guard.glb` in the optimized source. Its
  `install()` copies the garden, guard and lab meshes into the artistic source.
- `tools/repair_tree_clearance.py::repair(max_changes=4)` performs bounded
  relocation batches in the optimized map. Repeat until no further changes,
  then run `audit()`. `install(validate=False)` applies the resulting poses to
  the high-resolution artistic source. `assets/tree_clearance_repairs.json`
  records exact positions and the final optimized-map triangle audit.
- `tools/build_south_garden.py::save_standalone()` refreshes the garden library
  from a fresh read of the saved optimized map.

The optimized base-map GLB is unchanged. Generated binary assets remain local,
under the existing redistribution boundary. Only placement plans, source code,
shaders and documentation are intended for public Git history.

## Verification

`check_garden_polish.gd` passes six mirrored lantern checks, imported waterfall
UV/phase direction, seven collision probes along the rail, and four actual
player walks beside the rail and around its corner. `check_south_garden.gd`
passes 14 walks, 255 support samples and 50,400 koi checks. Both bridge
approaches pass all 12 lane walks in `check_site_finish.gd`; 13 coincident water
seam vertices remain connected. `check_character_walking.gd` completes its
800-second simulation with zero recoveries or backward walking.

`capture_garden_polish.gd` renders the named defects and Kestrel standing and
walking; `--kestrel-only` limits it to the robot views. It uses an unsaved
Original look and does not write saved looks or graphics preferences.
Evidence lives outside Git at:
`/home/allister/Projects/live-aligned-previews/garden-polish-2026-10-18/`.

Backups are under:
`/home/allister/Backups/live-aligned/garden-polish-20261018/`.
