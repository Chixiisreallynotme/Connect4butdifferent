--- LÖVE 2D Shader Collection
-- Ready-to-use GLSL shaders. Copy the shader string and create with:
--   local shader = love.graphics.newShader(SHADER_CODE)

local Shaders = {}

---------------------------------------------------------------------------
-- SCANLINES — Classic CRT horizontal scanline effect
---------------------------------------------------------------------------
Shaders.scanlines = [[
    uniform float intensity; // 0.0 to 1.0, default 0.3

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
        vec4 pixel = Texel(texture, tc);
        float scanline = sin(sc.y * 3.14159) * 0.5 + 0.5;
        float factor = 1.0 - intensity * (1.0 - scanline);
        return pixel * color * vec4(factor, factor, factor, 1.0);
    }
]]

---------------------------------------------------------------------------
-- CRT CURVATURE — Barrel distortion simulating a curved screen
---------------------------------------------------------------------------
Shaders.crt = [[
    uniform vec2 resolution;
    uniform float curvature; // 0.0 to 0.1, default 0.04

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
        vec2 uv = tc * 2.0 - 1.0;
        uv *= 1.0 + curvature * dot(uv, uv);
        uv = (uv + 1.0) * 0.5;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            return vec4(0.0, 0.0, 0.0, 1.0);
        }
        return Texel(texture, uv) * color;
    }
]]

---------------------------------------------------------------------------
-- CHROMATIC ABERRATION — Subtle RGB channel offset
---------------------------------------------------------------------------
Shaders.chromatic = [[
    uniform float offset; // pixel offset, default 1.0–3.0
    uniform vec2 resolution;

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
        vec2 off = offset / resolution;
        float r = Texel(texture, tc + vec2(off.x, 0.0)).r;
        float g = Texel(texture, tc).g;
        float b = Texel(texture, tc - vec2(off.x, 0.0)).b;
        float a = Texel(texture, tc).a;
        return vec4(r, g, b, a) * color;
    }
]]

---------------------------------------------------------------------------
-- VIGNETTE — Darken screen edges
---------------------------------------------------------------------------
Shaders.vignette = [[
    uniform float radius;   // 0.5 to 1.0, default 0.75
    uniform float softness; // 0.1 to 0.5, default 0.3

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
        vec4 pixel = Texel(texture, tc);
        float dist = distance(tc, vec2(0.5, 0.5));
        float vig = smoothstep(radius, radius - softness, dist);
        return pixel * color * vec4(vig, vig, vig, 1.0);
    }
]]

---------------------------------------------------------------------------
-- PALETTE SWAP — Remap grayscale to a custom palette via lookup texture
---------------------------------------------------------------------------
Shaders.paletteSwap = [[
    uniform Image palette; // 1xN pixel palette texture

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
        vec4 pixel = Texel(texture, tc);
        float gray = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
        vec4 remapped = Texel(palette, vec2(gray, 0.5));
        return vec4(remapped.rgb, pixel.a) * color;
    }
]]

---------------------------------------------------------------------------
-- FLASH / HIT EFFECT — Flash sprite white (or any color)
---------------------------------------------------------------------------
Shaders.flash = [[
    uniform float flashAmount; // 0.0 (normal) to 1.0 (full white)
    uniform vec3 flashColor;   // default vec3(1.0, 1.0, 1.0)

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
        vec4 pixel = Texel(texture, tc);
        pixel.rgb = mix(pixel.rgb, flashColor, flashAmount);
        return pixel * color;
    }
]]

---------------------------------------------------------------------------
-- PIXELATE — Force a specific pixel grid size
---------------------------------------------------------------------------
Shaders.pixelate = [[
    uniform vec2 resolution; // target low-res (e.g., 160, 120)

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
        vec2 size = 1.0 / resolution;
        vec2 coord = floor(tc / size) * size + size * 0.5;
        return Texel(texture, coord) * color;
    }
]]

---------------------------------------------------------------------------
-- OUTLINE — Draw an outline around non-transparent sprites
---------------------------------------------------------------------------
Shaders.outline = [[
    uniform vec2 stepSize; // vec2(1.0/textureWidth, 1.0/textureHeight)
    uniform vec3 outlineColor; // default vec3(0.0, 0.0, 0.0)

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
        vec4 pixel = Texel(texture, tc);
        if (pixel.a > 0.1) {
            return pixel * color;
        }
        // Check neighbors
        float a = 0.0;
        a += Texel(texture, tc + vec2( stepSize.x, 0.0)).a;
        a += Texel(texture, tc + vec2(-stepSize.x, 0.0)).a;
        a += Texel(texture, tc + vec2(0.0,  stepSize.y)).a;
        a += Texel(texture, tc + vec2(0.0, -stepSize.y)).a;
        if (a > 0.1) {
            return vec4(outlineColor, 1.0) * color;
        }
        return vec4(0.0);
    }
]]

---------------------------------------------------------------------------
-- BLOOM (simple) — Blurred bright areas
-- NOTE: Best used with a two-pass approach (blur + composite)
---------------------------------------------------------------------------
Shaders.bloom = [[
    uniform float threshold; // brightness threshold, default 0.7
    uniform float intensity; // bloom intensity, default 0.5
    uniform vec2 direction;  // blur direction: vec2(1,0) horizontal, vec2(0,1) vertical

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
        vec4 pixel = Texel(texture, tc);
        float brightness = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
        if (brightness < threshold) return pixel * color;

        vec4 sum = vec4(0.0);
        float total = 0.0;
        for (float i = -4.0; i <= 4.0; i += 1.0) {
            float weight = 1.0 - abs(i) / 4.0;
            sum += Texel(texture, tc + direction * i * 0.003) * weight;
            total += weight;
        }
        vec4 blurred = sum / total;
        return mix(pixel, blurred, intensity) * color;
    }
]]

return Shaders
