-- UI Module
-- Text rendering and UI elements for menus

local Colors = require("src.colors")
local PixelCanvas = require("src.pixel_canvas")

local UI = {}

--- Draw centered text at y position
function UI.drawCenteredText(text, y, color, scale)
    color = color or Colors.TEXT
    scale = scale or 1
    Colors.set(color)
    local font = love.graphics.getFont()
    local textW = font:getWidth(text) * scale
    local x = math.floor((PixelCanvas.GAME_W - textW) / 2)
    love.graphics.print(text, x, y, 0, scale, scale)
end

--- Draw text with shadow
function UI.drawShadowText(text, x, y, color, scale)
    color = color or Colors.TEXT
    scale = scale or 1
    -- Shadow
    Colors.set(Colors.BLACK, 0.5)
    love.graphics.print(text, x + 1, y + 1, 0, scale, scale)
    -- Main text
    Colors.set(color)
    love.graphics.print(text, x, y, 0, scale, scale)
end

--- Draw centered text with shadow
function UI.drawCenteredShadowText(text, y, color, scale)
    color = color or Colors.TEXT
    scale = scale or 1
    local font = love.graphics.getFont()
    local textW = font:getWidth(text) * scale
    local x = math.floor((PixelCanvas.GAME_W - textW) / 2)
    UI.drawShadowText(text, x, y, color, scale)
end

--- Draw a button-like text element
function UI.drawButton(text, y, isSelected, isHovered, color)
    color = color or Colors.TEXT
    local font = love.graphics.getFont()
    local textW = font:getWidth(text)
    local x = math.floor((PixelCanvas.GAME_W - textW) / 2)

    if isSelected or isHovered then
        -- Selection indicator
        Colors.set(Colors.WHITE)
        love.graphics.rectangle("fill", x - 6, y + 1, 3, 3)
        UI.drawCenteredText(text, y, Colors.WHITE)
    else
        UI.drawCenteredText(text, y, Colors.TEXT_DIM)
    end
end

--- Check if mouse is over a centered button
function UI.isMouseOverButton(text, y, mx, my)
    local font = love.graphics.getFont()
    local textW = font:getWidth(text)
    local x = math.floor((PixelCanvas.GAME_W - textW) / 2)
    local textH = 8 -- Standard small font height
    -- Padding for easier clicking
    return mx >= x - 10 and mx <= x + textW + 10 and my >= y - 2 and my <= y + textH + 4
end

--- Draw player indicator (colored square + name)
function UI.drawPlayerIndicator(player, x, y, isActive, isMe)
    local color = player == 1 and Colors.PLAYER1 or Colors.PLAYER2
    Colors.set(color)
    love.graphics.rectangle("fill", x, y, 5, 5)

    local name = player == 1 and "P1" or "P2"
    if isMe then
        name = "YOU"
    end
    
    local textColor = isActive and Colors.WHITE or Colors.TEXT_DIM
    if isMe and not isActive then
        textColor = {Colors.GREEN[1]*0.7, Colors.GREEN[2]*0.7, Colors.GREEN[3]*0.7, 1}
    elseif isMe and isActive then
        textColor = Colors.GREEN
    end

    Colors.set(textColor)
    love.graphics.print(name, x + 7, y - 1)
end

--- Draw turn indicator at top of screen
function UI.drawTurnIndicator(currentPlayer, ox, oy)
    local y = 4
    -- Player 1 on left
    UI.drawPlayerIndicator(1, ox, y, currentPlayer == 1)
    -- Player 2 on right
    local boardW = 7 * 8
    UI.drawPlayerIndicator(2, ox + boardW - 15, y, currentPlayer == 2)

    -- Current player arrow
    local arrowX
    if currentPlayer == 1 then
        arrowX = ox + 2
    else
        arrowX = ox + boardW - 13
    end
    local pulse = math.sin(love.timer.getTime() * 5) > 0
    if pulse then
        Colors.set(Colors.WHITE)
        love.graphics.rectangle("fill", arrowX, y + 7, 3, 1)
    end
end

return UI
