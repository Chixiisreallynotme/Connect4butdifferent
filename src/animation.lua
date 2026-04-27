-- Animation Module
-- Manages active tweens/animations for the game

local Tween = require("src.tween")

local Animation = {}
Animation.__index = Animation

-- Active animations pool
local activeAnimations = {}

--- Create a new tracked animation
function Animation.create(from, to, duration, easingName)
    local anim = Tween:new(from, to, duration, easingName)
    activeAnimations[#activeAnimations + 1] = anim
    return anim
end

--- Update all active animations
function Animation.updateAll(dt)
    for i = #activeAnimations, 1, -1 do
        activeAnimations[i]:update(dt)
        if activeAnimations[i].done then
            table.remove(activeAnimations, i)
        end
    end
end

--- Clear all animations
function Animation.clearAll()
    activeAnimations = {}
end

--- Drop animation: piece falls from top to target row
function Animation.createDrop(fromY, toY, callback)
    local anim = Tween:new(fromY, toY, 0.35, "outBounce")
    anim.callback = callback
    activeAnimations[#activeAnimations + 1] = anim
    return anim
end

--- Flash/blink animation for win highlight
function Animation.createBlink(duration)
    local anim = Tween:new(0, 1, duration or 0.5, "linear")
    anim.looping = true
    activeAnimations[#activeAnimations + 1] = anim
    return anim
end

return Animation
