local shaders = {}

local palettizeShader
local outlineShader
local crtShader
local sparkleShader

function shaders.init()
    palettizeShader = love.graphics.newShader("src/shaders/palettize.glsl")
    outlineShader = love.graphics.newShader("src/shaders/outline.glsl")
    crtShader = love.graphics.newShader("src/shaders/crt.glsl")
    sparkleShader = love.graphics.newShader("src/shaders/sparkle.glsl")
    
    if crtShader:hasUniform("intensity") then
        crtShader:send("intensity", 0.4)
    end
end

function shaders.applyToken(color)
    love.graphics.setShader(palettizeShader)
    if palettizeShader:hasUniform("targetColor") then
        palettizeShader:send("targetColor", {color[1], color[2], color[3]})
    end
end

function shaders.applyOutline(color, texWidth, texHeight)
    love.graphics.setShader(outlineShader)
    if outlineShader:hasUniform("outlineColor") then
        outlineShader:send("outlineColor", {color[1], color[2], color[3]})
    end
    if outlineShader:hasUniform("textureSize") and texWidth and texHeight then
        outlineShader:send("textureSize", {texWidth, texHeight})
    end
end

function shaders.applyCRT(canvas, time, texWidth, texHeight)
    love.graphics.setShader(crtShader)
    if crtShader:hasUniform("textureSize") and texWidth and texHeight then
        crtShader:send("textureSize", {texWidth, texHeight})
    end
end

function shaders.applySparkle(time)
    love.graphics.setShader(sparkleShader)
    if sparkleShader:hasUniform("time") then
        sparkleShader:send("time", time)
    end
end

function shaders.reset()
    love.graphics.setShader()
end

return shaders
