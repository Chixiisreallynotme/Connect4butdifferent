# Shader Templates by Engine

Boilerplate templates for each supported engine. Copy the appropriate template, then customize the `effect` / `fragment` function body.

---

## LÖVE 2D (Lua + GLSL)

### Fragment-only shader

```lua
local shader = love.graphics.newShader([[
    // --- Uniforms ---
    uniform float u_time;
    uniform vec2 u_resolution;

    vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen_coords) {
        vec4 pixel = Texel(texture, uv);
        // --- Your effect here ---
        return pixel * color;
    }
]])
```

### Vertex + Fragment shader

```lua
local shader = love.graphics.newShader([[
    // --- Vertex Shader ---
    uniform mat4 u_transform;

    vec4 position(mat4 transform_projection, vec4 vertex_position) {
        return transform_projection * vertex_position;
    }
]],[[
    // --- Fragment Shader ---
    uniform float u_time;

    vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen_coords) {
        vec4 pixel = Texel(texture, uv);
        return pixel * color;
    }
]])
```

### Integration pattern (canvas-based post-processing)

```lua
local GAME_W, GAME_H = 320, 240
local canvas
local shader

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    canvas = love.graphics.newCanvas(GAME_W, GAME_H)
    canvas:setFilter("nearest", "nearest")
    shader = love.graphics.newShader("assets/shaders/effect.glsl")
end

function love.draw()
    -- 1. Draw game to canvas at internal resolution
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    drawGame()
    love.graphics.setCanvas()

    -- 2. Apply shader to full canvas
    love.graphics.setShader(shader)
    shader:send("u_time", love.timer.getTime())
    shader:send("u_resolution", {GAME_W, GAME_H})

    local scale = math.min(
        love.graphics.getWidth() / GAME_W,
        love.graphics.getHeight() / GAME_H
    )
    local ox = (love.graphics.getWidth() - GAME_W * scale) / 2
    local oy = (love.graphics.getHeight() - GAME_H * scale) / 2

    love.graphics.draw(canvas, ox, oy, 0, scale, scale)
    love.graphics.setShader()
end
```

### LÖVE GLSL dialect notes

- Use `Texel(texture, uv)` instead of `texture2D()`
- Use `Image` instead of `sampler2D` for the main texture
- Use `VaryingTexCoord` to access texture coordinates in vertex shader
- Use `extern` as alias for `uniform` (both work)
- `love_ScreenSize` is a built-in uniform (vec4: w, h, 1/w, 1/h)
- Max varying count is limited — avoid passing too many interpolants

---

## Unity (ShaderLab + HLSL/Cg)

### Unlit shader template (Built-in RP)

```hlsl
Shader "Custom/MyEffect"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Intensity ("Effect Intensity", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float _Intensity;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                // --- Your effect here ---
                return col;
            }
            ENDCG
        }
    }
}
```

### URP post-processing (Render Feature + Volume)

```hlsl
// Use a ScriptableRendererFeature + ScriptableRenderPass
// Fragment shader receives _BlitTexture (URP 14+) or _CameraColorTexture
// Bind via Blit(cmd, source, destination, material)
// Always check Unity version — URP API changes frequently
```

### Integration (C# — Built-in RP post-processing)

```csharp
[ExecuteInEditMode]
public class ShaderEffect : MonoBehaviour
{
    public Material effectMaterial;
    [Range(0f, 1f)] public float intensity = 0.5f;

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (effectMaterial != null)
        {
            effectMaterial.SetFloat("_Intensity", intensity);
            effectMaterial.SetFloat("_Time", Time.time);
            Graphics.Blit(source, destination, effectMaterial);
        }
        else
        {
            Graphics.Blit(source, destination);
        }
    }
}
```

---

## Godot 4 (GDShader)

### Canvas item shader (2D)

```gdshader
shader_type canvas_item;

// --- Uniforms ---
uniform float u_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float u_time;

void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    // --- Your effect here ---
    COLOR = pixel;
}
```

### Spatial shader (3D)

```gdshader
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D u_texture;
uniform float u_intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 pixel = texture(u_texture, UV);
    ALBEDO = pixel.rgb;
    ALPHA = pixel.a;
}
```

### Integration (GDScript)

```gdscript
# Attach ShaderMaterial to a Sprite2D, TextureRect, or ColorRect

@onready var shader_material := $Sprite2D.material as ShaderMaterial

func _process(delta: float) -> void:
    shader_material.set_shader_parameter("u_time", Time.get_ticks_msec() / 1000.0)
    shader_material.set_shader_parameter("u_intensity", intensity)
```

### Godot post-processing pattern

```
# Use a ColorRect covering the viewport with a ShaderMaterial
# Or use a BackBufferCopy node + shader reading SCREEN_TEXTURE
# In Godot 4: use hint_screen_texture for the sampler

shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
    vec4 screen = texture(screen_texture, SCREEN_UV);
    // --- Apply effect to screen ---
    COLOR = screen;
}
```

---

## WebGL (JavaScript + GLSL ES)

### Vertex shader

```glsl
attribute vec4 a_position;
attribute vec2 a_texCoord;
varying vec2 v_texCoord;

void main() {
    gl_Position = a_position;
    v_texCoord = a_texCoord;
}
```

### Fragment shader

```glsl
precision mediump float;

uniform sampler2D u_texture;
uniform float u_time;
uniform vec2 u_resolution;
varying vec2 v_texCoord;

void main() {
    vec4 pixel = texture2D(u_texture, v_texCoord);
    // --- Your effect here ---
    gl_FragColor = pixel;
}
```

### Integration (JavaScript)

```javascript
// Compile shaders → create program → set uniforms
const program = createShaderProgram(gl, vertexSrc, fragmentSrc);
gl.useProgram(program);

const timeLoc = gl.getUniformLocation(program, "u_time");
const resLoc = gl.getUniformLocation(program, "u_resolution");

function render(time) {
    gl.uniform1f(timeLoc, time * 0.001);
    gl.uniform2f(resLoc, canvas.width, canvas.height);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    requestAnimationFrame(render);
}
```

---

## Common Uniform Naming Convention

All shaders produced by this skill MUST use this prefix scheme:

| Prefix | Category | Example |
|--------|----------|---------|
| `u_` | General uniform | `u_time`, `u_resolution` |
| `u_color` | Color parameter | `u_colorTint`, `u_colorOverlay` |
| `u_intensity` | Strength/amount | `u_intensityBloom`, `u_intensityScanline` |
| `u_offset` | Displacement | `u_offsetChroma`, `u_offsetWave` |
| `u_size` | Dimension | `u_sizePixel`, `u_sizeKernel` |
