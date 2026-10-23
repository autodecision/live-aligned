# Microscope and shelf reagents

The October 18 revision connects the microscope's previously floating objectives
to a revolving nosepiece and cast support. It includes three objective barrels
with magnification bands, a coated eyepiece, coarse and fine focus knobs, a
mechanical stage with an aperture, specimen slide and clips, condenser, iris
lever, base illuminator, power switch, screws, and rubber feet.

The fourteen shelf bottles now have round and square profiles, different necks
and shoulders, wide caps and dropper bulbs, ribbed screw caps, tamper rings,
volume marks, tinted transparent glass, and separate liquid volumes with visible
fill levels. Each curved label has a sample name, volume, lot number, and barcode
in a single shared 2048 × 1024 texture. These are decorative research specimens.

## Sources and rebuild

Both editable maps contain the same three meshes in the collection
`Lab optical and reagent detail`:

- `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`

`tools/detail_lab_props.py` constructs the original geometry and label artwork.
Run its `make_labels()` in regular Python with Pillow; run `build_and_export()`
through Blender MCP with the optimized map, then `install_saved()` with the
artistic map. Existing source props remain hidden for reference. Both maps were
saved and reopened, with matching vertex hashes for all three replacements.

The scoped runtime asset is `assets/lab_prop_detail.glb`. It contains 27,684
vertices across three mesh instances: microscope, opaque reagent details, and
transparent vessel shells. The label atlas is embedded in the GLB and saved as
`assets/textures/lab_reagent_labels.png` for source editing. Blender transmission
alone was not portable to the current renderer; the replacement shells use
explicit alpha with separate opaque contents.

`island_site_repairs.gd` installs the scoped asset and hides 53 old visual meshes.
The base map GLB, benches, shelf geometry, and original microscope collision
remain intact. This also preserves the previous centrifuge display repair.

## Verification

Godot's import completed without errors or warnings. The delivered Forward
Mobile views were checked for attached optics, slide clearance, glass
transparency, readable labels, and visible fill levels. The capture additionally
checks that all old meshes are hidden, the new asset contains three meshes,
both glass materials have alpha below 0.4, and the microscope's original
collision shape is retained. The existing temple movement check passed all
14 walking routes, including the central lab aisle, doorway, porch, stairs and
side passages.

Capture command: `godot --path . --script res://scripts/capture_lab_props.gd`.
This uses an unsaved Original preview and does not write graphics preferences.
Walking command: `godot --headless --path . --script res://scripts/check_temple_details.gd`.

Before/after images and verification logs are under
`/home/allister/Projects/live-aligned-previews/lab-props-2026-10-18/`.
Scoped backups are under
`/home/allister/Backups/live-aligned/lab-props-20261018/`.
Generated binaries and the label texture remain local under the existing asset
publication boundary.
