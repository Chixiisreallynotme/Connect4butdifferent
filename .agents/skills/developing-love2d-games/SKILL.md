---
name: developing-love2d-games
description: Expert guide for developing 2D games with the LÖVE (Love2D) framework and Lua. Use when the user mentions LÖVE, Love2D, love2d, LÖVE 2D, Lua game development, love.graphics, love.audio, love.physics, game framework Lua, .love file, conf.lua, or any LÖVE module. Covers project scaffolding, all core modules, shaders, physics, state machines, ECS, pixel art rendering, and distribution.
---

# Developing LÖVE 2D Games

## When to use this skill

- User wants to create, modify, or debug a LÖVE 2D game
- User asks about any `love.*` module or callback
- User mentions Lua game development or the LÖVE framework
- User needs help with LÖVE project structure, `conf.lua`, or `.love` packaging
- User asks about shaders (GLSL), physics (Box2D), particle systems, or camera systems in LÖVE
- User wants to implement game patterns: state machines, ECS, tweening, tilemaps
- User needs to optimize rendering (SpriteBatch, Canvas, Quad)

## Workflow

### Step 1: Understand the project scope

- [ ] Identify if this is a new project or modification of existing code
- [ ] Determine the game genre/type (platformer, RPG, puzzle, roguelike, etc.)
- [ ] Check the target LÖVE version (default to **11.5** unless specified)
- [ ] List required modules (graphics, audio, physics, etc.)

### Step 2: Scaffold or audit the project

For **new projects**, use the [Project Template](#project-template).  
For **existing projects**, audit with this checklist:

- [ ] `main.lua` exists with `love.load`, `love.update(dt)`, `love.draw`
- [ ] `conf.lua` exists with window/module settings
- [ ] Source files organized in `src/` or logical directories
- [ ] Assets organized in `assets/` (images, sounds, fonts, shaders)

### Step 3: Implement features

Use the reference sections below. Always follow [Lua Best Practices](#lua-best-practices) and [LÖVE Patterns](#architecture-patterns).

### Step 4: Test and validate

- [ ] Game launches without errors: `love .` from project root
- [ ] No nil access errors in console
- [ ] Frame rate stable (check with `love.timer.getFPS()`)
- [ ] Input handling responsive
- [ ] Audio plays correctly

---

## Project Template

### Minimal project structure

```
my-game/
├── main.lua
├── conf.lua
├── src/
│   ├── state_machine.lua
│   ├── states/
│   │   ├── menu.lua
│   │   ├── game.lua
│   │   └── pause.lua
│   ├── entities/
│   └── utils.lua
├── assets/
│   ├── images/
│   ├── sounds/
│   ├── fonts/
│   └── shaders/
└── lib/
```

### conf.lua template

```lua
function love.conf(t)
    t.identity = "my-game"
    t.version = "11.5"
    t.console = false

    t.window.title = "My Game"
    t.window.width = 800
    t.window.height = 600
    t.window.resizable = false
    t.window.vsync = 1
    t.window.msaa = 0

    -- Disable unused modules for performance
    t.modules.joystick = false
    t.modules.physics = false   -- Enable if needed
    t.modules.video = false
    t.modules.touch = false
end
```

### main.lua template

```lua
-- Require modules
local StateMachine = require("src.state_machine")

-- Game state
local game = {}

function love.load()
    -- Set default filter for pixel art (use "nearest") or smooth art ("linear")
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Initialize state machine
    game.sm = StateMachine:new()
    game.sm:switch("menu")
end

function love.update(dt)
    game.sm:update(dt)
end

function love.draw()
    game.sm:draw()
end

function love.keypressed(key, scancode, isrepeat)
    if key == "escape" then
        love.event.quit()
    end
    game.sm:keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button)
    game.sm:mousepressed(x, y, button)
end

function love.resize(w, h)
    game.sm:resize(w, h)
end
```

---

## LÖVE Core Modules Reference

### love.graphics — Drawing & Rendering

| Function | Purpose |
|---|---|
| `love.graphics.draw(drawable, x, y, r, sx, sy, ox, oy)` | Draw image/canvas/batch |
| `love.graphics.newImage(path)` | Load an image |
| `love.graphics.newCanvas(w, h)` | Off-screen render target |
| `love.graphics.newQuad(x, y, w, h, sw, sh)` | Sub-region of a texture (spritesheets) |
| `love.graphics.newSpriteBatch(texture, maxSprites)` | Batch draw calls for performance |
| `love.graphics.newParticleSystem(image, maxParticles)` | Particle effects |
| `love.graphics.newShader(code)` | GLSL shader |
| `love.graphics.newFont(path, size)` | Load a font |
| `love.graphics.print(text, x, y)` | Draw text |
| `love.graphics.printf(text, x, y, limit, align)` | Draw formatted text |
| `love.graphics.rectangle(mode, x, y, w, h, rx, ry)` | Draw rectangle |
| `love.graphics.circle(mode, x, y, radius)` | Draw circle |
| `love.graphics.line(x1, y1, x2, y2, ...)` | Draw lines |
| `love.graphics.setColor(r, g, b, a)` | Set draw color (0–1 range) |
| `love.graphics.setBackgroundColor(r, g, b)` | Set clear color |
| `love.graphics.push() / pop()` | Save/restore transform state |
| `love.graphics.translate(x, y)` | Move origin |
| `love.graphics.rotate(angle)` | Rotate (radians) |
| `love.graphics.scale(sx, sy)` | Scale |
| `love.graphics.setCanvas(canvas)` | Redirect drawing to canvas |
| `love.graphics.setShader(shader)` | Activate a shader |
| `love.graphics.setDefaultFilter(min, mag)` | `"nearest"` for pixel art, `"linear"` for smooth |
| `love.graphics.getWidth() / getHeight()` | Get window dimensions |
| `love.graphics.getDimensions()` | Returns width, height |

**Rendering to a Canvas (off-screen):**
```lua
local canvas = love.graphics.newCanvas(320, 240)

function love.draw()
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    -- draw game at low resolution
    love.graphics.setCanvas() -- reset to screen

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas, 0, 0, 0, scaleX, scaleY)
end
```

**Spritesheet with Quads:**
```lua
local sheet = love.graphics.newImage("spritesheet.png")
local quads = {}
local frameW, frameH = 32, 32
local cols = sheet:getWidth() / frameW

for i = 0, totalFrames - 1 do
    local col = i % cols
    local row = math.floor(i / cols)
    quads[i + 1] = love.graphics.newQuad(
        col * frameW, row * frameH,
        frameW, frameH,
        sheet:getDimensions()
    )
end

-- Draw frame
love.graphics.draw(sheet, quads[currentFrame], x, y)
```

### love.audio — Sound & Music

| Function | Purpose |
|---|---|
| `love.audio.newSource(path, type)` | Create audio source (`"static"` for SFX, `"stream"` for music) |
| `source:play()` | Play |
| `source:stop()` | Stop |
| `source:pause()` | Pause |
| `source:setLooping(bool)` | Loop toggle |
| `source:setVolume(0–1)` | Volume |
| `source:setPitch(pitch)` | Pitch shift |
| `source:clone()` | Clone for overlapping SFX |

```lua
local sfx = love.audio.newSource("assets/sounds/hit.wav", "static")
local music = love.audio.newSource("assets/sounds/bgm.ogg", "stream")
music:setLooping(true)
music:setVolume(0.5)
music:play()

-- Play overlapping SFX
sfx:clone():play()
```

### love.physics — Box2D Wrapper

```lua
function love.load()
    love.physics.setMeter(64) -- 64px = 1 meter
    world = love.physics.newWorld(0, 9.81 * 64, true) -- gravity

    -- Ground
    ground = {}
    ground.body = love.physics.newBody(world, 400, 550)
    ground.shape = love.physics.newRectangleShape(800, 50)
    ground.fixture = love.physics.newFixture(ground.body, ground.shape)

    -- Dynamic ball
    ball = {}
    ball.body = love.physics.newBody(world, 400, 100, "dynamic")
    ball.shape = love.physics.newCircleShape(20)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)
    ball.fixture:setRestitution(0.7) -- bounciness
end

function love.update(dt)
    world:update(dt)
end

-- Collision callbacks
world:setCallbacks(beginContact, endContact, preSolve, postSolve)

function beginContact(a, b, coll)
    -- a, b are Fixtures
end
```

### love.keyboard & love.mouse — Input

```lua
-- Polling (in love.update)
if love.keyboard.isDown("left") then
    player.x = player.x - speed * dt
end

-- Event callbacks
function love.keypressed(key, scancode, isrepeat)
    if key == "space" then player:jump() end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- left click
        shoot(x, y)
    end
end

-- Mouse position
local mx, my = love.mouse.getPosition()
```

### love.timer

```lua
local dt = love.timer.getDelta()
local fps = love.timer.getFPS()
local time = love.timer.getTime() -- seconds since start
love.timer.sleep(seconds)
```

### love.window

```lua
love.window.setTitle("My Game")
love.window.setMode(800, 600, {resizable = true, vsync = 1})
love.window.setFullscreen(true)
local w, h = love.window.getDesktopDimensions()
love.window.setIcon(love.image.newImageData("icon.png"))
```

### love.filesystem

```lua
-- Save data (stored in appdata by default)
love.filesystem.write("save.dat", data)
local content = love.filesystem.read("save.dat")
local exists = love.filesystem.getInfo("save.dat")

-- List directory
local files = love.filesystem.getDirectoryItems("assets/images")
```

### love.math

```lua
local rng = love.math.newRandomGenerator(seed)
local n = love.math.random(1, 10)
local noise = love.math.noise(x, y)         -- Perlin noise (0–1)
local bx, by = love.math.gammaToLinear(r, g, b)
```

---

## LÖVE Callbacks Reference

| Callback | When it fires |
|---|---|
| `love.load()` | Once, at startup |
| `love.update(dt)` | Every frame (logic) |
| `love.draw()` | Every frame (rendering) |
| `love.keypressed(key, scancode, isrepeat)` | Key down |
| `love.keyreleased(key)` | Key up |
| `love.mousepressed(x, y, button, istouch)` | Mouse button down |
| `love.mousereleased(x, y, button)` | Mouse button up |
| `love.mousemoved(x, y, dx, dy)` | Mouse movement |
| `love.wheelmoved(x, y)` | Scroll wheel |
| `love.resize(w, h)` | Window resized |
| `love.focus(focused)` | Window focus change |
| `love.quit()` | Before quitting (return `true` to cancel) |
| `love.textinput(text)` | Text input (for UI fields) |
| `love.errorhandler(msg)` | Custom error screen |
| `love.gamepadpressed(joystick, button)` | Gamepad button |
| `love.touchpressed(id, x, y, dx, dy, pressure)` | Touch input |

---

## Architecture Patterns

### State Machine

See [examples/state_machine.lua](examples/state_machine.lua) for a complete, reusable implementation.

**Usage pattern:**
```lua
local SM = require("src.state_machine")
local sm = SM:new()
sm:register("menu", require("src.states.menu"))
sm:register("game", require("src.states.game"))
sm:switch("menu")

-- In love.update / love.draw / love.keypressed:
sm:update(dt)
sm:draw()
sm:keypressed(key)
```

Each state is a table with methods: `enter(params)`, `exit()`, `update(dt)`, `draw()`, `keypressed(key)`.

### Entity-Component-System (ECS) — Lightweight

```lua
-- Entity is just an ID + component tables
local entities = {}
local nextId = 1

function spawnEntity(components)
    local id = nextId
    nextId = nextId + 1
    entities[id] = components
    return id
end

-- System: update all entities with "position" and "velocity"
function movementSystem(dt)
    for id, e in pairs(entities) do
        if e.position and e.velocity then
            e.position.x = e.position.x + e.velocity.dx * dt
            e.position.y = e.position.y + e.velocity.dy * dt
        end
    end
end
```

### Camera System

```lua
local Camera = {}
Camera.__index = Camera

function Camera:new(x, y, scale)
    return setmetatable({x = x or 0, y = y or 0, scale = scale or 1, rotation = 0}, Camera)
end

function Camera:attach()
    love.graphics.push()
    love.graphics.translate(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
    love.graphics.scale(self.scale)
    love.graphics.rotate(self.rotation)
    love.graphics.translate(-self.x, -self.y)
end

function Camera:detach()
    love.graphics.pop()
end

function Camera:follow(target, dt, lerp)
    lerp = lerp or 0.1
    self.x = self.x + (target.x - self.x) * lerp
    self.y = self.y + (target.y - self.y) * lerp
end

function Camera:screenToWorld(sx, sy)
    local w = love.graphics.getWidth() / 2
    local h = love.graphics.getHeight() / 2
    return (sx - w) / self.scale + self.x, (sy - h) / self.scale + self.y
end

return Camera
```

### Animation System

```lua
local Animation = {}
Animation.__index = Animation

function Animation:new(spritesheet, frameWidth, frameHeight, frameDuration, frames)
    local quads = {}
    local sw, sh = spritesheet:getDimensions()
    for _, f in ipairs(frames) do
        quads[#quads + 1] = love.graphics.newQuad(
            (f.col - 1) * frameWidth, (f.row - 1) * frameHeight,
            frameWidth, frameHeight, sw, sh
        )
    end
    return setmetatable({
        sheet = spritesheet,
        quads = quads,
        duration = frameDuration,
        timer = 0,
        current = 1,
        looping = true,
    }, Animation)
end

function Animation:update(dt)
    self.timer = self.timer + dt
    if self.timer >= self.duration then
        self.timer = self.timer - self.duration
        self.current = self.current + 1
        if self.current > #self.quads then
            self.current = self.looping and 1 or #self.quads
        end
    end
end

function Animation:draw(x, y, r, sx, sy, ox, oy)
    love.graphics.draw(self.sheet, self.quads[self.current], x, y, r, sx, sy, ox, oy)
end

return Animation
```

### Tweening (simple lerp)

```lua
local Tween = {}
Tween.__index = Tween

function Tween:new(target, props, duration, easing)
    local t = setmetatable({
        target = target,
        duration = duration,
        elapsed = 0,
        easing = easing or Tween.linear,
        from = {},
        to = props,
        done = false,
    }, Tween)
    for k, v in pairs(props) do
        t.from[k] = target[k]
    end
    return t
end

function Tween:update(dt)
    if self.done then return end
    self.elapsed = math.min(self.elapsed + dt, self.duration)
    local t = self.easing(self.elapsed / self.duration)
    for k, v in pairs(self.to) do
        self.target[k] = self.from[k] + (v - self.from[k]) * t
    end
    if self.elapsed >= self.duration then self.done = true end
end

-- Easing functions
function Tween.linear(t) return t end
function Tween.easeInQuad(t) return t * t end
function Tween.easeOutQuad(t) return t * (2 - t) end
function Tween.easeInOutQuad(t) return t < 0.5 and 2*t*t or -1+(4-2*t)*t end
function Tween.easeOutBack(t) local s=1.70158; return (t-1)^2*((s+1)*(t-1)+s)+1 end

return Tween
```

---

## Shaders (GLSL in LÖVE)

LÖVE uses a subset of GLSL. Shaders have two functions: `position` (vertex) and `effect` (fragment/pixel).

```lua
local shader = love.graphics.newShader([[
    // Uniform variables (set from Lua)
    uniform float time;
    uniform vec2 resolution;

    // Fragment shader: return pixel color
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords); // sample texture
        // Apply effect
        return pixel * color;
    }
]])

-- Use shader
love.graphics.setShader(shader)
shader:send("time", love.timer.getTime())
shader:send("resolution", {love.graphics.getDimensions()})
-- Draw stuff here
love.graphics.setShader() -- disable
```

**Common shader effects:**

- **Scanlines**: Darken every other row
- **CRT curve**: Barrel distortion on texture_coords
- **Chromatic aberration**: Offset R/G/B channels
- **Vignette**: Darken edges based on distance from center
- **Palette swap**: Remap colors via a lookup texture

See [examples/shaders.lua](examples/shaders.lua) for ready-to-use shader snippets.

---

## Pixel Art Rendering Pipeline

For crisp pixel art, use a low-res canvas upscaled to the window:

```lua
local GAME_W, GAME_H = 320, 240  -- internal resolution
local canvas
local scaleX, scaleY

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    canvas = love.graphics.newCanvas(GAME_W, GAME_H)
    canvas:setFilter("nearest", "nearest")
    calculateScale()
end

function calculateScale()
    local ww, wh = love.graphics.getDimensions()
    scaleX = math.floor(ww / GAME_W)
    scaleY = math.floor(wh / GAME_H)
    local scale = math.min(scaleX, scaleY)
    scaleX, scaleY = scale, scale
end

function love.resize(w, h)
    calculateScale()
end

function love.draw()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0)
    -- Draw game at internal resolution here
    love.graphics.setCanvas()

    local offsetX = (love.graphics.getWidth() - GAME_W * scaleX) / 2
    local offsetY = (love.graphics.getHeight() - GAME_H * scaleY) / 2
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas, offsetX, offsetY, 0, scaleX, scaleY)
end
```

---

## Lua Best Practices

### Tables & OOP

```lua
-- Class pattern via metatables
local Entity = {}
Entity.__index = Entity

function Entity:new(x, y)
    return setmetatable({x = x, y = y, alive = true}, Entity)
end

function Entity:update(dt) end
function Entity:draw() end

-- Inheritance
local Player = setmetatable({}, {__index = Entity})
Player.__index = Player

function Player:new(x, y)
    local p = Entity.new(self, x, y)
    p.speed = 200
    return setmetatable(p, Player)
end
```

### Key Lua patterns for LÖVE

- Use **local** everywhere possible — it's significantly faster than global access
- Use `ipairs` for sequential arrays, `pairs` for hash tables
- Avoid creating tables in `love.update` / `love.draw` — preallocate and reuse
- `require` caches modules — call it once, store the result
- Use `string.format` for formatted strings, not concatenation in hot paths
- `math.floor(x + 0.5)` for rounding
- `and/or` idiom: `local val = x or default`
- Varargs: `function f(...) local args = {...} end`

### Metatables cheat sheet

| Metamethod | Triggered by |
|---|---|
| `__index` | Accessing missing key |
| `__newindex` | Setting a new key |
| `__call` | Calling table as function |
| `__tostring` | `tostring()` |
| `__add / __sub / __mul / __div` | Arithmetic operators |
| `__eq / __lt / __le` | Comparison operators |
| `__len` | `#` operator |
| `__concat` | `..` operator |
| `__gc` | Garbage collection (Lua 5.2+) |

### Coroutines for cutscenes / async

```lua
local co

function startCutscene()
    co = coroutine.create(function()
        showDialogue("Hello!")
        wait(2) -- custom wait using coroutine.yield
        showDialogue("Welcome to the game!")
        wait(1)
        startGameplay()
    end)
end

local waitTimer = 0
function wait(seconds)
    waitTimer = seconds
    coroutine.yield()
end

function love.update(dt)
    if co and coroutine.status(co) ~= "dead" then
        if waitTimer > 0 then
            waitTimer = waitTimer - dt
        else
            coroutine.resume(co)
        end
    end
end
```

---

## Distribution & Packaging

### Create a .love file

```bash
# From the project root directory
# On Windows (PowerShell):
Compress-Archive -Path .\* -DestinationPath game.zip
Rename-Item game.zip game.love

# On Linux/macOS:
zip -9 -r game.love . -x ".*"
```

### Create a Windows executable

```bash
# Concatenate love.exe with .love file
copy /b love.exe+game.love game.exe
```

Then distribute `game.exe` alongside the LÖVE DLLs.

### conf.lua identity

Set `t.identity` in `conf.lua` — this determines the save directory name under the user's AppData.

---

## Common Pitfalls

- **Color range**: LÖVE 11+ uses 0–1 floats, not 0–255
- **Require paths**: Use dots, not slashes: `require("src.module")` not `require("src/module")`
- **Delta time**: Always multiply movement/timers by `dt` in `love.update`
- **Circular requires**: Avoid A requires B requires A — use lazy-loading or dependency injection
- **Filter mode**: Set `love.graphics.setDefaultFilter("nearest", "nearest")` in `love.load` for pixel art, or textures will be blurry
- **Canvas reset**: Always call `love.graphics.setCanvas()` (no args) to reset to screen after drawing to a canvas
- **Shader reset**: Always call `love.graphics.setShader()` after use
- **SpriteBatch**: Call `batch:clear()` and re-add sprites each frame, or use `batch:set(id, ...)` to update
- **Physics units**: Call `love.physics.setMeter()` before creating the world

---

## Resources

- [Shader examples](examples/shaders.lua)
- [State machine implementation](examples/state_machine.lua)
- [Tilemap loader](examples/tilemap.lua)
- [Advanced topics: ECS, networking, profiling](ADVANCED.md)
