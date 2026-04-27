---
name: creating-pixel-art-assets
description: Generates pixel art assets at a user-specified resolution using the generate_image tool. Use when the user mentions pixel art, sprite, tileset, game asset, retro art, 8-bit art, 16-bit art, or requests low-resolution graphics for games or projects.
---

# Creating Pixel Art Assets

## When to use this skill

- User asks to create pixel art, sprites, tilesets, icons, or game assets
- User mentions a specific pixel resolution (8x8, 16x16, 32x32, 64x64, 128x128)
- User wants retro-style, 8-bit, or 16-bit graphics
- User needs consistent asset sets for a game or application
- User asks for a character sprite, item icon, background tile, or UI element in pixel art style

## Workflow

### Step 1: Gather Requirements

Before generating any asset, confirm the following with the user:

- [ ] **Resolution**: Target pixel grid (e.g., 16x16, 32x32, 64x64, 128x128)
- [ ] **Palette** (optional): A named palette or custom colors (see [Palettes](#palettes))
- [ ] **Asset type**: Character, tile, icon, UI element, background, item, etc.
- [ ] **Subject**: What the asset depicts (e.g., "a knight", "a health potion", "grass tile")
- [ ] **Style notes** (optional): Outline style, shading, isometric, top-down, side-view, etc.
- [ ] **Quantity**: Single asset or batch of related assets

If the user does not specify a palette, default to a vibrant 16-color palette suitable for the subject.

### Step 2: Build the Prompt

Construct the `generate_image` prompt using this template:

```
Pixel art [ASSET_TYPE], [SUBJECT], [RESOLUTION] pixel grid, [PALETTE_DESC], [STYLE_NOTES]. 
Sharp pixels, no anti-aliasing, no blurring, clean pixel edges, retro game aesthetic.
Flat solid-color background ([BG_COLOR]).
```

**Key rules for prompt construction:**

- Always include `"pixel art"` and `"sharp pixels, no anti-aliasing, no blurring"` to enforce the pixel style
- Always specify the resolution as `"NxN pixel grid"` (e.g., `"32x32 pixel grid"`)
- Always request `"clean pixel edges"` to avoid subpixel smoothing
- Specify a flat solid background color for easy extraction (e.g., `"flat magenta background #FF00FF"` or `"flat transparent-style black background"`)
- For character sprites, specify the view: `"front-facing"`, `"side-view"`, `"3/4 view"`, `"top-down"`
- For tilesets, specify `"seamless tiling"` if needed

### Step 3: Generate the Asset

Use the `generate_image` tool:

```
Tool: generate_image
Prompt: <constructed prompt from Step 2>
ImageName: <descriptive_snake_case_name> (e.g., "knight_sprite_32x32", "health_potion_icon")
```

**Naming convention**: `[subject]_[type]_[resolution]`
Examples: `knight_sprite_32x32`, `grass_tile_16x16`, `sword_icon_64x64`

### Step 4: Review and Iterate

After generation, present the asset to the user and ask:

- Does the style match their vision?
- Should any colors be adjusted?
- Do they want variations (e.g., animation frames, alternate colors)?
- Do they need the asset in a different view/pose?

If generating a **batch**, maintain consistency by reusing the same style descriptors and palette across all prompts.

## Palettes

### Preset Palettes

Use these palette descriptions in your prompts when the user selects one:

| Palette Name  | Description for Prompt | Colors |
|---|---|---|
| **PICO-8** | `"PICO-8 16-color palette (black, dark blue, dark purple, dark green, brown, dark grey, light grey, white, red, orange, yellow, green, blue, indigo, pink, peach)"` | 16 |
| **Game Boy** | `"Game Boy 4-color palette (darkest green #0f380f, dark green #306230, light green #8bac0f, lightest green #9bbc0f)"` | 4 |
| **NES** | `"NES-style retro palette, limited to 4 colors per sprite, classic 8-bit Nintendo color tones"` | 4-per-sprite |
| **CGA** | `"CGA 4-color palette (black, cyan, magenta, white)"` | 4 |
| **Monokai** | `"Monokai-inspired pixel palette (dark background, green, orange, pink, purple, yellow, white)"` | 7 |
| **Endesga 32** | `"Endesga-32 palette, rich 32-color pixel art palette with warm and cool tones"` | 32 |
| **Sweetie 16** | `"Sweetie 16 palette, modern 16-color pixel art palette with soft pastel and vibrant accents"` | 16 |
| **1-Bit** | `"1-bit monochrome palette, black and white only, high contrast"` | 2 |

### Custom Palette

If the user provides specific hex colors, format them as:
`"limited color palette using only: #RRGGBB, #RRGGBB, #RRGGBB, ..."`

## Resolution Guide

| Resolution | Best For | Grid Size | Detail Level |
|---|---|---|---|
| **8x8** | Micro icons, minimal tiles | Very small | Extremely limited, iconic shapes only |
| **16x16** | Classic game sprites, tiles, small icons | Small | Basic shapes, 2-3 color shading |
| **32x32** | Detailed sprites, RPG characters, items | Medium | Good detail, facial features possible |
| **64x64** | Portraits, large icons, detailed items | Large | High detail, expressive faces, complex shapes |
| **128x128** | Splash art, large portraits, scene tiles | Very large | Full illustration level in pixel style |
| **256x256** | Full scene illustrations, poster art | Extra large | Near-illustration detail, complex compositions |

## Asset Type Templates

### Character Sprite
```
Pixel art character sprite, [DESCRIPTION], [RESOLUTION] pixel grid, [PALETTE], 
[VIEW]-view, full body visible, centered in frame,
sharp pixels, no anti-aliasing, no blurring, clean pixel edges, retro game aesthetic.
Flat solid [BG_COLOR] background.
```

### Tileset Tile
```
Pixel art game tile, [DESCRIPTION], [RESOLUTION] pixel grid, [PALETTE],
seamless tiling, top-down view, consistent lighting from top-left,
sharp pixels, no anti-aliasing, no blurring, clean pixel edges, retro game aesthetic.
```

### Item / Icon
```
Pixel art game icon, [DESCRIPTION], [RESOLUTION] pixel grid, [PALETTE],
centered, clear silhouette, recognizable at small size,
sharp pixels, no anti-aliasing, no blurring, clean pixel edges, retro game aesthetic.
Flat solid [BG_COLOR] background.
```

### UI Element
```
Pixel art UI element, [DESCRIPTION], [RESOLUTION] pixel grid, [PALETTE],
clean borders, consistent padding, game interface style,
sharp pixels, no anti-aliasing, no blurring, clean pixel edges, retro game aesthetic.
Flat solid [BG_COLOR] background.
```

### Background / Scene
```
Pixel art background scene, [DESCRIPTION], [RESOLUTION] pixel grid, [PALETTE],
atmospheric, layered depth, [PERSPECTIVE] perspective,
sharp pixels, no anti-aliasing, no blurring, clean pixel edges, retro game aesthetic.
```

### Animation Frame Set
When creating animation frames, generate each frame individually with consistent descriptors:
```
Pixel art [SUBJECT] animation frame [N] of [TOTAL], [ACTION_DESCRIPTION],
[RESOLUTION] pixel grid, [PALETTE], [VIEW]-view,
matching previous frames in style and proportions,
sharp pixels, no anti-aliasing, no blurring, clean pixel edges.
Flat solid [BG_COLOR] background.
```

Name each frame: `[subject]_[action]_frame[N]_[resolution]`

## Batch Generation Checklist

When generating multiple related assets:

- [ ] Define a shared palette and style descriptor string
- [ ] Use the same background color across all assets
- [ ] Keep the same view/perspective for related sprites
- [ ] Use a consistent naming scheme
- [ ] Generate a reference asset first, confirm style, then proceed with the rest
- [ ] Present all assets together for final review

## Tips for Best Results

- **Lower resolutions (8x8, 16x16)**: Use simpler descriptions, fewer details, emphasize shape and silhouette
- **Higher resolutions (64x64+)**: Can include more detail, shading, and nuance
- **Consistent sets**: Always reuse the exact same palette and style string across a batch
- **Transparency**: Use `"flat magenta #FF00FF background"` for easy chroma-key removal
- **Outlines**: Specify `"with dark pixel outline"` or `"no outline, outlineless"` explicitly
- **Shading**: Specify `"flat shading"`, `"dithered shading"`, or `"cel shading"` as needed
