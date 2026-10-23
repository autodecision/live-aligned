# South island koi and sand garden

The south island now contains an excavated koi pond beside a raked sand garden.
Both bridge landings lead to a continuous gravel loop, with a viewing deck,
two benches, lilies, reeds, and three warm stone lanterns. The expanded shoreline
retains the island's eleven olive trees. Existing trees, rocks, coastal lamps,
and meadow points are reseated on the graded ground; grass is cleared from
the full garden and path footprints.

The pond is approximately 11.2 by 8 metres, centered at Godot `(96,4.42,34)`.
Four low bank gaps permit walking out of the pond without jumping. Fourteen
original koi share three meshes: Kohaku, Sanke, and gold. They swim at different
speeds and depths while steering toward independent, changing destinations.
They accelerate, turn, briefly glide, and separate from nearby fish. A soft bank
avoidance force keeps them inside the sloping banks; they no longer follow loops. The pond has its own
transparent ripple material so the fish remain visible below the water.

The adjacent 9.6 by 10.4 metre sand bed has three asymmetrical moss-based stones.
Its shader combines parallel rake grooves with concentric strokes around the
stones, with distance filtering to reduce shimmer. Garden lights use the
existing day/night cycle and have no shadow maps.

## Saved sources and scoped integration

- Artistic map: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Optimized companion: `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`
- Standalone editable library: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/south_garden.blend`
- Scoped external backup: `/home/allister/Backups/live-aligned/south-koi-garden-20261015-225134`

`tools/build_south_garden.py` builds original geometry and exports
`south_garden.glb`, `south_garden_koi.glb`, and `south_garden_terrain.glb`.
`assets/south_garden.json` contains dimensions, colliders, routes, lights, and
grounded prop placements. The standalone library includes the garden,
fourteen posed fish, three prototype meshes, terrain, and the two south banks.

`scripts/south_garden.gd` runs after NorthPagoda and before IslandGroundCover.
It replaces the existing Distant_Islands mesh and the two south landing banks,
rebuilds their existing collision from those meshes, installs the garden,
and extends the sea footprint to cover the enlarged island. All 6,735 northern
terrain vertices and faces are retained. The optimized base-map GLB is untouched.

The builder expects the pre-garden optimized source and original placement
inputs; its assertion prevents duplicate installation. For a full rebuild,
restore only those scoped inputs from the backup, run `build_and_export()`,
then `save_standalone()` in a fresh read of the optimized source, and
`install_saved()` in the pre-garden artistic map. Never run the historical
full-map exporter. Exclude **South Koi and Zen Garden** and **South Garden Koi
Library** from any later base-map export, as with the other independent assets.

The fish, pond, props, and sand geometry are generated entirely from code,
without scans, downloaded meshes, or image textures. The terrain and existing
map objects retain the map's asset restrictions. Generated binaries remain
local under the repository's publication boundary.

## Verification and viewing

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://scripts/check_south_garden.gd
godot --path . --script res://scripts/check_south_garden.gd -- --views-only
godot --path . --script res://scripts/preview_south_garden.gd
```

The garden check uses the actual player capsule for both bridge approaches,
the loop and connecting path in both directions, the deck, the sand bed, and
four pond exits. It checks route support, fish containment and forward-facing
movement over sixty simulated seconds, mesh sharing, and day/night lamps.
`tools/validate_south_garden.py::validate()` reopens each Blender source,
compares northern vertices against the scoped backup, fingerprints terrain,
and checks that the lining covers the soil.

Reports and day/night game captures are saved in
`/home/allister/Projects/live-aligned-previews/south-koi-garden-2026-10-15/`.
The normal game spawn, saved looks, and F6 preferences are preserved.

The completed checks report 255 supported route samples, fourteen complete
walks (including four pond exits), and 50,400 fish checks. All three bridges
pass full crossings in both directions, and the north sidewalk retains its
300 supported samples and twelve walks. The grass check retains three shared
meshes, one material, both MSAA modes, and 47,112 instances. Day/night checks
pass, and the saved terrain fingerprints match in all three Blender sources.


## Garden fit and movement refinement

The scoped refinement backup is
`/home/allister/Backups/live-aligned/south-garden-refinement-20261015-233806`.
`tools/refine_south_garden.py::refine_and_export()` operates on the installed
optimized garden. It rebuilds only the static garden, updates its collision plan,
and clears grass from the union of the paths and the full transformed rock
footprints. It retains terrain, existing fish meshes, props, and saved looks.
Then run the builder's `save_standalone()` in a fresh process and the refinement's
`install_refinement()` in the artistic map. Apply this pass after a full garden
rebuild too. Reopen all three sources with `validate_saved()`.

Paths now use one joined, clipped triangle grid at 0.125 m spacing. Their heights
follow both terrain and independent landing banks, with matching mesh collision.
Constrained smoothing fills competing-grade ruts, smooth normals remove triangular
faceting, and shallow edge skirts finish the paving down into the soil. Route
heights are resampled from the final surface.
The two bridge approaches meet at a broad arrival apron. Pond coping has beveled
quarried stones, visible top faces, four flush exits, and an opening cut around
the entire deck footprint. Reeds root inside the wet shelf. The zen stones use
asymmetric plane-cut, displaced geometry, chipped silhouettes, mineral grain,
subtle fracture lines and lichen, with thin moss at their bases.

The refinement removes 93 obstructing grass instances, leaving 47,019 total
runtime plants including north-island cover. The same three shared grass meshes
and one material remain. Validation checks 30,869 paving triangles against
terrain/banks, at least 0.084 m clearance, no deck/coping intersection, cleared
rock footprints, and identical geometry in all saved sources. The runtime check
walks fourteen routes, including all four pond exits, and checks containment,
forward movement, speed variation and changing radii for every fish over sixty
simulated seconds. Game captures and source reports are in
`/home/allister/Projects/live-aligned-previews/south-garden-refinement-2026-10-15/`.

## Rectangular sidewalk ends (October 18)

`tools/square_garden_paths.py::build()` replaces only `SouthGarden_Gravel` in
the optimized source, clears intersecting meadow tufts, resamples the four
walking routes, and exports the existing garden collection. The loop now has
exact right-angle corners and joins, with a consistent 2 m width. Its outer
Blender bounds are x=87..119.5, y=-42.5..-25.5. The two bridge thresholds keep
their existing fitted grades. `build_south_garden.py` retains this layout for
future rebuilds. `install()` copies only the paving to the artistic source and
standalone garden library, and synchronizes meadow data in the artistic map.

Existing land supports the entire rectangle, so no terrain expansion was
needed. All 34,976 paving top triangles have ground beneath them, with at
least 0.075 m soil clearance. All 1,370 garden boundary edges run along X or Y.
The three reopened saved sources have matching paving geometry. Eighty-three
grass tufts were cleared. The base map, terrain, fish and pagoda GLBs remain
byte-for-byte unchanged.

The runtime garden check passes 18 walks, including both edge lanes around
the complete rectangle in both directions, plus 225 support samples, both
bridge approaches, four pond exits and 50,400 fish checks. The windowed
`--views-only` check also captures the arrival, far end, and overhead plan.
Evidence: `/home/allister/Projects/live-aligned-previews/square-garden-paths-2026-10-18/`.
Scoped backups: `/home/allister/Backups/live-aligned/square-garden-paths-20261018-081506/`.

The subsequent shoreline slope pass lowered the southeast soil beneath the
squared paving. See `SHORE_PLANTING.md` for the supported shoulder, new coastal
grass and offshore rock relocation; its terrain exports supersede the terrain
preservation statement above.
