# Sound Generation Prompts (English)

Copy-paste-ready prompts for AI sound generators (ElevenLabs SFX, Stable Audio, etc.).
Every prompt below is **self-contained** — the shared style base is already merged into
each one, so paste a single block as-is without assembling anything.

Korean design notes and in-game context live in [`SOUND_PROMPTS.md`](SOUND_PROMPTS.md).
When a sound is *wrong* rather than missing, start from [`SOUND_GUIDE.md`](SOUND_GUIDE.md) —
symptom-to-cause diagnosis, overlap density, inaudible bass, and repeat-play rules.

## How to use

1. Pick a sound below, paste its prompt, set the generator's duration to the listed length.
2. Generate 3-5 takes and keep the one with the strongest attack (no silent lead-in).
3. Convert and normalize (see [Post-processing](#post-processing)).
4. Drop the file into `assets/audio/` under the exact filename listed.
   The game loads it automatically — no code change needed. Missing files are skipped
   silently, so you can add them one at a time.

## Negative prompt (use wherever the tool supports it)

```
music, melody, singing, voice, speech, silence, fade-in intro, low volume, thin,
weak, lo-fi, clipping, distortion, abrupt cut-off ending, reverb tail, room ambience
```

---

# 1. Ultimate abilities

Long one-shots fired once per activation. The ability lasts **3.0 seconds**, so energy
should hold until 3s and then decay naturally. Target length **4 seconds**.
These play over the BGM and need to cut through — generate them loud and bright.

### `sfx_ult_quake.ogg` — Veteran, "Seismic Wrath" (4s)

```
Massive earthquake ultimate attack for a video game: a deep seismic slam impact
with a heavy sub-bass drop at the very start, then the ground violently cracking
and splitting open, boulders grinding against each other, a continuous low
rumbling tremor lasting three full seconds with irregular rocky crack bursts
throughout, debris and dust falling, ending in a fading underground rumble.
Cinematic, huge and impactful, powerful punchy transient at the very start,
wide stereo, clean professional game audio, no music, no voice, no silence at
the beginning, not an explosion or fireball.
```

### `sfx_ult_arrow.ogg` — Hunter, "Arrow Tempest" (4s)

```
Dense medieval arrow volley barrage: hundreds of arrows falling continuously
like a violent hailstorm, a thick layered wall of overlapping high-pitched
arrow whistles and rapid wooden thunk impacts hitting the ground, eight to ten
impacts every second with no gaps and no pauses, chaotic and relentless for the
entire duration, never a single isolated arrow, massed archery battlefield
texture, tapering off in the final half second. Cinematic, huge and impactful,
wide stereo, clean professional game audio, no music, no voice, no silence at
the beginning.
```

> Generators often collapse this into **one arrow** because it reads as a story
> ("an arrow flies and lands"). The wording above is deliberately a *continuous
> texture*: quantity first, a hail metaphor, an explicit impacts-per-second rate,
> and a ban on single hits. Add `single arrow, one impact, sparse, slow` to the
> negative prompt. If it still comes out as one arrow, open with
> `Heavy rain of arrows, like hail hammering a wooden roof,` — the rain metaphor
> pulls density better than any other phrasing.
>
> **Fallback:** generate one clean arrow instead and multiply it into a storm with
> the bundled script (see [Plan B](#plan-b--build-the-arrow-storm-from-one-arrow)).

### `sfx_ult_orbital.ogg` — Engineer, "Orbital Barrage" (4s)

```
Sci-fi orbital laser bombardment ultimate attack: a quick targeting charge-up
hum, then powerful energy beams firing down from the sky in rapid rhythm,
roughly three strikes per second layered and overlapping, each beam a searing
electric zap followed by a plasma impact explosion on the ground, sustained for
three full seconds, ending with a discharging electrical fizzle. Satellite-scale
weapon, deeper and heavier than a handheld laser, cinematic, huge and impactful,
wide stereo, clean professional game audio, no music, no voice, no silence at
the beginning.
```

---

# 2. Gameplay one-shots

Short, dry, repeatable. Several of these fire many times per minute, so a long tail or
a strong personality becomes irritating fast — keep them tight.

### `sfx_bomber_blast.ogg` — bomber zombie explodes (0.8-1.2s)

```
Close-range suicide bomber zombie explosion: a sharp flesh-and-shrapnel burst
with a short punchy low thump underneath, wet and gritty, dry and tight with no
long reverb tail. Punchy transient, clean 2D game sound effect, mono compatible,
no music, no voice, no silence at the beginning.
```

Must read as *a zombie bursting nearby*, clearly distinct from the game's existing
shotgun/explosive `boom`. Lean on gore and shrapnel, and keep the tail short.

### `sfx_bomber_fuse.ogg` — bomber ignites, 0.55s escape window (0.5s)

```
Short urgent warning beep sequence: three quick rising electronic ticks like a
bomb fuse about to blow, small, dry and clean, tense. Punchy transient, 2D game
sound effect, mono compatible, no music, no voice, no silence at the beginning.
```

### `sfx_evolve.ogg` — weapon evolution (1.5-2.5s)

```
Triumphant weapon evolution fanfare: a rising magical power surge that
transforms into a bright metallic bloom, heroic and rewarding, a short
orchestral hit with shimmer on top. Clean professional game audio, punchy,
no voice, no silence at the beginning.
```

The biggest power-up in a run — this should feel clearly grander than the level-up jingle.

### `sfx_wave_clear.ogg` — wave cleared banner (0.8-1.2s)

```
Short positive achievement stinger: two or three bright ascending notes with a
satisfying finish, clean and crisp, light and quick, not a long fanfare. Clean
2D game sound effect, no voice, no silence at the beginning.
```

Plays on every wave, so keep it noticeably lighter and shorter than the 30-minute
clear jingle.

### `sfx_revive.ogg` — free revive (1.5-2s)

```
Heroic revival sound: a soft holy choir-like chime swelling up with a warm
energy surge and a heartbeat resuming underneath, uplifting and dramatic.
Clean professional game audio, no voice, no silence at the beginning.
```

### `sfx_swing.ogg` — melee weapon swing (0.25s)

```
A quick heavy baseball bat swing whoosh cutting through air, short and dry, no
impact and no hit at the end. Punchy transient, clean 2D game sound effect, mono
compatible, no music, no voice, no silence at the beginning.
```

Fires roughly once per second all run long — keep it minimal and free of character.

### `sfx_spit.ogg` — spitter zombie fires (0.4s)

```
A wet guttural acid spit projectile launch from a monster: a short slimy hawking
burst, disgusting and organic, dry and tight. Punchy transient, clean 2D game
sound effect, mono compatible, no music, no voice, no silence at the beginning.
```

Warns the player that a projectile is incoming, so the attack transient matters more
than the texture.

---

# Post-processing

**The bundled importer does all of this for you.** Add an entry to `PLAN` in
`tools/import_sfx.py` (source filename, the slice to keep, fade length) and run it —
it decodes, trims the silent lead-in, cuts to length, fades the tail, normalizes and
encodes straight into `assets/audio/`:

```bash
python3 tools/import_sfx.py                 # everything in PLAN
python3 tools/import_sfx.py swing spit      # just these two
SFX_SRC_DIR=~/Downloads python3 tools/import_sfx.py   # different source folder
```

The manual equivalent is below, for reference.

Mix balance is handled in code (`SoundManager._VOLUMES`), **not** in the files. Normalize
everything to the same loudness and let the game apply per-sound levels — otherwise the
mix becomes impossible to manage.

```bash
# Ultimates (louder — they must cut through the BGM)
ffmpeg -i in.wav -af loudnorm=I=-14:TP=-1 -c:a libvorbis -q:a 6 assets/audio/sfx_ult_quake.ogg

# Gameplay one-shots
ffmpeg -i in.wav -af loudnorm=I=-16:TP=-1 -c:a libvorbis -q:a 6 assets/audio/sfx_swing.ogg
```

Checklist before committing a file:

1. **No silent lead-in** — the attack must start at 0.000s, or it will drift out of sync
   with the screen shake and burst FX.
2. **Same loudness across the set** — normalize as above.
3. **No hard cut at the end** — let the tail decay, adding a 60-100ms fade-out if needed.
4. **In-game check** — audible over the BGM, not confusable with `boom` or `laser`, and
   the repeating sounds (`swing`, `spit`, `bomber_fuse`) still
   feel fine after several minutes of play.

## Plan B — build the arrow storm from single arrows

**This is what currently ships.** A generated volley that isn't dense enough reads as
*breaking glass* rather than falling arrows — sparse hits with bright 0.8-8kHz content
are exactly what shattering sounds like. Building the storm from single arrows lets you
control band balance and density directly:

```bash
python3 tools/make_arrow_rain.py                      # synthesizes the arrow, writes the asset
python3 tools/make_arrow_rain.py --src one_arrow.wav  # or layer a real recorded arrow
```

|  | generated volley | layered (shipping) | real glass | wooden bat |
|---|---|---|---|---|
| centroid | 2031Hz | **480Hz** | 5538Hz | 374Hz |
| 200-800Hz (wood) | 35.6% | **60.0%** | 1.6% | 60.1% |
| 3-8kHz (glass) | 22.6% | **3.9%** | 57.8% | 0.4% |
| impacts/sec | 4.4 | **12.0** | — | — |

To supply a real arrow instead of the synthesized one, generate a single clean arrow —
generators handle *one* arrow reliably — and pass it with `--src`:

```
Single arrow flyby: one quick sharp whoosh cutting through air, then a solid
wooden thunk impact into the ground, short and dry, no reverb tail. Punchy
transient, clean 2D game sound effect, no music, no voice, no silence at the
beginning.
```
