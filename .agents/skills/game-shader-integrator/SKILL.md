---
name: integrating-game-shaders
description: Analyzes a game's engine, art direction, and performance constraints to design and integrate a custom shader. Use when the user mentions shader, post-processing, visual effect, GLSL, HLSL, ShaderLab, GDShader, render pipeline, CRT effect, bloom, vignette, chromatic aberration, palette swap, outline shader, water shader, lighting shader, shadow shader, dissolve effect, scanlines, dithering, cel-shading, toon shader, glow, distortion, or any visual rendering technique for a game project.
---

# Game Shader Integrator

## Use this skill when

- Designing a custom shader for an existing or new game project
- Adding post-processing effects (CRT, bloom, vignette, color grading, etc.)
- Implementing surface shaders (water, fire, dissolve, outline, toon)
- Diagnosing visual rendering issues or optimizing shader performance
- Porting a shader effect between engines (Unity ↔ Godot ↔ LÖVE ↔ Web/WebGL)
- The user describes a desired visual style and needs a shader to achieve it
- Integrating multiple shader passes into a coherent render pipeline

## Do not use this skill when

- The task is purely about game logic with no rendering component
- The user needs UI/UX design without shader involvement
- The question targets CPU-side performance (not GPU-bound)
- The task is about 3D modeling, rigging, or asset creation

## Instructions

Follow this 6-step pipeline in order. Do NOT skip steps.

### Step 1 — Deep Project Analysis

Gather or identify the following. Ask the user for anything not already available:

- [ ] **Engine & language**: Unity/C#/ShaderLab, Godot/GDScript/GDShader, LÖVE/Lua/GLSL, Web/JS/WebGL, Unreal/C++/HLSL, custom
- [ ] **Render pipeline**: Forward vs Deferred, 2D vs 3D, built-in vs URP vs HDRP (Unity), Vulkan vs GL (Godot)
- [ ] **Art direction**: Pixel art, hand-drawn, realistic, stylized, minimalist, retro, neon, noir
- [ ] **Target resolution & scale**: Internal res, upscale factor, canvas-based rendering
- [ ] **Performance budget**: Target platform (mobile/PC/console), target FPS, existing draw call count
- [ ] **Desired effect**: What the user wants the shader to achieve visually
- [ ] **Player perception goals**: Readability needs, immersion style, comfort constraints (photosensitivity, motion sensitivity)

If context is already available from the codebase, acknowledge and proceed to Step 2.

### Step 2 — Research Best Techniques

Before writing any shader code, **research the optimal technique** for the declared engine and effect.

**Mandatory research actions:**
- Use Context7 MCP (`resolve-library-id` → `query-docs`) to fetch current shader documentation for the target engine
- Search for reference implementations matching the desired visual effect
- Identify the shader language dialect and API constraints of the target engine

**Decision matrix** — select the approach by cross-referencing:

| Factor | Impact on shader design |
|---|---|
| 2D pixel art | Use integer coordinates, nearest filtering, avoid sub-pixel blending |
| 2D HD / vector | Safe to use smooth gradients, anti-aliasing, SDF techniques |
| 3D forward | Single pass preferred, limit texture samples, pack data |
| 3D deferred | Can leverage G-buffer data, multiple passes are acceptable |
| Mobile | Max 4 texture samples, avoid branching, prefer half precision |
| PC/Console | Full precision allowed, compute shaders viable, multi-pass OK |

**Reference games** — identify 1–3 shipped games that achieve the desired look. Cite them explicitly. Analyze what techniques they use.

### Step 3 — Shader Design Specification

Produce a structured Artifact containing:

```markdown
## Shader Design Spec: [Effect Name]

### Visual target
[1-2 sentence description of the intended look + cited reference games]

### Technique
[Chosen algorithm/approach with justification]

### Uniforms
| Name | Type | Default | Purpose |
|------|------|---------|---------|
| ... | ... | ... | ... |

### Pass structure
[Single-pass / multi-pass diagram]

### Performance estimate
- Texture samples: X
- Math operations: ~X ALU
- Expected cost: X ms at target resolution

### Player perception checklist
- [ ] Readability: text and game elements remain legible
- [ ] Comfort: no high-frequency flicker, strobe, or aggressive motion
- [ ] Immersion: effect reinforces the game's tonal identity
- [ ] Coherence: shader integrates with existing visual style, doesn't feel "pasted on"
```

**Present this spec to the user for validation BEFORE writing shader code.**

### Step 4 — Implement the Shader

Write the complete shader using the target engine's shader language. Follow these hard rules:

**Code standards:**
- All tunable values MUST be uniforms/externals with descriptive names (e.g., `u_scanlineIntensity`, `u_vignetteRadius`)
- Include inline comments explaining non-obvious math
- Use named constants for magic numbers
- Group uniforms by category (time, appearance, performance)

**Engine-specific templates:**
- See [references/shader-templates.md](references/shader-templates.md) for boilerplate by engine
- See [references/effect-catalog.md](references/effect-catalog.md) for common effect implementations

**Integration code:**
- Provide the complete host-side code (Lua/C#/GDScript/JS) to load, send uniforms, and activate the shader
- Include the render pipeline hookup (canvas routing, render pass setup, material assignment)

### Step 5 — Player Experience Validation

Evaluate the shader against the **4 Perception Pillars**:

| Pillar | Question | Pass criteria |
|---|---|---|
| **Readability** | Can the player read all text, distinguish all game elements? | No essential information obscured by the effect |
| **Comfort** | Does the effect cause visual fatigue or discomfort? | No high-frequency strobe (>3 Hz), motion sickness triggers minimized |
| **Immersion** | Does the effect pull the player into the game world? | Effect feels native to the art direction, not a generic filter |
| **Coherence** | Does the shader match the game's tonal register? | Cozy game = subtle effects; action game = aggressive effects (see [references/tonal-guide.md](references/tonal-guide.md)) |

Produce a scoring table:

```markdown
| Pillar       | Score /10 | Status   | Notes |
|-------------|-----------|----------|-------|
| Readability | X         | ✅/⚠️/❌ | ...   |
| Comfort     | X         | ✅/⚠️/❌ | ...   |
| Immersion   | X         | ✅/⚠️/❌ | ...   |
| Coherence   | X         | ✅/⚠️/❌ | ...   |
```

If any pillar scores ❌ (0–3), revise the shader before delivery.

### Step 6 — Delivery & Integration Guide

Deliver:

1. **Complete shader file(s)** — ready to drop into the project
2. **Integration code** — host-side setup with all uniform bindings
3. **Tuning guide** — a table of all uniforms with recommended ranges and descriptions
4. **Performance notes** — profiling advice, fallback strategy for lower-end hardware
5. **Optional toggle** — code to enable/disable the shader at runtime (accessibility)

## Hard Rules

- MUST research current engine documentation before writing any shader code
- MUST produce a Design Spec artifact (Step 3) BEFORE implementation
- MUST cite at least one reference game that achieves the target visual style
- MUST use engine-appropriate shader language (GLSL for LÖVE/WebGL, ShaderLab/HLSL for Unity, GDShader for Godot 4)
- MUST provide complete integration code, not just the shader in isolation
- MUST include a runtime toggle mechanism for accessibility
- NEVER use hardcoded magic numbers — all visual parameters MUST be uniforms
- NEVER ship a shader that scores ❌ on Readability or Comfort without explicit user override
- NEVER assume render pipeline — always verify (URP vs Built-in, Forward vs Deferred)
- MUST adapt shader complexity to the declared performance budget

## Resources

- [Shader Templates by Engine](references/shader-templates.md)
- [Common Effect Catalog](references/effect-catalog.md)
- [Tonal Guide for Shader Intensity](references/tonal-guide.md)
- [Integration Example: CRT Post-Processing](examples/crt-postprocess.md)
