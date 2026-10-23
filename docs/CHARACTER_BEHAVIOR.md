# Character walking and routines

`scenes/main.tscn` instantiates `IslandCharacters`. The runtime routes and tasks live in `scripts/island_characters.gd`; locomotion and rig posing live in `scripts/ps3_character_npc.gd`. Locomotion is implemented at runtime. The subsequent clothing and armour fit repairs are saved in the character Blender source and the three scoped GLB exports; see `VISUAL_FIT_REPAIRS.md`.

- The Envoy starts at the mainland end of Main_North, crosses to the pagoda entrance along the stone sidewalk, then takes North_South to the koi garden viewing deck and returns. It pauses to study the temple from across the landscape, the pagoda and the fish. Its former short temple circuit is replaced by this connected island tour.
- Dr. Vale surveys the lower courtyard and temple landing, climbs the central stairs, and pauses to check readings.
- Kestrel-09 starts on Main_South, inspects the deck, follows the full gravel loop around the pond and sand garden, crosses North_South, and follows the pagoda sidewalk to its entrance before returning. Its inspection stops overlook the bridge, sand bed and pagoda.

Bridge sections, garden approaches and the loop, and both branches of the pagoda sidewalk come from their existing JSON plans. These routes use their actual landing heights and every sidewalk bend; the characters never cut across water or enter the pagoda stairs. Dr. Vale retains the temple stair routine.

Route entries without an `activity` are transit points. Named activities (`observe`, `record`, `inspect`) include a duration and a world-space `look_at` target. Keep turns on clear landings and test entire circuits after changing a route. Point clearance alone is insufficient: columns, furniture and terrace walls can block the connecting segment.

The imported rigs face **+Z**. Only the model child is rotated by PI; the character controller continues to use Godot's **-Z** forward convention. Bone rotations account for each bone's rest orientation. Walking phase follows measured horizontal travel, with character-specific stride, lift and arm swing. Two-bone leg solving places each ankle on its sampled ground height, with stance, swing and toe-off phases. Starts, stops and turns blend into breathing and destination gestures. Away from the player, characters cover ground three times faster than the previous fast travel mode by taking three short route steps per physics tick; this avoids jumping across the closely spaced waypoints. Within 2.5 m they use normal speed on routine patrols, with a smooth transition out to 5 m. When approaching the player for their sequential daily check-in (Dr. Vale first, Kestrel-09 second, and the Envoy third), the active check-in character moves at full travel speed all the way up to talking distance (`approach_arrival_distance`), using `scripts/npc_navigation.gd` across islands and bridges before zooming into their face and opening dialogue. During conversation, each character turns to face the player with personality-distinct posture and gestures (Dr. Vale inquisitive and expressive, Kestrel-09 stoic and upright, the Envoy relaxed and open). The pose is updated once per tick. Steep stair segments and Dr. Vale's narrow temple landing stay at normal speed per step during routine patrols for safe foot placement. Characters slow before sharp turns and yield to a player directly ahead when not approaching for a check-in.

Verification with the local asset pack:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/check_character_walking.gd
godot --path . --script res://scripts/check_character_walking.gd -- --capture
```

The integration check runs 800 simulated seconds against the actual map, requires every task with its deliberate dwell and a complete circuit for each character, and asserts that the expanded island regions are actually visited. It fails on a stalled destination, any unplanned recovery, backwards travel or a fall. It retains Dr. Vale's stair travel check, tests player yielding/resumption on a straight Main_South deck section selected from the actual route, and measures foot and hand motion in the imported skeletons. The report includes each circuit's planned horizontal distance and time to the first completed lap. Results and windowed snapshots go to `/tmp/live-aligned-character-walking/`. Captures select a temporary daylight view without saving Visual Lab settings.

If terrain traps the player, press **Esc** and click **Reset position** at the
bottom right. It restores the starting location and view, clears momentum, and
leaves the cursor available. Click the world to resume looking and walking.
Automatic recovery after a fall uses the same reset function.
