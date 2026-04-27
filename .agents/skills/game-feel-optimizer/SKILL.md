---
name: game-feel-optimizer
description: Audits and improves game feel, juice, and polish in games. Use when the user mentions game feel, jeu flottant, manque de punch, juice, polish, screenshake, hitstop, input lag, responsivité, animation de personnage, retour haptique, particules, feedback visuel, feel de tir, feel de saut, squash and stretch, or describes a game as floaty, mushy, lifeless, or unsatisfying.
---

# Game Feel Optimizer

## Use this skill when

- Auditing a game mechanic or full game for its perceived feel and responsiveness
- Implementing polish effects: screenshake, hitstop, squash & stretch, particles, trails
- Diagnosing a game described as "floaty", "mushy", "lifeless", "not satisfying", or "lacking punch"
- Reviewing code related to player controls, perceived physics, or character animations
- Generating parameters or code snippets to improve game feel in Unity, Godot, or Unreal
- The user asks about input latency, jump feel, shooting feel, or hit feedback

## Do not use this skill when

- The question targets realistic physics simulation or deterministic physics engines
- The task is purely technical performance optimization (FPS, draw calls, memory)
- The design topic is unrelated to player perception (enemy AI, economy systems, progression)
- The user asks about networking, multiplayer sync, or server architecture

## Instructions

Follow this 5-step audit pipeline in order. Do NOT skip steps.

### Step 1 — Gather Context

Ask the user for:

- [ ] Game genre (platformer, roguelite, FPS, hack & slash, puzzle, etc.)
- [ ] Target platform (PC, console, mobile)
- [ ] Engine and language (Unity/C#, Godot/GDScript, Unreal/C++/Blueprints, LÖVE/Lua, other)
- [ ] The specific problem felt ("jump feels floaty", "hits lack impact", "controls feel mushy")
- [ ] Relevant code or video if available

If the user already provided this context, acknowledge it and proceed to Step 2.

### Step 2 — Diagnose Against the 7 Pillars

Analyze the submitted code or description against the **7 Pillars of Game Feel**. See [references/game-feel-pillars.md](references/game-feel-pillars.md) for definitions, symptoms, reference games, and typical parameter ranges.

The 7 pillars are:
1. **Input Response** — latency, buffering, coyote time
2. **Kinematics** — acceleration curves, gravity scaling, speed caps
3. **Sensory Feedback** — screenshake, hitstop, flash, particles
4. **Reactive Audio** — pitch variation, layered SFX, contextual sounds
5. **Visual Readability** — silhouettes, contrast, animation clarity
6. **Psychological Reward** — combo counters, slowmo on kills, screen flash
7. **Tonal Coherence** — effects match the genre's register and mood

### Step 3 — Produce a Scoring Artifact

Create an Artifact with a scoring table:

```markdown
| Pillar                  | Score /10 | Status | Priority |
|-------------------------|-----------|--------|----------|
| Input Response          | X         | ✅/⚠️/❌ | Critique/Haute/Basse |
| Kinematics              | X         | ...    | ...      |
| Sensory Feedback        | X         | ...    | ...      |
| Reactive Audio          | X         | ...    | ...      |
| Visual Readability      | X         | ...    | ...      |
| Psychological Reward    | X         | ...    | ...      |
| Tonal Coherence         | X         | ...    | ...      |
```

Status thresholds: ❌ = 0–3, ⚠️ = 4–6, ✅ = 7–10.

### Step 4 — Recommendations

Produce an ordered list of fixes, prioritized by impact. For each recommendation:

- **Description**: what to change and why
- **Reference game**: a shipped title that does this well (MUST cite explicitly)
- **Code snippet or parameters**: concrete, engine-specific implementation

Use snippets from [references/snippets-by-engine.md](references/snippets-by-engine.md) as templates. Adapt constants to the declared genre.

### Step 5 — Validation Plan

Propose a measurable validation for each recommendation:

- Frame data target (e.g., "input-to-action ≤ 3 frames at 60 FPS")
- Animation curve to verify (e.g., "ease-out on jump apex")
- A/B playtest protocol (e.g., "have 3 testers compare old vs new jump, rate 1–5")

## Hard Rules

- MUST adapt all generated code to the user's declared engine and language
- MUST produce an Artifact "Implementation Plan" before any code diff
- NEVER propose cosmetic polish (particles, screenshake) before validating input latency and kinematics
- NEVER invent parameter values without anchoring them to an explicitly cited reference game
- NEVER apply identical screenshake or hitstop values across genres — adapt to register (roguelite ≠ puzzle ≠ FPS)
- MUST use named constants in all code snippets (e.g., `SCREENSHAKE_DURATION`, `HITSTOP_FRAMES`)

## Resources

- [7 Pillars of Game Feel](references/game-feel-pillars.md)
- [Code Snippets by Engine](references/snippets-by-engine.md)
- [Audit Example](examples/audit-sample.md)
