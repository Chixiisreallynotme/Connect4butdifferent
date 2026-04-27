-- Menu State
-- Title screen with mode selection, AI difficulty slider, and animated title

local Colors = require("src.colors")
local UI = require("src.ui")
local Particles = require("src.particles")
local AudioManager = require("src.audio_manager")

local Menu = {}

local timer = 0
local titleBounce = 0

-- Menu navigation
local menuPhase = "main"  -- "main" or "difficulty"
local selectedOption = 1
local hoveredOption = 0
local hoveredBack = false
local hoveredLArrow = false
local hoveredRArrow = false
local hoveredEnter = false

-- Main menu options
local mainOptions = {"VS HUMAN", "VS CPU", "ONLINE", "QUIT"}

-- AI difficulty slider
local aiDifficulty = 5  -- 1-10
local isDraggingSlider = false

function Menu:enter()
    timer = 0
    selectedOption = 1
    hoveredOption = 0
    hoveredBack = false
    hoveredLArrow = false
    hoveredRArrow = false
    hoveredEnter = false
    menuPhase = "main"
    aiDifficulty = 5
    isDraggingSlider = false
    Particles.clear()
    for i = 1, 5 do
        Particles.spawn(
            love.math.random(20, 140),
            love.math.random(20, 120),
            Colors.BLUE,
            4, 10, 3
        )
    end
end

function Menu:exit()
    Particles.clear()
end

function Menu:update(dt)
    timer = timer + dt
    titleBounce = math.sin(timer * 2) * 1
    Particles.update(dt)

    if love.math.random() < dt * 0.5 then
        Particles.spawn(
            love.math.random(20, 140),
            love.math.random(80, 130),
            Colors.INDIGO,
            3, 8, 2
        )
    end
end

function Menu:draw()
    -- Background
    Colors.set(Colors.BG)
    love.graphics.rectangle("fill", 0, 0, 160, 144)

    -- Decorative dither
    Colors.set(Colors.DARK_PURPLE, 0.15)
    for y = 0, 143, 2 do
        for x = (y % 4 == 0 and 0 or 2), 159, 4 do
            love.graphics.rectangle("fill", x, y, 1, 1)
        end
    end

    Particles.draw()

    if menuPhase == "main" then
        self:drawMainMenu()
    elseif menuPhase == "difficulty" then
        self:drawDifficultySlider()
    end
end

function Menu:drawMainMenu()
    -- Title (scale 2 = ~24px tall per line)
    local titleY = 4 + math.floor(titleBounce)
    UI.drawCenteredShadowText("CONNECT", titleY, Colors.RED, 2)
    UI.drawCenteredShadowText("FOUR", titleY + 16, Colors.YELLOW, 2)

    -- Decorative line
    Colors.set(Colors.BOARD)
    love.graphics.rectangle("fill", 30, 50, 100, 1)

    -- Menu options (scale 1 = ~12px each, spacing 12px)
    local startY = 56
    for i, option in ipairs(mainOptions) do
        UI.drawButton(option, startY + (i - 1) * 12, i == selectedOption, i == hoveredOption)
    end

    -- Mode description
    local descY = startY + #mainOptions * 12 + 4
    if selectedOption == 1 then
        UI.drawCenteredText("2 players local", descY, Colors.DARK_GREY)
    elseif selectedOption == 2 then
        UI.drawCenteredText("Play against AI", descY, Colors.DARK_GREY)
    elseif selectedOption == 3 then
        UI.drawCenteredText("Play online (code)", descY, Colors.DARK_GREY)
    end

    -- Version (bottom-left)
    Colors.set(Colors.TEXT_DIM)
    love.graphics.print("Made by Chixi", 4, 133, 0, 0.75, 0.75)
end

function Menu:drawDifficultySlider()
    -- Header
    UI.drawCenteredShadowText("CPU LEVEL", 10, Colors.BLUE)

    -- Slider track
    local sliderX = 30
    local sliderY = 30
    local sliderW = 100
    local sliderH = 5

    Colors.set(Colors.DARK_GREY)
    love.graphics.rectangle("fill", sliderX, sliderY, sliderW, sliderH)

    -- Filled portion with color gradient
    local fillW = math.floor((aiDifficulty - 1) / 9 * sliderW)
    local r = aiDifficulty / 10
    local g = 1 - aiDifficulty / 10
    love.graphics.setColor(r, g, 0.2, 1)
    love.graphics.rectangle("fill", sliderX, sliderY, fillW, sliderH)

    -- Handle
    Colors.set(Colors.WHITE)
    love.graphics.rectangle("fill", sliderX + fillW - 1, sliderY - 2, 3, sliderH + 4)

    -- Notches
    Colors.set(Colors.DARK_GREY, 0.5)
    for i = 1, 10 do
        local nx = sliderX + math.floor((i - 1) / 9 * sliderW)
        love.graphics.rectangle("fill", nx, sliderY + sliderH + 2, 1, 2)
    end

    -- Number (scale 2)
    UI.drawCenteredShadowText(tostring(aiDifficulty), 48, Colors.WHITE, 2)

    -- Difficulty label
    local labels = {
        [1] = "BRAINDEAD",  [2] = "BABY",
        [3] = "EASY",       [4] = "CASUAL",
        [5] = "NORMAL",     [6] = "TOUGH",
        [7] = "HARD",       [8] = "EXPERT",
        [9] = "MASTER",     [10] = "SKYNET",
    }
    local label = labels[aiDifficulty] or "???"
    local labelColor = aiDifficulty <= 3 and Colors.GREEN
        or aiDifficulty <= 6 and Colors.YELLOW
        or aiDifficulty <= 8 and Colors.ORANGE
        or Colors.RED
    UI.drawCenteredText(label, 72, labelColor)

    -- Separator
    Colors.set(Colors.BOARD)
    love.graphics.rectangle("fill", 40, 88, 80, 1)

    -- Interactive Instruction line (slightly shifted left)
    local arrowY = 96
    local totalW = 75 
    local startX = math.floor((160 - totalW) / 2) - 5 -- Adjusted offset
    
    local lx = startX
    local rx = startX + 15
    local ex = startX + 50 

    Colors.set(hoveredLArrow and Colors.WHITE or Colors.TEXT_DIM)
    love.graphics.print("<", lx, arrowY, 0, 1.2, 1.2)
    
    Colors.set(hoveredRArrow and Colors.WHITE or Colors.TEXT_DIM)
    love.graphics.print(">", rx, arrowY, 0, 1.2, 1.2)

    if hoveredEnter then
        Colors.set(Colors.WHITE)
        love.graphics.rectangle("fill", ex - 6, arrowY + 3, 3, 3)
    end
    Colors.set(hoveredEnter and Colors.WHITE or Colors.TEXT_DIM)
    love.graphics.print("ENTER", ex, arrowY + 2)

    -- Back button (clickable)
    UI.drawButton("BACK", 118, false, hoveredBack)
end

function Menu:keypressed(key)
    if menuPhase == "main" then
        if key == "up" or key == "w" then
            selectedOption = selectedOption - 1
            if selectedOption < 1 then selectedOption = #mainOptions end
            AudioManager.play("menuSelect")
        elseif key == "down" or key == "s" then
            selectedOption = selectedOption + 1
            if selectedOption > #mainOptions then selectedOption = 1 end
            AudioManager.play("menuSelect")
        elseif key == "return" or key == "space" then
            AudioManager.play("menuConfirm")
            if selectedOption == 1 then
                _G.stateMachine:switch("game", {mode = "human"})
            elseif selectedOption == 2 then
                menuPhase = "difficulty"
            elseif selectedOption == 3 then
                _G.stateMachine:switch("lobby")
            elseif selectedOption == 4 then
                love.event.quit()
            end
        end
    elseif menuPhase == "difficulty" then
        if key == "left" or key == "a" then
            aiDifficulty = math.max(1, aiDifficulty - 1)
            AudioManager.play("tick")
        elseif key == "right" or key == "d" then
            aiDifficulty = math.min(10, aiDifficulty + 1)
            AudioManager.play("tick")
        elseif key == "return" or key == "space" then
            AudioManager.play("menuConfirm")
            _G.stateMachine:switch("game", {mode = "cpu", difficulty = aiDifficulty})
        elseif key == "escape" then
            AudioManager.play("menuBack")
            menuPhase = "main"
        end
    end
end

function Menu:mousemoved(x, y)
    if menuPhase == "main" then
        hoveredOption = 0
        local startY = 56
        for i, option in ipairs(mainOptions) do
            if UI.isMouseOverButton(option, startY + (i - 1) * 12, x, y) then
                hoveredOption = i
                if selectedOption ~= i then
                    selectedOption = i
                    AudioManager.play("menuSelect")
                end
                break
            end
        end
    elseif menuPhase == "difficulty" then
        if isDraggingSlider then
            local sliderX, sliderW = 30, 100
            local val = (x - sliderX) / sliderW
            local newDifficulty = math.floor(val * 9 + 1.5)
            newDifficulty = math.max(1, math.min(10, newDifficulty))
            if newDifficulty ~= aiDifficulty then
                aiDifficulty = newDifficulty
                AudioManager.play("tick")
            end
        end
        
        -- Check hover for adjusted line
        local totalW = 75
        local startX = math.floor((160 - totalW) / 2) - 5
        local arrowY = 96
        
        hoveredLArrow = x >= startX - 2 and x <= startX + 10 and y >= arrowY and y <= arrowY + 12
        hoveredRArrow = x >= startX + 13 and x <= startX + 25 and y >= arrowY and y <= arrowY + 12
        hoveredEnter  = x >= startX + 44 and x <= startX + 80 and y >= arrowY and y <= arrowY + 12
        
        hoveredBack = UI.isMouseOverButton("BACK", 118, x, y)
    end
end

function Menu:mousepressed(x, y, button)
    if button ~= 1 then return end

    if menuPhase == "main" then
        local startY = 56
        for i, option in ipairs(mainOptions) do
            if UI.isMouseOverButton(option, startY + (i - 1) * 12, x, y) then
                selectedOption = i
                AudioManager.play("menuConfirm")
                if i == 1 then
                    _G.stateMachine:switch("game", {mode = "human"})
                elseif i == 2 then
                    menuPhase = "difficulty"
                elseif i == 3 then
                    _G.stateMachine:switch("lobby")
                elseif i == 4 then
                    love.event.quit()
                end
                return
            end
        end
    elseif menuPhase == "difficulty" then
        -- Click on Arrows or Enter
        if hoveredLArrow then
            aiDifficulty = math.max(1, aiDifficulty - 1)
            AudioManager.play("tick")
            return
        elseif hoveredRArrow then
            aiDifficulty = math.min(10, aiDifficulty + 1)
            AudioManager.play("tick")
            return
        elseif hoveredEnter then
            AudioManager.play("menuConfirm")
            _G.stateMachine:switch("game", {mode = "cpu", difficulty = aiDifficulty})
            return
        end

        -- Slider interaction
        local sliderX, sliderY, sliderW, sliderH = 30, 30, 100, 5
        if x >= sliderX - 5 and x <= sliderX + sliderW + 5 and y >= sliderY - 5 and y <= sliderY + sliderH + 10 then
            isDraggingSlider = true
            self:mousemoved(x, y)
            return
        end

        -- Back button
        if UI.isMouseOverButton("BACK", 118, x, y) then
            AudioManager.play("menuBack")
            menuPhase = "main"
            hoveredBack = false
            return
        end
    end
end

function Menu:mousereleased(x, y, button)
    if button == 1 then
        isDraggingSlider = false
    end
end

return Menu
