# Integration Example: CRT Post-Processing for a LÖVE 2D Pixel Art Game

This example demonstrates the full Game Shader Integrator pipeline applied to a retro pixel art platformer in LÖVE 2D.

---

## Context

> "I want a CRT retro look for my pixel art platformer in LÖVE 2D. Internal resolution is 320×240, upscaled to window. The game has a cozy retro vibe like Shovel Knight."

**Engine**: LÖVE 2D (Lua + GLSL)  
**Art direction**: 16-color pixel art, warm retro aesthetic  
**Internal resolution**: 320×240  
**Target FPS**: 60  
**Tone**: Cozy retro platformer

---

## Step 2 — Research Result

- LÖVE uses `Texel()` instead of `texture2D()`, `Image` instead of `sampler2D`
- Post-processing is done via canvas → shader → draw pattern
- For cozy retro: scanlines ≤ 0.1 intensity, gentle curvature, no aggressive chroma
- Reference: *Shovel Knight* uses optional CRT filter with subtle scanlines and slight curvature

---

## Step 3 — Design Spec

### Shader Design Spec: Cozy CRT

**Visual target**: Subtle CRT television feel — gentle screen curvature, faint scanlines, warm color shift. Reference: *Shovel Knight*'s optional CRT mode.

**Technique**: Single-pass fragment shader combining barrel distortion, scanlines, vignette, and warm color tint.

**Uniforms**:

| Name | Type | Default | Purpose |
|------|------|---------|---------|
| `u_resolution` | vec2 | (320, 240) | Internal resolution |
| `u_time` | float | — | Animation time |
| `u_curvature` | float | 8.0 | Barrel distortion amount (higher = less curve) |
| `u_scanlineIntensity` | float | 0.08 | Scanline darkening strength |
| `u_scanlineCount` | float | 240.0 | Number of scanline rows |
| `u_vignetteRadius` | float | 0.75 | Vignette start distance |
| `u_vignetteSoftness` | float | 0.35 | Vignette fade width |
| `u_warmth` | float | 0.05 | Warm color shift amount |
| `u_enabled` | bool | true | Runtime toggle |

**Pass structure**: Single-pass (game canvas → CRT shader → screen)

**Performance estimate**:
- Texture samples: 1
- Math operations: ~20 ALU
- Expected cost: < 0.1 ms at 320×240

---

## Step 4 — Complete Shader

### `assets/shaders/crt.glsl`

```glsl
// CRT Post-Processing Shader — Cozy Retro
// Designed for pixel art games at low internal resolution
// Single-pass: curvature + scanlines + vignette + warm tint

uniform vec2 u_resolution;
uniform float u_curvature;        // 8.0 = subtle, 4.0 = strong
uniform float u_scanlineIntensity; // 0.0–0.3, keep ≤ 0.1 for cozy
uniform float u_scanlineCount;    // match internal vertical resolution
uniform float u_vignetteRadius;   // 0.3–0.9
uniform float u_vignetteSoftness; // 0.1–0.5
uniform float u_warmth;           // 0.0–0.15

vec2 crt_curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / vec2(u_curvature);
    uv = uv + uv * offset * offset;
    return uv * 0.5 + 0.5;
}

float vignette(vec2 uv) {
    vec2 center = uv - 0.5;
    float dist = length(center);
    return smoothstep(u_vignetteRadius, u_vignetteRadius - u_vignetteSoftness, dist);
}

vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen_coords) {
    // 1. Apply CRT curvature
    vec2 curved_uv = crt_curve(uv);

    // Discard pixels outside the curved screen area
    if (curved_uv.x < 0.0 || curved_uv.x > 1.0 ||
        curved_uv.y < 0.0 || curved_uv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    // 2. Sample texture
    vec4 pixel = Texel(texture, curved_uv);

    // 3. Scanlines — darken based on vertical position
    float scanline = sin(curved_uv.y * u_scanlineCount * 3.14159) * 0.5 + 0.5;
    pixel.rgb *= mix(1.0, scanline, u_scanlineIntensity);

    // 4. Vignette — darken edges
    pixel.rgb *= vignette(curved_uv);

    // 5. Warm tint — slight red/yellow shift for cozy feel
    pixel.r += u_warmth;
    pixel.g += u_warmth * 0.5;
    // Clamp to valid range
    pixel.rgb = clamp(pixel.rgb, 0.0, 1.0);

    return pixel * color;
}
```

### Integration code — `main.lua` additions

```lua
-- In love.load():
local GAME_W, GAME_H = 320, 240
local gameCanvas = love.graphics.newCanvas(GAME_W, GAME_H)
gameCanvas:setFilter("nearest", "nearest")

local crtShader = love.graphics.newShader("assets/shaders/crt.glsl")
local crtEnabled = true

-- Set default uniforms
crtShader:send("u_resolution", {GAME_W, GAME_H})
crtShader:send("u_curvature", 8.0)
crtShader:send("u_scanlineIntensity", 0.08)
crtShader:send("u_scanlineCount", GAME_H)
crtShader:send("u_vignetteRadius", 0.75)
crtShader:send("u_vignetteSoftness", 0.35)
crtShader:send("u_warmth", 0.05)

-- In love.draw():
love.graphics.setCanvas(gameCanvas)
love.graphics.clear(0, 0, 0)
drawGame() -- your existing draw logic
love.graphics.setCanvas()

-- Calculate integer scale for crisp pixels
local scale = math.min(
    math.floor(love.graphics.getWidth() / GAME_W),
    math.floor(love.graphics.getHeight() / GAME_H)
)
local ox = (love.graphics.getWidth() - GAME_W * scale) / 2
local oy = (love.graphics.getHeight() - GAME_H * scale) / 2

-- Apply CRT shader (or bypass)
if crtEnabled then
    love.graphics.setShader(crtShader)
end
love.graphics.setColor(1, 1, 1)
love.graphics.draw(gameCanvas, ox, oy, 0, scale, scale)
love.graphics.setShader()

-- In love.keypressed(key):
if key == "f9" then
    crtEnabled = not crtEnabled  -- Runtime toggle
end
```

---

## Step 5 — Perception Scoring

| Pillar       | Score /10 | Status | Notes |
|-------------|-----------|--------|-------|
| Readability | 9         | ✅     | Scanline intensity at 0.08 doesn't obscure text or sprites |
| Comfort     | 10        | ✅     | No flicker, no rapid color changes, static effect |
| Immersion   | 8         | ✅     | Warm CRT feel matches cozy retro tone |
| Coherence   | 9         | ✅     | Effect calibrated for cozy register per tonal guide |

---

## Step 6 — Tuning Guide

| Uniform | Cozy Default | Arcade Preset | Intense Preset |
|---------|-------------|---------------|----------------|
| `u_curvature` | 8.0 | 6.0 | 4.0 |
| `u_scanlineIntensity` | 0.08 | 0.15 | 0.25 |
| `u_scanlineCount` | 240.0 | 240.0 | 240.0 |
| `u_vignetteRadius` | 0.75 | 0.65 | 0.5 |
| `u_vignetteSoftness` | 0.35 | 0.3 | 0.25 |
| `u_warmth` | 0.05 | 0.02 | 0.0 |

**Runtime toggle**: Press F9 to enable/disable (accessibility).
