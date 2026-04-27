# Common Effect Catalog

Engine-agnostic shader algorithms. Adapt to target engine dialect using [shader-templates.md](shader-templates.md).

---

## 1. CRT / Retro Display

**Reference games**: *Shovel Knight*, *Celeste*, *Hyper Light Drifter*

### Scanlines
```glsl
float scanline = sin(screen_coords.y * u_scanlineCount * 3.14159) * 0.5 + 0.5;
pixel.rgb *= mix(1.0, scanline, u_scanlineIntensity);
```
| Uniform | Type | Range | Default |
|---------|------|-------|---------|
| `u_scanlineCount` | float | 100–500 | 240.0 |
| `u_scanlineIntensity` | float | 0.0–0.5 | 0.15 |

### Barrel Distortion
```glsl
vec2 crt_curve(vec2 uv, float amount) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / vec2(amount);
    uv = uv + uv * offset * offset;
    return uv * 0.5 + 0.5;
}
```
| Uniform | Type | Range | Default |
|---------|------|-------|---------|
| `u_curvatureAmount` | float | 3.0–20.0 | 6.0 |

### Chromatic Aberration
```glsl
float r = Texel(texture, uv + vec2(u_chromaOffset, 0.0)).r;
float g = Texel(texture, uv).g;
float b = Texel(texture, uv - vec2(u_chromaOffset, 0.0)).b;
pixel = vec4(r, g, b, pixel.a);
```
| Uniform | Type | Range | Default |
|---------|------|-------|---------|
| `u_chromaOffset` | float | 0.0005–0.005 | 0.002 |

---

## 2. Vignette

**Reference games**: *Limbo*, *Inside*, *Darkest Dungeon*

```glsl
float vignette(vec2 uv, float radius, float softness) {
    vec2 center = uv - 0.5;
    float dist = length(center);
    return smoothstep(radius, radius - softness, dist);
}
```
| Uniform | Type | Range | Default |
|---------|------|-------|---------|
| `u_vignetteRadius` | float | 0.3–0.9 | 0.7 |
| `u_vignetteSoftness` | float | 0.1–0.5 | 0.3 |

---

## 3. Bloom / Glow

**Reference games**: *Hollow Knight*, *Dead Cells*, *Transistor*

```glsl
// Single-pass 5x5 kernel approximation
vec2 texel = 1.0 / u_resolution;
vec4 blur = vec4(0.0);
for (int x = -2; x <= 2; x++) {
    for (int y = -2; y <= 2; y++) {
        blur += Texel(texture, uv + vec2(float(x), float(y)) * texel * u_bloomRadius);
    }
}
blur /= 25.0;
pixel += max(blur - vec4(u_bloomThreshold), vec4(0.0)) * u_bloomIntensity;
```
| Uniform | Type | Range | Default |
|---------|------|-------|---------|
| `u_bloomThreshold` | float | 0.3–0.9 | 0.7 |
| `u_bloomIntensity` | float | 0.0–2.0 | 0.5 |
| `u_bloomRadius` | float | 1.0–5.0 | 2.0 |

---

## 4. Color Grading

**Reference games**: *Celeste*, *Katana ZERO*, *Stardew Valley*

```glsl
// Desaturation
float gray = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
pixel.rgb = mix(pixel.rgb, vec3(gray), u_desaturation);

// Contrast
pixel.rgb = (pixel.rgb - 0.5) * u_contrast + 0.5;

// Tint
pixel.rgb = mix(pixel.rgb, pixel.rgb * u_tintColor, u_tintStrength);
```

---

## 5. Outline / Edge Detection (Sobel)

**Reference games**: *Cuphead*, *Borderlands*, *Okami*

```glsl
// Sample 3x3 Sobel kernel on luminance
// Produces edge intensity 0.0–1.0
// Apply: pixel.rgb = mix(pixel.rgb, u_outlineColor.rgb, edge * step(u_outlineThreshold, edge));
```

---

## 6. Wave Distortion

**Reference games**: *Stardew Valley*, *Hyper Light Drifter*

```glsl
vec2 wave_distort(vec2 uv, float time, float amp, float freq, float speed) {
    uv.x += sin(uv.y * freq + time * speed) * amp;
    uv.y += cos(uv.x * freq + time * speed * 0.7) * amp * 0.5;
    return uv;
}
```

---

## 7. Dissolve

**Reference games**: *Hades*, *Hollow Knight*

```glsl
float noise = Texel(u_noiseTexture, uv).r;
float edge = smoothstep(u_dissolveProgress, u_dissolveProgress + u_dissolveEdgeWidth, noise);
pixel.a *= step(u_dissolveProgress, noise);
pixel.rgb = mix(u_dissolveEdgeColor.rgb, pixel.rgb, edge);
```

---

## 8. Dithering

**Reference games**: *Return of the Obra Dinn*

```glsl
// Bayer 4x4 ordered dithering — map luminance to binary via threshold matrix
```

---

## Combining Effects

Chain in a single fragment shader for 2D:
```
1. CRT curvature (uv transform)
2. Sample texture
3. Chromatic aberration
4. Scanlines
5. Vignette
6. Color grading
```

Use multi-pass for expensive effects (bloom):
```
Pass 1: Game → Canvas A
Pass 2: Bright extract A → Canvas B
Pass 3–4: Blur B (H then V)
Pass 5: Composite A + B → Screen
```
