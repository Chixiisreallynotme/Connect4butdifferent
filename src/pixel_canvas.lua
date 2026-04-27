-- Pixel Art Canvas Pipeline
-- Renders at low internal resolution (160x144) then upscales to window with nearest-neighbor

local shaders = require("src.shaders")

local PixelCanvas = {}
PixelCanvas.__index = PixelCanvas

PixelCanvas.GAME_W = 160
PixelCanvas.GAME_H = 144

function PixelCanvas:new()
    local pc = setmetatable({}, PixelCanvas)
    pc.canvas = love.graphics.newCanvas(PixelCanvas.GAME_W, PixelCanvas.GAME_H)
    pc.canvas:setFilter("nearest", "nearest")
    pc.scale = 1
    pc.offsetX = 0
    pc.offsetY = 0
    pc:calculateScale()
    return pc
end

function PixelCanvas:calculateScale()
    local ww, wh = love.graphics.getDimensions()
    local scaleX = math.floor(ww / PixelCanvas.GAME_W)
    local scaleY = math.floor(wh / PixelCanvas.GAME_H)
    self.scale = math.max(1, math.min(scaleX, scaleY))
    self.offsetX = math.floor((ww - PixelCanvas.GAME_W * self.scale) / 2)
    self.offsetY = math.floor((wh - PixelCanvas.GAME_H * self.scale) / 2)
end

function PixelCanvas:beginDraw()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 1)
end

function PixelCanvas:endDraw()
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Apply CRT shader
    shaders.applyCRT(self.canvas, love.timer.getTime(), PixelCanvas.GAME_W, PixelCanvas.GAME_H)
    love.graphics.draw(self.canvas, self.offsetX, self.offsetY, 0, self.scale, self.scale)
    shaders.reset()
end

--- Convert screen (mouse) coordinates to internal pixel coordinates
function PixelCanvas:screenToPixel(sx, sy)
    local px = math.floor((sx - self.offsetX) / self.scale)
    local py = math.floor((sy - self.offsetY) / self.scale)
    return px, py
end

--- Convert internal pixel coordinates to screen coordinates
function PixelCanvas:pixelToScreen(px, py)
    return px * self.scale + self.offsetX, py * self.scale + self.offsetY
end

function PixelCanvas:resize(w, h)
    self:calculateScale()
end

return PixelCanvas
