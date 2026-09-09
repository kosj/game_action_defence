# Hunter directional rig — game assets

The approved wider-thigh rig is baked into `walk.png` (3072×1024) and `idle.png`
(128×1024). Cells are 128×128. Rows: S, SW, W, NW, N, NE, E, SE. Walk has 24
columns; idle has one. Both use actual transparency and lossless Godot imports.

`data/character_db.tres` enables these textures only for the hunter. Its menu
portrait remains the existing atlas entry. Player uses positive scale 0.9 and
offset (0,-6), with the previous ground/shadow anchor preserved. No procedural
squash, extra lean, or horizontal flip is applied to the baked animation.

The walk advances by actual displacement and keeps its phase through stops.
At rest, it uses a neutral pose in the last facing direction. The base gun and
ProjectileWeapon (including crossbow) both use this facing direction and the
matching muzzle marker.

The game uses 211.2 world pixels per cycle, so base movement at 220px/s plays
one cycle in 0.96s. This deliberately preserves gameplay movement speed and
the reviewed cadence; it is not a physically exact foot-to-world stride lock
(the rig preview's treadmill uses its shorter anatomical stride). Movement
buffs and slows proportionally change playback speed.

Authoring source: `output/hunter_walk_sample/rig_v3/`. Serve that directory on
localhost:8765 and run `export_game.mjs` with RIG_NODE_MODULES pointing to the
Playwright node_modules directory. Exporting the existing rig uses no image
generation calls. Preview outputs are excluded from Web export.

Regression scene: `res://scenes/CharacterWalkTest.tscn` (headless). It covers
all 8 directions, idle/resume, distance-based frame selection, shot origin
and direction, and both legacy characters. It does not save character selection.
