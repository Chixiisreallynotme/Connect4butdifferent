# Tonal Guide for Shader Intensity

Match shader effect intensity to your game's emotional register. A cozy puzzle game should NOT use the same shader settings as a cyberpunk action roguelite.

---

## Tonal Profiles

| Genre / Tone | Scanlines | Chroma Aberration | Vignette | Bloom | Color Temp | Overall Intensity |
|---|---|---|---|---|---|---|
| **Cozy / Puzzle** | None | None | Gentle (0.8 radius) | Soft (0.2) | Warm | Very Low |
| **Retro Platformer** | Subtle (0.1) | Minimal (0.001) | Medium (0.7) | None | Neutral | Low |
| **Pixel Art Adventure** | Optional (0.08) | None | Gentle (0.75) | Soft (0.3) | Warm | Low-Medium |
| **Action Roguelite** | Medium (0.15) | Light (0.002) | Strong (0.6) | Medium (0.5) | Cool/Neutral | Medium |
| **Cyberpunk / Neon** | Heavy (0.25) | Strong (0.004) | Strong (0.5) | High (0.8) | Cool blue/pink | High |
| **Horror** | Medium (0.2) | Medium (0.003) | Very strong (0.4) | Low (0.2) | Desaturated cold | Medium-High |
| **Noir / Stylized** | Heavy (0.3) | None | Extreme (0.35) | None | High contrast B&W | High |
| **Fantasy RPG** | None | None | Medium (0.65) | Medium (0.4) | Warm golden | Medium |
| **Arcade / Fast-paced** | Light (0.12) | Light (0.002) | Medium (0.65) | Medium (0.5) | Vivid saturated | Medium |

---

## Decision Rules

1. **If the game is meant to feel cozy, relaxing, or meditative** → Minimize all screen-space distortions. Soft vignette only. Warm color tones.

2. **If the game is meant to feel tense, dark, or oppressive** → Strong vignette, desaturated colors, subtle chromatic aberration that increases during danger.

3. **If the game is retro/pixel art** → Scanlines are thematic but keep intensity ≤ 0.15. CRT curvature optional. NEVER blur pixel art.

4. **If the game has fast action** → Keep readability paramount. Bloom should highlight effects, not wash out the scene. Avoid heavy vignette that restricts peripheral vision.

5. **If the game targets photosensitive players** → No scanlines above 0.1, no chromatic aberration, no flickering effects, no rapid color transitions.

---

## Dynamic Intensity (Context-Sensitive)

Shaders are most effective when they react to game state:

| Game State | Suggested Shader Response |
|---|---|
| Normal gameplay | Baseline settings |
| Low health / danger | Increase vignette, add desaturation, slight chroma aberration |
| Boss fight | Increase contrast, bloom on boss attacks |
| Death / game over | Full desaturation, strong vignette, slow fade |
| Underwater | Blue tint, wave distortion, increased bloom |
| Dream / flashback | Soft focus, warm palette shift, vignette |
| Power-up / buff | Increase bloom, saturate colors, subtle screen pulse |
| Pause / menu | Reduce all effects, slight blur (depth of field feel) |

### Implementation pattern

```lua
-- Dynamic uniform interpolation
local function lerp_shader(shader, param, target, speed, dt)
    local current = shader_values[param] or 0
    shader_values[param] = current + (target - current) * speed * dt
    shader:send(param, shader_values[param])
end

-- Usage in love.update(dt):
if player.health < 30 then
    lerp_shader(shader, "u_vignetteRadius", 0.4, 3.0, dt)
    lerp_shader(shader, "u_desaturation", 0.5, 2.0, dt)
else
    lerp_shader(shader, "u_vignetteRadius", 0.7, 3.0, dt)
    lerp_shader(shader, "u_desaturation", 0.0, 2.0, dt)
end
```

---

## Accessibility Considerations

- **MUST** provide a toggle to disable ALL post-processing effects
- **MUST** allow individual effect intensity adjustment if possible
- **NEVER** use rapid flashing (> 3 Hz) in any shader effect
- **AVOID** high-contrast strobe effects without warning
- **CONSIDER** providing a "reduced effects" preset that keeps the art direction but lowers all intensities by 50%
