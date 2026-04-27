-- Tween / Easing Module
-- Lightweight value animator with easing functions
-- Inspired by kikito/tween.lua (MIT License)

local Tween = {}
Tween.__index = Tween

-- Easing functions (t normalized 0-1, returns 0-1)
local pow, sin, cos, pi, sqrt = math.pow, math.sin, math.cos, math.pi, math.sqrt

Tween.easing = {
    linear = function(t) return t end,
    inQuad = function(t) return t * t end,
    outQuad = function(t) return t * (2 - t) end,
    inOutQuad = function(t) return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t end,
    inCubic = function(t) return t * t * t end,
    outCubic = function(t) local u = t - 1; return u * u * u + 1 end,
    inOutCubic = function(t)
        return t < 0.5 and 4 * t * t * t or (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
    end,
    inBack = function(t) local s = 1.70158; return t * t * ((s + 1) * t - s) end,
    outBack = function(t) local s = 1.70158; t = t - 1; return t * t * ((s + 1) * t + s) + 1 end,
    outBounce = function(t)
        if t < 1 / 2.75 then return 7.5625 * t * t end
        if t < 2 / 2.75 then t = t - 1.5 / 2.75; return 7.5625 * t * t + 0.75 end
        if t < 2.5 / 2.75 then t = t - 2.25 / 2.75; return 7.5625 * t * t + 0.9375 end
        t = t - 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    end,
    outElastic = function(t)
        if t == 0 or t == 1 then return t end
        return pow(2, -10 * t) * sin((t - 0.075) * (2 * pi) / 0.3) + 1
    end,
}

--- Create a new tween
--- @param from number Start value
--- @param to number End value
--- @param duration number Duration in seconds
--- @param easingName string Name of easing function (default "linear")
function Tween:new(from, to, duration, easingName)
    local t = setmetatable({}, Tween)
    t.from = from
    t.to = to
    t.duration = duration
    t.elapsed = 0
    t.easingFn = Tween.easing[easingName or "linear"] or Tween.easing.linear
    t.done = false
    return t
end

--- Update the tween, returns true when complete
function Tween:update(dt)
    if self.done then return true end
    self.elapsed = math.min(self.elapsed + dt, self.duration)
    if self.elapsed >= self.duration then
        self.done = true
    end
    return self.done
end

--- Get the current interpolated value
function Tween:getValue()
    if self.done then return self.to end
    local t = self.elapsed / self.duration
    local eased = self.easingFn(t)
    return self.from + (self.to - self.from) * eased
end

--- Reset the tween to start
function Tween:reset()
    self.elapsed = 0
    self.done = false
end

return Tween
