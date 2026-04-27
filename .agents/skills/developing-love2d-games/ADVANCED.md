# Advanced LÖVE 2D Topics

## Table of Contents

- [Entity-Component-System (Full)](#entity-component-system-full)
- [Collision Detection](#collision-detection)
- [Tilemap Collision](#tilemap-collision)
- [Screen Shake](#screen-shake)
- [Particle Presets](#particle-presets)
- [Save/Load System](#saveload-system)
- [Scene Transitions](#scene-transitions)
- [Object Pooling](#object-pooling)
- [Profiling & Performance](#profiling--performance)
- [Popular Libraries](#popular-libraries)
- [Mobile & Gamepad Input](#mobile--gamepad-input)

---

## Entity-Component-System (Full)

A more robust ECS with typed component queries:

```lua
local World = {}
World.__index = World

function World:new()
    return setmetatable({
        entities = {},
        systems = {},
        nextId = 1,
    }, World)
end

function World:spawn(...)
    local id = self.nextId
    self.nextId = self.nextId + 1
    self.entities[id] = {}
    for _, component in ipairs({...}) do
        self.entities[id][component._type] = component
    end
    return id
end

function World:despawn(id)
    self.entities[id] = nil
end

function World:get(id, componentType)
    return self.entities[id] and self.entities[id][componentType]
end

function World:query(...)
    local types = {...}
    local results = {}
    for id, components in pairs(self.entities) do
        local match = true
        for _, t in ipairs(types) do
            if not components[t] then match = false; break end
        end
        if match then results[#results + 1] = {id = id, c = components} end
    end
    return results
end

function World:addSystem(system)
    self.systems[#self.systems + 1] = system
end

function World:update(dt)
    for _, sys in ipairs(self.systems) do
        sys(self, dt)
    end
end

-- Component constructors
local function Position(x, y) return {_type = "position", x = x, y = y} end
local function Velocity(dx, dy) return {_type = "velocity", dx = dx, dy = dy} end
local function Sprite(image) return {_type = "sprite", image = image} end
local function Health(hp) return {_type = "health", current = hp, max = hp} end

-- System example
local function movementSystem(world, dt)
    for _, e in ipairs(world:query("position", "velocity")) do
        e.c.position.x = e.c.position.x + e.c.velocity.dx * dt
        e.c.position.y = e.c.position.y + e.c.velocity.dy * dt
    end
end
```

---

## Collision Detection

### AABB (Axis-Aligned Bounding Box)

```lua
function checkAABB(a, b)
    return a.x < b.x + b.w and
           a.x + a.w > b.x and
           a.y < b.y + b.h and
           a.y + a.h > b.y
end
```

### Circle vs Circle

```lua
function checkCircles(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist < a.radius + b.radius
end
```

### Spatial Hash Grid

For many entities, use a spatial hash to reduce collision checks:

```lua
local SpatialHash = {}
SpatialHash.__index = SpatialHash

function SpatialHash:new(cellSize)
    return setmetatable({cells = {}, cellSize = cellSize}, SpatialHash)
end

function SpatialHash:clear()
    self.cells = {}
end

function SpatialHash:key(x, y)
    local cx = math.floor(x / self.cellSize)
    local cy = math.floor(y / self.cellSize)
    return cx .. "," .. cy
end

function SpatialHash:insert(entity)
    local k = self:key(entity.x, entity.y)
    self.cells[k] = self.cells[k] or {}
    self.cells[k][#self.cells[k] + 1] = entity
end

function SpatialHash:query(x, y)
    local k = self:key(x, y)
    return self.cells[k] or {}
end

function SpatialHash:queryArea(x, y, w, h)
    local results = {}
    local seen = {}
    for gx = x, x + w, self.cellSize do
        for gy = y, y + h, self.cellSize do
            for _, e in ipairs(self:query(gx, gy)) do
                if not seen[e] then
                    seen[e] = true
                    results[#results + 1] = e
                end
            end
        end
    end
    return results
end
```

---

## Tilemap Collision

```lua
--- Check if a rectangle collides with solid tiles.
-- @param tilemap Tilemap  the tilemap object
-- @param x, y, w, h  entity bounding box in world coords
-- @param solidTiles table  set of tile IDs that are solid, e.g. {[1]=true, [2]=true}
-- @return boolean
function checkTilemapCollision(tilemap, x, y, w, h, solidTiles)
    local col1, row1 = tilemap:worldToGrid(x, y)
    local col2, row2 = tilemap:worldToGrid(x + w - 1, y + h - 1)

    for row = row1, row2 do
        for col = col1, col2 do
            local id = tilemap:getTile(col, row)
            if solidTiles[id] then
                return true
            end
        end
    end
    return false
end
```

---

## Screen Shake

```lua
local shake = {intensity = 0, duration = 0, timer = 0}

function triggerShake(intensity, duration)
    shake.intensity = intensity
    shake.duration = duration
    shake.timer = duration
end

function updateShake(dt)
    if shake.timer > 0 then
        shake.timer = shake.timer - dt
    end
end

function applyShake()
    if shake.timer > 0 then
        local fade = shake.timer / shake.duration
        local ox = (math.random() * 2 - 1) * shake.intensity * fade
        local oy = (math.random() * 2 - 1) * shake.intensity * fade
        love.graphics.translate(ox, oy)
    end
end

-- Usage in love.draw:
-- love.graphics.push()
-- applyShake()
-- ... draw game ...
-- love.graphics.pop()
```

---

## Particle Presets

```lua
function createFireParticles(image)
    local ps = love.graphics.newParticleSystem(image, 200)
    ps:setParticleLifetime(0.5, 1.5)
    ps:setEmissionRate(80)
    ps:setSizeVariation(0.5)
    ps:setSizes(1.5, 0.5, 0.1)
    ps:setLinearAcceleration(-20, -100, 20, -50)
    ps:setColors(
        1, 0.8, 0.2, 1,   -- start: bright yellow
        1, 0.3, 0.0, 0.8, -- mid: orange
        0.2, 0.0, 0.0, 0  -- end: dark red, transparent
    )
    ps:setSpeed(30, 80)
    ps:setSpread(math.pi / 6)
    ps:setDirection(-math.pi / 2) -- upward
    return ps
end

function createSmokeParticles(image)
    local ps = love.graphics.newParticleSystem(image, 100)
    ps:setParticleLifetime(1, 3)
    ps:setEmissionRate(20)
    ps:setSizes(0.5, 2, 3)
    ps:setLinearAcceleration(-10, -40, 10, -20)
    ps:setColors(
        0.5, 0.5, 0.5, 0.6,
        0.3, 0.3, 0.3, 0
    )
    ps:setSpeed(10, 30)
    ps:setSpread(math.pi / 4)
    ps:setDirection(-math.pi / 2)
    return ps
end

function createSparkParticles(image)
    local ps = love.graphics.newParticleSystem(image, 50)
    ps:setParticleLifetime(0.1, 0.5)
    ps:setEmissionRate(0) -- use emit(n) for bursts
    ps:setSizes(0.8, 0.1)
    ps:setLinearAcceleration(-200, -200, 200, 200)
    ps:setColors(1, 1, 0.8, 1, 1, 0.5, 0, 0)
    ps:setSpeed(100, 300)
    ps:setSpread(math.pi * 2)
    return ps
end
```

---

## Save/Load System

```lua
local Save = {}

--- Serialize a Lua table to a string.
function Save.serialize(t)
    -- Simple serializer for flat/nested tables of primitives
    local parts = {}
    for k, v in pairs(t) do
        local key = type(k) == "number" and ("[" .. k .. "]") or k
        local val
        if type(v) == "table" then
            val = Save.serialize(v)
        elseif type(v) == "string" then
            val = string.format("%q", v)
        else
            val = tostring(v)
        end
        parts[#parts + 1] = key .. "=" .. val
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

--- Save game data to a file.
function Save.write(filename, data)
    local str = "return " .. Save.serialize(data)
    love.filesystem.write(filename, str)
end

--- Load game data from a file.
function Save.read(filename)
    local info = love.filesystem.getInfo(filename)
    if not info then return nil end
    local content = love.filesystem.read(filename)
    local fn = loadstring(content)
    if fn then return fn() end
    return nil
end

return Save
```

---

## Scene Transitions

```lua
local Transition = {}
Transition.__index = Transition

function Transition:new(duration, callback)
    return setmetatable({
        duration = duration,
        timer = 0,
        phase = "out", -- "out" = fade to black, "in" = fade from black
        callback = callback,
        active = false,
        alpha = 0,
    }, Transition)
end

function Transition:start()
    self.active = true
    self.phase = "out"
    self.timer = 0
    self.alpha = 0
end

function Transition:update(dt)
    if not self.active then return end
    self.timer = self.timer + dt
    local half = self.duration / 2

    if self.phase == "out" then
        self.alpha = math.min(self.timer / half, 1)
        if self.timer >= half then
            self.phase = "in"
            self.timer = 0
            if self.callback then self.callback() end
        end
    else
        self.alpha = 1 - math.min(self.timer / half, 1)
        if self.timer >= half then
            self.active = false
            self.alpha = 0
        end
    end
end

function Transition:draw()
    if not self.active then return end
    love.graphics.setColor(0, 0, 0, self.alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    love.graphics.setColor(1, 1, 1)
end

return Transition
```

---

## Object Pooling

Avoids garbage collection spikes from frequent allocations:

```lua
local Pool = {}
Pool.__index = Pool

function Pool:new(factory, resetFn, initialSize)
    local pool = setmetatable({
        factory = factory,
        reset = resetFn,
        objects = {},
        active = {},
    }, Pool)
    for i = 1, (initialSize or 0) do
        pool.objects[#pool.objects + 1] = factory()
    end
    return pool
end

function Pool:acquire(...)
    local obj
    if #self.objects > 0 then
        obj = table.remove(self.objects)
    else
        obj = self.factory()
    end
    self.reset(obj, ...)
    self.active[#self.active + 1] = obj
    return obj
end

function Pool:release(obj)
    for i, a in ipairs(self.active) do
        if a == obj then
            table.remove(self.active, i)
            self.objects[#self.objects + 1] = obj
            return
        end
    end
end

function Pool:releaseAll()
    for i = #self.active, 1, -1 do
        self.objects[#self.objects + 1] = self.active[i]
        self.active[i] = nil
    end
end

return Pool
```

---

## Profiling & Performance

### FPS overlay

```lua
function drawDebugInfo()
    love.graphics.setColor(0, 1, 0)
    love.graphics.print(
        string.format("FPS: %d | Mem: %.1f KB | Entities: %d",
            love.timer.getFPS(),
            collectgarbage("count"),
            entityCount
        ),
        4, 4
    )
    love.graphics.setColor(1, 1, 1)
end
```

### Performance tips

- **SpriteBatch**: Batch identical textures. One draw call instead of hundreds.
- **Canvas caching**: Draw static elements (background, tilemap) to a Canvas once, redraw only on change.
- **Avoid allocations in update/draw**: Preallocate tables, reuse vectors.
- **`love.graphics.setDefaultFilter("nearest")`**: Cheaper than linear filtering.
- **Limit particle counts**: Cap ParticleSystem buffer and emission rate.
- **Spatial hashing**: For collision detection with many entities.
- **Garbage collection**: Call `collectgarbage("step")` to spread GC across frames if needed.

---

## Popular Libraries

| Library | Purpose | Link |
|---|---|---|
| **HUMP** | Camera, timer, vector, gamestate | github.com/vrld/hump |
| **bump.lua** | AABB collision detection & response | github.com/kikito/bump.lua |
| **STI** | Tiled map loader (.tmx) | github.com/karai17/Simple-Tiled-Implementation |
| **anim8** | Sprite animation | github.com/kikito/anim8 |
| **flux** | Tweening | github.com/rxi/flux |
| **SUIT** | Immediate-mode GUI | github.com/vrld/suit |
| **lume** | Utility functions | github.com/rxi/lume |
| **push** | Resolution-independent rendering | github.com/Ulydev/push |
| **middleclass** | OOP with classes | github.com/kikito/middleclass |
| **sock** | Networking (TCP/UDP) | github.com/camchenry/sock.lua |
| **cargo** | Asset loader with lazy loading | github.com/bjornbytes/cargo |
| **windfield** | Physics wrapper (Box2D) | github.com/a327ex/windfield |

---

## Mobile & Gamepad Input

### Touch input

```lua
function love.touchpressed(id, x, y, dx, dy, pressure)
    -- id uniquely identifies each finger
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    -- track swipes
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    -- handle tap
end

-- Get all active touches
local touches = love.touch.getTouches()
for _, id in ipairs(touches) do
    local x, y = love.touch.getPosition(id)
end
```

### Gamepad input

```lua
function love.gamepadpressed(joystick, button)
    if button == "a" then player:jump() end
    if button == "start" then togglePause() end
end

function love.update(dt)
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        local js = joysticks[1]
        local lx = js:getGamepadAxis("leftx")
        local ly = js:getGamepadAxis("lefty")
        -- Apply deadzone
        if math.abs(lx) > 0.2 then player.x = player.x + lx * speed * dt end
        if math.abs(ly) > 0.2 then player.y = player.y + ly * speed * dt end
    end
end
```
