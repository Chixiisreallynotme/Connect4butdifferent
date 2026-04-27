-- Screen Shake Module
-- Adds camera shake for impactful moments

local Screenshake = {}
Screenshake.__index = Screenshake

local shake = {
    intensity = 0,
    duration = 0,
    elapsed = 0,
    active = false,
    dx = 0,
    dy = 0,
}

--- Trigger a screen shake
function Screenshake.trigger(intensity, duration)
    shake.intensity = intensity or 2
    shake.duration = duration or 0.3
    shake.elapsed = 0
    shake.active = true
end

--- Update shake state
function Screenshake.update(dt)
    if not shake.active then return end
    shake.elapsed = shake.elapsed + dt
    if shake.elapsed >= shake.duration then
        shake.active = false
        shake.dx = 0
        shake.dy = 0
        return
    end
    local decay = 1 - (shake.elapsed / shake.duration)
    local mag = shake.intensity * decay
    shake.dx = math.floor((love.math.random() * 2 - 1) * mag + 0.5)
    shake.dy = math.floor((love.math.random() * 2 - 1) * mag + 0.5)
end

--- Get current shake offset (returns integer pixels for pixel-perfect rendering)
function Screenshake.getOffset()
    return shake.dx, shake.dy
end

--- Check if shaking
function Screenshake.isActive()
    return shake.active
end

return Screenshake
