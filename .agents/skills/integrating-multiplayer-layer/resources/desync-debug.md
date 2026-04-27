# Desync Debugging Checklist

Desync = two peers have different game states despite receiving the same inputs.
It is always a determinism bug. Use this checklist to hunt it down.

---

## Step 1 — Verify Hash Exchange is Working

Add a state hash to every synchronized tick. Desync is detected, not assumed:

```lua
-- Lua / LÖVE2D
local function hashState(state)
  -- Quick checksum over critical state fields
  local s = string.format("%d|%d|%d|%d",
    state.player1.x, state.player1.y,
    state.player2.x, state.player2.y)
  local h = 0
  for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 2^32 end
  return h
end
```

```gdscript
# Godot 4
func get_state_hash() -> int:
  var s = "%d|%d|%d|%d" % [p1.position.x, p1.position.y, p2.position.x, p2.position.y]
  return s.hash()
```

Exchange hash every tick. Log the tick number and both hashes when they differ.

---

## Step 2 — Bisect by Tick Number

Once you know desync starts at tick T:
- Log the FULL game state at tick T-1 on both peers — they should be identical
- Log the input received at tick T on both peers — they should be identical
- If state(T-1) and input(T) are identical but state(T) differs → the simulation function is non-deterministic

---

## Step 3 — Common Culprits

### Floating-Point Position
```lua
-- BAD: floating point accumulation diverges across platforms
player.x = player.x + speed * dt  -- dt varies slightly per frame

-- GOOD: fixed timestep
local FIXED_DT = 1/60
player.x = player.x + speed * FIXED_DT
```

### Un-seeded Random
```lua
-- BAD
local roll = math.random(1, 6)

-- GOOD: use a seeded RNG, synced at session start
local rng = love.math.newRandomGenerator(sessionSeed)
local roll = rng:random(1, 6)
```

### Hash-map Iteration (Lua `pairs`, Python `dict`)
```lua
-- BAD: pairs() iteration order is undefined in Lua
for id, entity in pairs(entities) do
  entity:update(dt)
end

-- GOOD: iterate a sorted array of IDs
local ids = {}
for id in pairs(entities) do ids[#ids+1] = id end
table.sort(ids)
for _, id in ipairs(ids) do entities[id]:update(dt) end
```

### Wall-Clock Time in Logic
```lua
-- BAD: os.clock() differs between machines
if os.clock() - lastFire > cooldown then fire() end

-- GOOD: use simulation tick counter
if (currentTick - lastFireTick) > cooldownTicks then fire() end
```

### Entity Spawn IDs from OS
```lua
-- BAD: using memory addresses or OS-assigned IDs
entity.id = tostring(entity)  -- pointer address — different on each machine

-- GOOD: monotonic counter shared via game events
local nextId = 1
function spawnEntity()
  local id = nextId
  nextId = nextId + 1
  -- broadcast id to all peers so they use the same value
  return id
end
```

---

## Step 4 — Isolation Test

Simulate both peers locally on one machine with identical inputs:
```lua
-- Force both "peers" to use the exact same simulation function
-- with the exact same inputs — state MUST match after every tick
local stateA = deepCopy(initialState)
local stateB = deepCopy(initialState)
for tick = 1, 600 do
  local input = generateInput(tick)
  stateA = simulate(stateA, input, input)
  stateB = simulate(stateB, input, input)
  assert(hash(stateA) == hash(stateB), "Desync at tick " .. tick)
end
```
If this passes but online desync still occurs, the problem is in **input delivery** (packets arriving out of order or with wrong tick labels), not in the simulation.

---

## Step 5 — Logging Template

```
[NET] Tick 142 | Hash A: 0xDEADBEEF | Hash B: 0xCAFEBABE | DESYNC
[NET] Input at 142 | P1: {move=right} | P2: {move=right} | MATCH
[NET] State at 141 | A: {x=100,y=200} | B: {x=100,y=200} | MATCH
→ Simulation bug: same state + same input → different output
```
