-- Pixel Particle System
-- Simple particle system for pixel-art scale effects

local Colors = require("src.colors")

local Particles = {}
Particles.__index = Particles

local particles = {}

--- Spawn a burst of pixel particles
function Particles.spawn(x, y, color, count, speed, lifetime)
    count = count or 8
    speed = speed or 30
    lifetime = lifetime or 0.8
    for i = 1, count do
        local angle = (i / count) * math.pi * 2 + love.math.random() * 0.5
        local spd = speed * (0.5 + love.math.random() * 0.5)
        particles[#particles + 1] = {
            x = x,
            y = y,
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd - 10,
            life = lifetime * (0.7 + love.math.random() * 0.3),
            maxLife = lifetime,
            color = color,
            size = love.math.random(1, 2),
        }
    end
end

--- Spawn celebration particles for winning cells
function Particles.celebrate(cells, ox, oy, cellSize, playerColor)
    for _, cell in ipairs(cells) do
        local cx = ox + (cell.col - 1) * cellSize + cellSize / 2
        local cy = oy + (cell.row - 1) * cellSize + cellSize / 2
        Particles.spawn(cx, cy, playerColor, 12, 40, 1.2)
    end
end

--- Update all particles
function Particles.update(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 60 * dt  -- pixel gravity
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

--- Draw all particles
function Particles.draw()
    for _, p in ipairs(particles) do
        local alpha = math.max(0, p.life / p.maxLife)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
    end
end

--- Clear all particles
function Particles.clear()
    particles = {}
end

--- Get particle count (for debugging)
function Particles.count()
    return #particles
end

return Particles
