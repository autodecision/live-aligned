# Character walking and routines

`scenes/main.tscn` instantiates `IslandCharacters`. The runtime routes and tasks live in `scripts/island_characters.gd`; locomotion and rig posing live in `scripts/ps3_character_npc.gd`. These are runtime-only changes; the original character GLBs and Blender sources are unchanged.

- The Envoy visits the temple interior and the clear west colonnade lane, stopping to look at the surroundings.
- Dr. Vale surveys the lower courtyard and temple landing, climbs the central stairs, and pauses to check readings.
- Kestrel-09 inspects both ends and the middle of Main_South, following the bridge plan's deck sections in both directions.

Route entries without an `activity` are transit points. Named activities (`observe`, `record`, `inspect`) include a duration and a world-space `look_at` target. Keep turns on clear landings and test entire circuits after changing a route. Point clearance alone is insufficient: columns, furniture and terrace walls can block the connecting segment.

The imported rigs face **+Z**. Only the model child is rotated by PI; the character controller continues to use Godot's **-Z** forward convention. Bone rotations account for each bone's rest orientation. Walking phase follows measured horizontal travel, with character-specific stride, lift and arm swing. Two-bone leg solving places each ankle on its sampled ground height, with stance, swing and toe-off phases. Starts, stops and turns blend into breathing and destination gestures. Characters slow before sharp turns and yield to a player directly ahead.

Verification with the local asset pack:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/check_character_walking.gd
godot --path . --script res://scripts/check_character_walking.gd -- --capture
```

The integration check runs 220 simulated seconds against the actual map, requires every task and a complete circuit for each character, checks actual model-facing versus displacement, checks stair travel, tests player yielding/resumption, and measures foot and hand motion in the imported skeletons. Results and windowed snapshots go to `/tmp/live-aligned-character-walking/`. Captures select a temporary daylight view without saving Visual Lab settings.
