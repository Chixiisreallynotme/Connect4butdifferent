-- Game Over State
-- Shows winner or draw with bigger crown, proper layout, SFX

local Colors = require("src.colors")
local UI = require("src.ui")
local Particles = require("src.particles")
local AudioManager = require("src.audio_manager")

local GameOver = {}

local winner = 0
local isDraw = false
local timer = 0
local selectedOption = 1
local hoveredOption = 0
local options = {"REMATCH", "MENU"}
local gameMode = "human"
local difficulty = 5

function GameOver:enter(params)
    params = params or {}
    winner = params.winner or 0
    isDraw = params.isDraw or false
    gameMode = params.mode or "human"
    difficulty = params.difficulty or 5
    timer = 0
    selectedOption = 1
    hoveredOption = 0
    Particles.clear()

    if not isDraw then
        local color = winner == 1 and Colors.PLAYER1 or Colors.PLAYER2
        for i = 1, 3 do
            Particles.spawn(
                80 + love.math.random(-30, 30),
                50 + love.math.random(-10, 10),
                color, 15, 50, 2
            )
        end
    end
end

function GameOver:exit()
    Particles.clear()
end

function GameOver:update(dt)
    timer = timer + dt
    Particles.update(dt)

    if not isDraw and love.math.random() < dt * 2 then
        local color = winner == 1 and Colors.PLAYER1 or Colors.PLAYER2
        Particles.spawn(
            love.math.random(20, 140),
            love.math.random(30, 70),
            color, 4, 15, 1.5
        )
    end
end

--- Draw pixel art crown centered at cx, with top at topY
local function drawCrown(cx, topY)
    local bounce = math.floor(math.sin(timer * 4) * 1.5)
    local y = topY + bounce

    -- Base gold
    Colors.set(Colors.YELLOW)
    -- Bottom base
    love.graphics.rectangle("fill", cx - 12, y + 8, 25, 4)
    
    -- Left spike
    love.graphics.rectangle("fill", cx - 12, y + 2, 4, 6)
    love.graphics.rectangle("fill", cx - 11, y, 2, 2)
    -- Mid-left small bump
    love.graphics.rectangle("fill", cx - 6, y + 5, 2, 3)
    -- Center spike
    love.graphics.rectangle("fill", cx - 2, y + 1, 5, 7)
    love.graphics.rectangle("fill", cx - 1, y - 1, 3, 2)
    -- Mid-right small bump
    love.graphics.rectangle("fill", cx + 5, y + 5, 2, 3)
    -- Right spike
    love.graphics.rectangle("fill", cx + 9, y + 2, 4, 6)
    love.graphics.rectangle("fill", cx + 10, y, 2, 2)

    -- Shading (Orange)
    Colors.set(Colors.ORANGE)
    -- Bottom edge
    love.graphics.rectangle("fill", cx - 12, y + 11, 25, 1)
    -- Inner depths between spikes
    love.graphics.rectangle("fill", cx - 8, y + 6, 2, 2)
    love.graphics.rectangle("fill", cx - 4, y + 6, 2, 2)
    love.graphics.rectangle("fill", cx + 3, y + 6, 2, 2)
    love.graphics.rectangle("fill", cx + 7, y + 6, 2, 2)
    
    -- Jewels
    Colors.set(Colors.RED)
    love.graphics.rectangle("fill", cx - 8, y + 8, 3, 2)
    Colors.set(Colors.BLUE)
    love.graphics.rectangle("fill", cx - 1, y + 8, 3, 2)
    Colors.set(Colors.GREEN)
    love.graphics.rectangle("fill", cx + 6, y + 8, 3, 2)

    -- Jewel Highlights (White)
    Colors.set(Colors.WHITE)
    love.graphics.rectangle("fill", cx - 8, y + 8, 1, 1)
    love.graphics.rectangle("fill", cx - 1, y + 8, 1, 1)
    love.graphics.rectangle("fill", cx + 6, y + 8, 1, 1)

    -- Spike shines (White)
    love.graphics.rectangle("fill", cx - 11, y, 1, 1)
    love.graphics.rectangle("fill", cx - 1, y - 1, 1, 1)
    love.graphics.rectangle("fill", cx + 10, y, 1, 1)
end

function GameOver:draw()
    -- Background
    Colors.set(Colors.BG)
    love.graphics.rectangle("fill", 0, 0, 160, 144)

    -- Decorative dither
    Colors.set(Colors.DARK_PURPLE, 0.1)
    for y = 0, 143, 3 do
        for x = (y % 6 == 0 and 0 or 1), 159, 3 do
            love.graphics.rectangle("fill", x, y, 1, 1)
        end
    end

    Particles.draw()

    if isDraw then
        -- No crown for draw
        UI.drawCenteredShadowText("DRAW!", 20, Colors.LIGHT_GREY, 2)
        UI.drawCenteredText("No winner", 48, Colors.TEXT_DIM)
    else
        local color = winner == 1 and Colors.PLAYER1 or Colors.PLAYER2

        -- Crown at top
        drawCrown(80, 4)

        -- Winner name (height ~28px)
        local name
        if gameMode == "cpu" then
            name = winner == 1 and "YOU WIN!" or "CPU WINS!"
        else
            name = winner == 1 and "P1 WINS!" or "P2 WINS!"
        end
        UI.drawCenteredShadowText(name, 16, color, 2)

        -- Sub-text (scale 1, below the name, height ~14px)
        if gameMode == "cpu" and winner == 1 then
            UI.drawCenteredText("Well played!", 46, Colors.WHITE)
        elseif gameMode == "cpu" and winner == 2 then
            UI.drawCenteredText("Try again!", 46, Colors.TEXT_DIM)
        end
    end

    -- Separator
    Colors.set(Colors.BOARD)
    love.graphics.rectangle("fill", 30, 64, 100, 1)

    -- Menu options (spacing 14px)
    local startY = 74
    for i, option in ipairs(options) do
        UI.drawButton(option, startY + (i - 1) * 14, i == selectedOption, i == hoveredOption)
    end

    -- Mode info (safe y position)
    if gameMode == "cpu" then
        Colors.set(Colors.DARK_GREY)
        love.graphics.print("LVL " .. difficulty, 2, 130)
    end
end

function GameOver:keypressed(key)
    if key == "up" or key == "w" then
        selectedOption = selectedOption - 1
        if selectedOption < 1 then selectedOption = #options end
        AudioManager.play("menuSelect")
    elseif key == "down" or key == "s" then
        selectedOption = selectedOption + 1
        if selectedOption > #options then selectedOption = 1 end
        AudioManager.play("menuSelect")
    elseif key == "return" or key == "space" then
        AudioManager.play("menuConfirm")
        if selectedOption == 1 then
            _G.stateMachine:switch("game", {mode = gameMode, difficulty = difficulty})
        elseif selectedOption == 2 then
            _G.stateMachine:switch("menu")
        end
    elseif key == "escape" then
        AudioManager.play("menuBack")
        _G.stateMachine:switch("menu")
    end
end

function GameOver:mousemoved(x, y)
    hoveredOption = 0
    local startY = 74
    for i, option in ipairs(options) do
        if UI.isMouseOverButton(option, startY + (i - 1) * 14, x, y) then
            hoveredOption = i
            if selectedOption ~= i then
                selectedOption = i
                AudioManager.play("menuSelect")
            end
            break
        end
    end
end

function GameOver:mousepressed(x, y, button)
    if button == 1 then
        local startY = 74
        for i, option in ipairs(options) do
            if UI.isMouseOverButton(option, startY + (i - 1) * 14, x, y) then
                selectedOption = i
                AudioManager.play("menuConfirm")
                if i == 1 then
                    _G.stateMachine:switch("game", {mode = gameMode, difficulty = difficulty})
                elseif i == 2 then
                    _G.stateMachine:switch("menu")
                end
                return
            end
        end
    end
end

return GameOver
