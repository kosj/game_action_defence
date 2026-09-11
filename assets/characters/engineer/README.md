# Engineer directional rig — game assets

`walk.png` is a 3072×1024 RGBA sheet and `idle.png` is 128×1024. Every cell is
128×128. Rows are S, SW, W, NW, N, NE, E, SE; walk has 24 temporal columns.

The rig preserves the engineer's yellow hard hat and goggles, cream rolled
sleeves, wide brown overalls, gloves, oversized work boots, and two-handed nail
gun. The torso and weapon are reused throughout each cycle; fixed-length IK legs
provide the alternating planted-foot gait. The game advances it by actual travel
distance, retains phase while idle, and aims shots from direction-specific muzzle
positions. Lossless Godot texture import is required.

Authoring source and generation prompts are in
`tools/engineer_rig/`. The Player integration is shared with the
hunter and configured by `CharacterData` fields.

The revised gait increases lateral spacing from 12 to 20 rig pixels. SE uses a
front-facing three-quarter torso and lowered, foreshortened nail gun; SW mirrors
the same component. The diagonal muzzle positions follow the new gun tips.
