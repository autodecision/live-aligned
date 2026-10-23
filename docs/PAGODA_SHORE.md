# Continuous pagoda coast — October 20, 2026

The west ridge and bridge-side ravine exposed an older vertical island shell
through gaps in the newer meadow overlay. The western-toe repair alone covered
one open boundary; it did not resolve these inland intersections.

`tools/refine_pagoda_coast.py` replaces those overlapping northern surfaces with
one continuous 0.5 m heightfield. It samples the existing ridge, meadow and
Main_North landing, spreads their shoulders at a controlled grade, and rounds
the transitions into the beach. The original path bed remains 0.07 m below the
paving. The pagoda plateau and independent structures retain their placements.

The new mesh has 53,265 vertices and 105,600 triangles. All 928 perimeter vertices
sit 0.50 m inside the existing rolling seabed. The obsolete 6,503 northern faces
are removed from Distant_Islands; its 28,512 southern faces, original coordinates
and mesh attributes are retained. The old Main_North landing remains editable,
hidden in the full sources; its upper ground is integrated into the new surface.

The water gaps around rocks use the active `offshore_spectrum.glb` geometry and
transforms. Older map copies of those formations can differ from the runtime
asset. Rock meshes, materials, transforms and submerged foundations are preserved.
The sea contact field is rebaked after installing the coastline.

Affected grass roots are reseated and aligned to the new ground. Another 3,140
tufts fill the dry shoulders, leaving 81,325 plants in 638 spatial batches using
the same three shared grass meshes and material. Main-island roots are excluded
using their actual terrain support; the south planting is unchanged. Path,
structure, rock and trunk exclusions remain in place.

## Runtime composition

`assets/pagoda_shore.glb` contains the continuous northern ground and a
`Pagoda_Coastal_Distant_Islands` mesh retaining the south terrain. NorthPagoda
installs the first mesh and builds collision from it. After SouthGarden installs
its terrain, it calls `NorthPagoda.install_coastal_base()` to replace the shared
Distant_Islands mesh/collider and hide/disable the redundant Main_North bank.
Keep that initialization order and the path/window/stair collision.

The optimized base-map, pagoda, sidewalk-terrain, south-terrain, bridges and ocean
GLBs are unchanged. The shoreline GLB disables mesh compression and generated
LODs to retain its fitted ground and collision. If the south terrain is rebuilt,
refresh its retained geometry in this coastal payload before exporting; do not
silently install an older southern surface over a new south-garden edit.

## Saved sources

- Optimized map: `/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend`
- Artistic map: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend`
- Pagoda source: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/north_pagoda.blend`
- Scoped source: `/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/pagoda_shore.blend`

All four reopened sources share the northern terrain digest
`7b525ee675dd334d304fa465e730e2c3db7a2b8f6478097987e343edc32d11d2`.
The retained Distant_Islands digest is
`6aee0c0cce2506707b04e807b8e080bec61ae31b72b7d67fccb35e4bac47f2d2`.
Both full maps contain all 81,325 meadow points. Build/install checks preserve
unrelated mesh coordinates, topology and object transforms.

Backup: `/home/allister/Backups/live-aligned/pagoda-coast-20261020-031232/`.
Evidence: `/home/allister/Projects/live-aligned-previews/pagoda-coast-2026-10-20/`.
`assets/pagoda_shore.json` records geometry, planting and source digests.

## Reproduction and verification

Run `build()` through Blender MCP on the unmodified optimized source. To reproduce
this installed version, open the optimized file in the scoped backup and pass
that backup directory to `build(backup=...)`; it reads the original placement
JSON there and saves the rebuilt optimized map at its normal project path.
`install()` copies the scoped ground into the artistic and pagoda files and
synchronizes meadow points in full maps. Link the scoped library's two mesh
objects into its scene before saving so it opens directly in Blender. The older
`repair_pagoda_shore.py` is the historical western-toe recipe, not this rebuild.

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/check_pagoda_coast.gd
godot --headless --path . --script res://scripts/check_pagoda_sidewalk.gd
godot --headless --path . --script res://scripts/bake_ocean_contact_field.gd
godot --headless --path . --editor --quit
godot --path . --script res://scripts/check_pagoda_coast.gd
```

The coast check verifies 12,099 ground samples, all 928 buried boundary vertices,
3,140 new grass roots, 17,175 active offshore footprint samples and twelve player
walks in both directions across the repaired slopes. The path check verifies
300 paving samples and twelve walks. Low headroom where the rising ground meets
a solid bridge deck is kept solid; movement routes cross the open shoulders and
the portion of the underside with room for the player. Native views cover the
reported ridge, bridge slope, ravine, coast overview and submerged seam. Preview
settings do not save graphics or Visual Lab preferences.
