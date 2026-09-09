# Veteran directional rig — game assets

`walk.png` is a 3072×1024 RGBA sheet and `idle.png` is 128×1024. Every cell is
128×128. Rows are S, SW, W, NW, N, NE, E, SE; walk has 24 temporal columns.

The rig preserves the veteran's red headband tails, gray beard, green tactical
vest, muscular arms, wide dark cargo trousers, oversized combat boots, and
two-handed machine gun. The torso and weapon remain fixed within each direction;
fixed-length IK legs provide the alternating planted-foot gait. The broad thigh
parts fill the connection beneath the wide tactical belt.

The game advances the cycle by travel distance, retains direction while idle,
and uses direction-specific muzzle positions. Lossless Godot texture import is
required. Authoring sources and generation prompts are in
`output/veteran_walk_sample/rig_v1/`.
