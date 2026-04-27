# 7 Pillars of Game Feel — Reference Card

---

## 1. Input Response

**Definition**: The perceived delay between player input and on-screen reaction. Includes input buffering, coyote time, and pre-emptive jump queuing.

**Symptoms of failure**: Player says "controls are laggy" or "unresponsive" despite stable framerate. Missed jumps near ledge edges. Actions feel delayed.

**Reference games**:
- *Celeste* — 6-frame input buffer, 6-frame coyote time, instant directional change
- *Hollow Knight* — 5-frame jump buffer, 4-frame coyote time

**Typical parameter ranges**:
| Parameter | Range | Unit |
|---|---|---|
| Input buffer window | 4–10 | frames (at 60 FPS) |
| Coyote time | 3–8 | frames |
| Input-to-first-movement-frame | 1–3 | frames |
| Jump squat (anticipation) | 0–4 | frames |

---

## 2. Kinematics

**Definition**: The movement curves that govern acceleration, deceleration, gravity, and top speed. Defines how the character "weighs" in the player's mind.

**Symptoms of failure**: Character feels "floaty" (low gravity, no speed cap), "slippery" (too much momentum, not enough deceleration), or "stiff" (instant velocity, no acceleration curve).

**Reference games**:
- *Super Meat Boy* — snappy horizontal, high gravity (3200 px/s²), low air friction
- *Dead Cells* — fast ground accel (0.8s to top speed), high jump gravity multiplier (2.5×)

**Typical parameter ranges**:
| Parameter | Range | Unit |
|---|---|---|
| Gravity | 800–3500 | px/s² |
| Jump velocity | 300–800 | px/s |
| Fall gravity multiplier | 1.5–3.0× | ratio vs jump gravity |
| Ground acceleration | 0.05–0.3 | seconds to top speed |
| Air control factor | 0.3–0.8 | ratio vs ground accel |
| Top speed | 200–600 | px/s |

---

## 3. Sensory Feedback

**Definition**: Visual and haptic effects that confirm player actions: screen shake, hitstop (freeze frames), flash, squash & stretch, particle bursts.

**Symptoms of failure**: Hits feel "weightless", actions happen without confirmation, player is unsure if they hit something.

**Reference games**:
- *Vlambeer games (Nuclear Throne)* — aggressive screenshake (8–12 px), 3-frame hitstop, muzzle flash + shell casings
- *Hades* — targeted hitstop (2–5 frames), directional knockback particles, white flash on hit

**Typical parameter ranges**:
| Parameter | Range | Notes |
|---|---|---|
| Screenshake intensity | 2–15 | pixels displacement |
| Screenshake duration | 0.05–0.3 | seconds |
| Screenshake decay | exponential | never linear |
| Hitstop duration | 2–6 | frames (at 60 FPS) |
| Hit flash duration | 1–3 | frames |
| Squash & stretch ratio | 0.8–1.3 | from rest scale of 1.0 |
| Particle burst count | 3–20 | particles per impact |

---

## 4. Reactive Audio

**Definition**: Sound that responds dynamically to game events with variation, layering, and context-awareness.

**Symptoms of failure**: Repetitive SFX (same hit sound 100 times), audio feels "flat" or disconnected from visuals, silence during impactful moments.

**Reference games**:
- *DOOM Eternal* — pitch-shifted gore SFX, layered weapon sounds (bass + crack + tail), context-sensitive music
- *Returnal* — spatial audio feedback, pitch variation ±10%, intensity-scaled SFX

**Typical parameter ranges**:
| Parameter | Range | Notes |
|---|---|---|
| Pitch variation | ±5–15% | random per play |
| SFX variants per action | 3–5 | minimum to avoid repetition |
| Volume ducking on impact | 10–30% | momentary dip of background audio |
| Attack SFX anticipation | 0–2 | frames before visual hit |

---

## 5. Visual Readability

**Definition**: Clarity of game state communication through silhouettes, contrast hierarchy, animation anticipation, and visual layering.

**Symptoms of failure**: Player can't distinguish foreground from background, attack hitboxes are unclear, important objects don't stand out.

**Reference games**:
- *Ori and the Blind Forest* — strong foreground/background contrast, glowing interactive elements
- *Cuphead* — clean silhouettes, exaggerated anticipation frames, 3-layer parallax

**Typical parameter ranges**:
| Parameter | Range | Notes |
|---|---|---|
| Background desaturation | 20–50% | vs foreground |
| Anticipation frames | 2–6 | before attack/jump |
| Active frames | 1–4 | hitbox active |
| Recovery frames | 3–8 | after attack |
| Foreground/BG luminance ratio | 1.5–3.0× | contrast hierarchy |

---

## 6. Psychological Reward

**Definition**: Feedback mechanisms that create a dopamine response: combo counters, slowmo on kills, XP popups, screen flash, hit numbers.

**Symptoms of failure**: Game feels "unrewarding", player doesn't feel powerful even when winning, no motivation to chain actions.

**Reference games**:
- *Devil May Cry 5* — style meter (D→SSS), slowmo on last kill, rising combo multiplier
- *Vampire Survivors* — constant XP popups, satisfying level-up screen, kill count escalation

**Typical parameter ranges**:
| Parameter | Range | Notes |
|---|---|---|
| Kill slowmo factor | 0.1–0.3× | time scale, 0.1–0.3s duration |
| Combo timeout | 1.0–3.0 | seconds before reset |
| XP/damage number float speed | 30–80 | px/s upward |
| Number fade duration | 0.5–1.5 | seconds |
| Screen flash opacity | 10–40% | white overlay on major events |

---

## 7. Tonal Coherence

**Definition**: All game feel effects reinforce the game's aesthetic identity. A cozy puzzle uses gentle easing; a fast-paced roguelite uses aggressive, snappy feedback.

**Symptoms of failure**: Effects feel "borrowed" from another genre, screenshake in a zen puzzle game, lack of identity in feedback style.

**Reference games**:
- *Stardew Valley* — soft audio pops, gentle scale bounces, no screenshake (matches cozy tone)
- *Katana ZERO* — hard cuts, instant screenshake, zero easing (matches neo-noir aggression)

**Tonal guidelines by genre**:
| Genre | Screenshake | Hitstop | Easing | Overall intensity |
|---|---|---|---|---|
| Cozy / Puzzle | None or ≤2px | None | Smooth ease-in-out | Low |
| Platformer | 3–6px | 2–3f | Ease-out | Medium |
| Roguelite / Action | 6–12px | 3–5f | Exponential decay | High |
| FPS / Shooter | 4–8px | 1–2f | Sharp linear | Medium-High |
| Fighting | 8–15px | 4–8f | Instant + decay | Very High |
| Horror | 2–4px slow | 3–6f long | Slow ease | Low-Medium |
