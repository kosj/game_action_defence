# Engineer directional rig source

Versioned copy of the established `output/engineer_walk_sample/rig_v1` Canvas/IK rig. `.gdignore` excludes raw authoring images from game builds. Serve this folder on localhost port 8768, set `RIG_NODE_MODULES` to the Node packages directory containing Playwright, then run `verify.mjs` and `export_game.mjs` with Node. Export writes the runtime walk/idle sheets under `assets/characters/engineer/`.

Lateral spacing is 20 rig pixels, increased from 12. Fixed bone length, ground contact, cadence and 24-frame loop remain unchanged. The new SE torso is mirrored for SW; other directions reuse the original components.

The SE component was created using built-in image_gen with the original torso sheet as the identity reference, on solid magenta for the existing rig keying material. Runtime transparency and frame composition use the established Canvas renderer.

## Image prompt

Edit target/reference: engineer torso component sheet. Create ONE replacement upper-body component for SOUTHEAST / DOWN-RIGHT. Preserve exact yellow hardhat with round goggles on helmet, dark short hair, cream rolled sleeves, brown bib overalls with central pocket, olive work gloves, industrial yellow-gray two-handed nail gun, bold dark outlines and flat game shading. Only upper body from helmet to bottom waist: NO LEGS, no scene. Character faces camera at three-quarter angle: both eyes visible under helmet, front bib and central overall pocket clearly visible, shoulders face viewer and right. Rotate BOTH torso AND nail gun to aim down-right toward foreground, nail gun barrel clearly slants about 30 degrees downward-right, strongly foreshortened, muzzle visible. Must NOT resemble a horizontal right-facing profile. One centered sprite with uniform small margin on perfectly solid uniform chroma-magenta #FF00FF background, no checkerboard or shadows or grid or text. Intended replacement part for the existing Canvas animation rig; clean hard silhouette and consistent costume.
