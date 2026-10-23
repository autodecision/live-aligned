# Couch cushions, pagoda interior, and bowl outlet

The couch's two small boxes are replaced by plump cloth cushions, standing on
its end seats and leaning back. Each has two rounded fabric panels, small
stitched gathers, a corded perimeter, and an original woven color texture.
The ivory and ochre colors remain. Both bottoms are at Blender Z 5.137 m,
1 mm above the original seat surface. The solid couch retains its collision;
small, redundant pillow colliders are disabled.

The pagoda now contains three furnished areas:

- Ground floor: a low tea table, tray, teapot and three cups, two round cushions,
  a cabinet with books and ceramics, a bench, and a bonsai on a stand.
- Middle floor: a reading/calligraphy desk with an open manuscript, brush pot,
  brushes and inkstone, a cushion, book cabinet and stacked folios, and a vase.
- Top floor: a ceramic display console, two corner bonsai stands, and an observation table with a rolled map.

The original benches, structure, lights, stair openings and sidewalk remain.
Sixteen simple furniture collision boxes sit outside the main circulation
lanes. Three batched meshes contain 56,712 vertices in Blender. All added
geometry, cloth, and furniture textures are procedural and
use no downloaded models or images.

The temple bowl outlet previously stepped up from the basin into its spillway,
then changed width into a separate round tube. The bowl's southern lip now has
an actual lowered notch, the little stone sill sits beneath the water, and the
spillway and falling stream share the same 40-point oval cross-section. They
have matching flow UVs and one shader with reduced surface folding. The stream
continues below the receiving channel surface. All thirteen existing water
surfaces retain their names and animation hooks.

## Editable sources and scoped exports

Saved and reopened:

- Artistic map:
  `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Optimized companion:
  `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`
- Standalone pagoda, with furnishings in a separate editable collection:
  `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/north_pagoda.blend`

`tools/furnish_pagoda.py` provides `make_textures()` for regular Python,
`build()` for the original complete repair, `refine_interior()` for pagoda-only
changes in the optimized Blender map, `install(True)` for pagoda-only changes
in the artistic map, and
`install_pagoda()` for the standalone landmark. Run Blender functions through
Blender MCP. Appended, unlinked objects use their `matrix_basis` so cushion
placement is preserved before the dependency graph evaluates them.

Runtime additions are only `assets/couch_pillows.glb`,
`assets/pagoda_interior.glb` + `pagoda_interior.json`, and
`assets/bowl_outlet_detail.glb`. The cushions and bowl visuals substitute the
named existing map meshes; the interior is instantiated once by
`north_pagoda.gd`. The optimized base-map GLB and existing standalone pagoda GLB
are unchanged. Do not rebuild either to deliver these additions.

## Verification

- Headless Godot import completed without errors or warnings.
- Native Godot captures checked the couch from two angles, all three floors,
  the library cabinet, night lighting, and three animated bowl outlet frames.
- `check_pagoda_walkable.gd`: 514 movement samples, approach, both spiral flights
  up and down without jumping, and both upstairs perimeter routes passed.
- `check_pagoda_interior.gd`: ten two-way room/couch/fountain lane walks passed;
  both actual cushion bottoms are supported, all three interior batches and
  sixteen collision boxes are installed, and all thirteen water surfaces run.
- All forty water seam points match exactly in Blender. Godot's independently
  compressed surfaces differ by at most 0.000012875 m, within the 0.00003 m
  import precision allowance. Both use the same flow UVs, shader and clock.
- Reopened saved maps have identical local geometry for all nine affected
  meshes and matching world bounds within 0.00001 m. The standalone pagoda's
  three furnishing meshes match both maps.
- Base-map SHA-256 is unchanged. Python compilation and `git diff --check` pass.

Evidence: `/home/allister/Projects/live-aligned-previews/pagoda-interior-2026-10-18/`.
Scoped pre-edit backups:
`/home/allister/Backups/live-aligned/pagoda-furnishings-20261018-064859/`.
Captures and checks use unsaved preset previews and do not persist Visual Lab or
F6 graphics preferences.

## Pagoda plant and cabinet refinement

The framed landscape above the top-floor console has been removed. All three
bonsai now have smoothly tapered, curved trunks and branches, exposed roots,
1,056 individual ridged leaves each, varied leaf colors, textured bark, glazed
planters, moss and gravel. The leaf geometry is opaque and has no alpha cards.
The upper pair uses different branch rotations and deterministic leaf layouts.

Both cabinets now have short feet, stepped plinths, crown and shelf moldings,
recessed walnut side and door panels, framed stiles and rails, brass hinges,
escutcheons and hanging ring pulls. The original wood grain was replaced with
quieter irregular grain, aligned along individual boards before world-space
transforms. The tea cabinet's books sit inside its shelf.

`tools/detail_pagoda_furnishings.py` supplies the original geometry helpers and
three wood/bark textures. To rebuild only these furnishings, generate the three
textures with `make_wood_texture()`, then run
`tools/furnish_pagoda.py::refine_interior()` through Blender MCP in the optimized
map. Run `install(True)` in the artistic map and `install_pagoda()` in the
standalone pagoda. Only `assets/pagoda_interior.glb` is re-exported; its public
JSON plan records the detail version and counts. All sixteen original furniture
collision boxes are identical to their pre-edit values.

Refinement evidence:
`/home/allister/Projects/live-aligned-previews/pagoda-refinement-2026-10-18/`.
Pre-edit backup:
`/home/allister/Backups/live-aligned/pagoda-plant-cabinet-20261018-071810/`.

Refinement validation passed: clean headless Godot import, six native day/night
captures, and ten physical room/couch/fountain lane walks. Reopened all three
Blender sources: the three furnishing meshes and their packed texture hashes
match exactly. The old painting's volume is empty. The optimized base map,
structural pagoda, cushion and bowl outlet GLBs remain byte-identical to the
pre-edit copies. Python compilation and `git diff --check` pass.

## Distinct book collections, closed doors, and attached branches

The first-floor cabinet contains twelve garden, botanical and tea books, with
three horizontal folios on the left. The second-floor cabinet holds seventeen
different reference, history and poetry volumes, with a central stack of four.
Their titles, order and arrangements differ. Individual bindings have varied
height, thickness, color, rounded spines, separate cover boards, recessed tinted
pages, page edges, foil tooling, labels, medallions and occasional raised ribs.
The original 32-tile spine atlas is generated by `tools/detail_pagoda_books.py`;
its local output is `assets/textures/pagoda_book_bindings.png`.

Both lower cabinets have a closed dark lining and a wooden meeting stile.
The pale folios previously visible between the second-floor doors were removed.
Bonsai primary branches and roots now attach to the interpolated centerline of
the actual curved trunk, fixing the detached lower branch on the top floor.
The JSON plan is version 3 and includes both book inventories.

Pagoda windows now have eight continuous, invisible collision slabs, one per
wall on the two enclosed floors. `north_pagoda.gd` derives them from the existing
room dimensions; they overlap the visible sills and lintels and block all sixteen
lattice apertures. The ground-floor veranda remains accessible. This is a Godot
physics change; it does not require new Blender window geometry.

Validation: seven native Godot book/plant views inspected; 48 physical player
jumps at all sixteen windows, including angled jumps from sill height; 72 wall
samples; ten room/couch/fountain lane walks; and all 514 pagoda approach, spiral
stair and upstairs perimeter movement samples pass. Reopened all three Blender
sources: matching furnishing geometry and packed spine atlas, eighteen wood-only
door seam samples, and all 37 woody components per bonsai connected by actual
surface intersections. Sixteen furniture colliders and the base map, structural
pagoda, cushion and bowl outlet GLBs are unchanged.

Evidence: `/home/allister/Projects/live-aligned-previews/pagoda-books-2026-10-18/`.
Scoped backup: `/home/allister/Backups/live-aligned/pagoda-books-branches-20261018-073753/`.
