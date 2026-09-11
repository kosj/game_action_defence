# Hunter rig source

Preserved from the established `output/hunter_walk_sample/rig_v3` authoring rig so changes can be regenerated from versioned source. The source illustrations are not runtime textures; `.gdignore` excludes this directory from Godot imports.

Serve this directory on localhost port 8767. Set `RIG_NODE_MODULES` to a Node packages directory containing Playwright. Run `node tools/hunter_rig/verify.mjs`, then `node tools/hunter_rig/export_game.mjs` from the project root. The export writes `assets/characters/hunter/walk.png` and `idle.png` using the existing deterministic Canvas/IK renderer, with 24×8 and 1×8 cells of 128 pixels.

The lateral leg spacing is 20 rig pixels (previously 12), with bone length, gait phase, contact timing and cadence preserved. The SE torso is also mirrored for SW, preserving bilateral costume consistency. No per-frame image generation is used.

`torso_se.png` was edited with built-in image_gen using the original torso component sheet as the identity reference. The first candidate contained a checkerboard backdrop and was not used. A second edit replaced only that backdrop with solid magenta #FF00FF, matching the established rig keying material. All other source parts are unchanged.

## Torso edit prompt

Edit target/reference: attached hunter torso component sheet. Create ONE replacement upper-body component for the SOUTHEAST / DOWN-RIGHT direction only. Keep exact green hood, black ponytail, tan skin, leather vest, brown gloves, waist belt, wooden crossbow, bold dark outlines and flat painted shading. Show from top of hood to bottom of belt only, NO legs. Turn torso, face AND both arms and crossbow together toward viewer and right, halfway between front-facing and right-facing: BOTH eyes should be visible, front breastplate and central belt buckle clearly visible. Crossbow aims diagonally toward lower-right foreground, barrel slants downward-right about 25 degrees in image, strongly foreshortened instead of pointing horizontally right. Broad shoulders face camera at 3/4 angle. DO NOT produce a right-facing side profile. ONE isolated waist-up sprite, centered on an ACTUAL transparent RGBA background with small uniform margin, no grid, no text, no other poses. Preserve costume and flat illustrative style of reference. This is an animation rig part, keep clean crisp silhouette, no cast shadow, no floor.

## Background edit prompt

Change ONLY the background of this hunter torso component to perfectly solid uniform chroma magenta #FF00FF. Keep the illustrated character, pose, outline, proportions, crossbow, face and colors exactly unchanged. No checkerboard, no shadows, no texture or gradient in the background. Maintain clean hard silhouette edges. This is for an existing animation rig that keys out magenta.
