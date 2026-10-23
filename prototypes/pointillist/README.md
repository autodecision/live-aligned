# Pointillist play prototype

This is a playable dot rendering experiment for Live Aligned. The current
temple, trees, garden, plants, sea, player, and NPCs are rendered as visible
colored points. The existing scene supplies collision, movement, UI, and
gameplay. Terrain, sea, bridge decks and rails, and the temple's solid masonry
keep subdued opaque backing surfaces so the world does not become transparent
between dots. The bridge and cella wall dots are sampled by triangle area, so
large faces receive visible coverage instead of losing their budget to bevels.
The submerged seabed, island slopes, rock roots and bridge foundations use a
world-space dot shader. It also reaches ocean buffers that start hidden and
are shown only after the camera dives. This keeps the underwater floor solid
and covered in colored dots without adding a huge field of point vertices.
The original seabed and foundation collision remains in place.
The north pagoda island's `Meadow_Ground` mesh also keeps the same opaque
terrain backing. Its name does not contain `Terrain`, which previously caused
the prototype to hide the entire hillside and leave plants and buildings
floating against the sky. This is a runtime material change; the Blender
geometry, collision, and point cache are unchanged.

While the dot renderer is active, a single screen shader sweeps slowly moving
cobalt, indigo, and violet-blue zigzag ripples across the image, inspired by
the supplied optical-art reference. A 512x512 pattern
texture is generated once at startup so the screen shader avoids expensive
per-pixel trigonometry or a full-screen scene copy. The effect covers the world,
including underwater views, but sits behind the HUD and menus. The normal
scene and `original` preview mode do not install it. Add `no_filter` to a
preview command to compare the dots without the effect. The screen effect
does not change the point cache, collision, or source assets.

Run from the project root with Godot 4.7.2:

```sh
godot --display-driver wayland --path . --script res://prototypes/pointillist/preview.gd -- play
```

The first launch builds a local point cache if it is missing. Later launches
load the cache. After changing source geometry or materials, regenerate it:

```sh
godot --display-driver wayland --path . --script res://prototypes/pointillist/preview.gd -- play rebuild
```

The cache is `res://assets/pointillist_world_cache.scn` and is ignored by Git
with the other local asset binaries. It is generated from the assembled
runtime scene, including independently instanced assets. Do not run the
historical Blender exporter to refresh it.
The prototype rebuilds an older cache when its point layout version changes.

To benchmark four fixed views at 1920×1080 with active game scripts and NPCs:

```sh
godot --display-driver wayland --path . --script res://prototypes/pointillist/preview.gd -- live npc_speed_1_5 long
```

`long` samples each view for 10 seconds; without it, the sample is 3 seconds.
The Wayland display flag matches this computer's desktop session.
Results and captured frames go to
`/home/allister/Projects/live-aligned-previews/pointillist-2026-10-21/live/`.
The offscreen benchmark forces a full render each frame. A direct window can
be measured with `real npc_speed_1_5`, but an occluded window invalidates GPU
timing; the script exits with code 3 when this happens.

To capture the three bridges and two close temple views:

```sh
godot --display-driver wayland --path . --script res://prototypes/pointillist/preview.gd -- structures
```

The images go to
`/home/allister/Projects/live-aligned-previews/pointillist-2026-10-21/structures/`.

To capture the underwater bridge, rock, and island shore at 1920×1080:

```sh
godot --display-driver wayland --path . --script res://prototypes/pointillist/preview.gd -- underwater
```

The images and report go to
`/home/allister/Projects/live-aligned-previews/pointillist-2026-10-21/underwater/`.

To inspect the north shore, including two diagnostic camera positions beneath
the hill, and the south bridge shore:

```sh
godot --display-driver wayland --path . --script res://prototypes/pointillist/preview.gd -- hills
```

The reachable exterior views are `north_bridge_exterior`,
`north_coast_exterior`, and `western_sea`. The original scene also shows sky
through the hill from the two interior camera positions because its terrain
is a thin surface. Normal player collision blocks entry into that surface.

On this computer's AMD Radeon Graphics at 1920×1080, the earlier 10-second
sample after the bridge and wall visibility pass, with active scripts and
NPCs, measured 67.4 FPS at the temple, 139.9 in the meadow, 115.1 over water,
and 87.5 in the garden. That report predates the underwater shader:
`/home/allister/Projects/live-aligned-previews/pointillist-2026-10-21/live/report_structures_5px.json`.
After the underwater pass, a 3-second sample with another game running on the
same computer measured 32.0, 71.0, 57.0, and 51.1 FPS respectively. The
underwater views measured 96.3, 103.2, and 48.4 FPS in that run. The 60 FPS
target therefore remains unverified for the updated prototype; the island
shore and several full-scene views fell below it in current desktop conditions.
Results vary between runs and window/compositor states.
After the north hill backing fix, another 10-second active-scene sample at
1920×1080 measured 62.2 FPS at the temple, 112.1 in the meadow, 76.0 over
water, and 79.0 in the garden. The 95th-percentile frame times were 29.6,
17.5, 23.5, and 22.9 ms, so this still does not establish sustained 60 FPS.
The updated report is in `live/report.json` under the same preview directory.

The prototype changes distant NPC travel speed to 1.5 at runtime to avoid a
physics cost spike found during the live benchmark. It does not modify the
original NPC script or saved world. The dot cache and shader are an early art
pass. Silhouettes, color grouping, night treatment, and dense foliage need
artist review. A fixed-view benchmark passing 60 FPS does not prove a locked
60 FPS through every route, interaction, and weather or time condition.
