-- [NET] Lobby State
-- Create a game, get a code, or join by entering a code
-- Handles matchmaking via Supabase REST

local Colors = require("src.colors")
local UI = require("src.ui")
local Particles = require("src.particles")
local AudioManager = require("src.audio_manager")
local network = require("src.network")
local Board = require("src.board")

local Lobby = {}

-- Phases: "main", "creating", "waiting", "joining", "connecting", "error"
local phase
local selectedOption
local hoveredOption = 0
local hoveredJoin = false
local hoveredBack = false
local mainOptions = {"CREATE GAME", "JOIN GAME", "BACK"}

-- Game data
local gameId
local gameCode
local playerId
local playerNumber -- 1 or 2

-- Join input
local joinCode
local maxCodeLen = 6

-- Polling
local pollTimer
local POLL_INTERVAL = 1.0

-- Error display
local errorMessage
local errorTimer

-- Timer
local timer
local heartbeatTimer

function Lobby:enter()
    phase = "main"
    selectedOption = 1
    hoveredOption = 0
    hoveredJoin = false
    hoveredBack = false
    gameId = nil
    gameCode = ""
    playerId = network.generatePlayerId()
    playerNumber = nil
    joinCode = ""
    pollTimer = 0
    errorMessage = nil
    errorTimer = 0
    timer = 0
    heartbeatTimer = 0
    Particles.clear()

    -- Init network
    network.init()
end

function Lobby:exit()
    -- Clean up orphaned game if we were hosting and waiting
    if gameId and phase == "waiting" then
        network.request("DELETE", "/rest/v1/games?id=eq." .. gameId, nil, function() end)
    end
    Particles.clear()
end

function Lobby:update(dt)
    timer = timer + dt
    Particles.update(dt)
    network.poll()

    -- Error timeout
    if errorMessage then
        errorTimer = errorTimer + dt
        if errorTimer > 3 then
            errorMessage = nil
            if phase == "error" then
                phase = "main"
            end
        end
    end

    -- Poll for player 2 joining (when we are host waiting)
    if phase == "waiting" and gameId then
        pollTimer = pollTimer + dt
        if pollTimer >= POLL_INTERVAL then
            pollTimer = 0
            self:pollForOpponent()
        end

        heartbeatTimer = heartbeatTimer + dt
        if heartbeatTimer >= 5.0 then -- 5 seconds heartbeat
            heartbeatTimer = 0
            local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            network.request("PATCH", "/rest/v1/games?id=eq." .. gameId, {
                player1_heartbeat = timestamp,
                updated_at = timestamp
            }, function() end)
        end
    end
end

--- Create a new game on Supabase
function Lobby:createGame()
    phase = "creating"
    local code = network.generateGameCode()

    local body = {
        code = code,
        player1_id = playerId,
        status = "waiting",
        board_state = {},
    }
    -- Build default board
    for col = 1, Board.COLS do
        body.board_state[col] = {}
        for row = 1, Board.ROWS do
            body.board_state[col][row] = 0
        end
    end

    network.request("POST", "/rest/v1/games", body, function(status, data)
        if status >= 200 and status < 300 and data then
            local game = data
            if type(data) == "table" and data[1] then
                game = data[1]
            end
            gameId = game.id
            gameCode = game.code
            playerNumber = 1
            phase = "waiting"
            pollTimer = 0
            AudioManager.play("menuConfirm")
            print("[NET] Game created: " .. gameCode)
        else
            self:showError("CREATION FAILED")
            phase = "main"
        end
    end)
end

--- Poll Supabase to check if player 2 has joined
function Lobby:pollForOpponent()
    if not gameId then return end
    network.request("GET", "/rest/v1/games?id=eq." .. gameId .. "&select=*", nil, function(status, data)
        if status >= 200 and status < 300 and data and data[1] then
            local game = data[1]
            if game.player2_id and game.player2_id ~= "" then
                -- Player 2 joined!
                AudioManager.play("win")
                print("[NET] Opponent joined!")
                self:startOnlineGame(game)
            end
        end
    end)
end

--- Attempt to join a game by code
function Lobby:joinGame()
    if #joinCode ~= maxCodeLen then
        self:showError("CODE: 6 CHARS")
        return
    end

    phase = "connecting"
    local upperCode = joinCode:upper()

    -- First, find the game
    network.request("GET", "/rest/v1/games?code=eq." .. upperCode .. "&select=*", nil, function(status, data)
        if status < 200 or status >= 300 then
            self:showError("NETWORK ERROR")
            phase = "joining"
            return
        end

        if not data or #data == 0 then
            self:showError("CODE INVALIDE")
            phase = "joining"
            return
        end

        local game = data[1]
        if game.status ~= "waiting" then
            self:showError("PARTIE PLEINE")
            phase = "joining"
            return
        end

        if game.player2_id and game.player2_id ~= "" then
            self:showError("PARTIE PLEINE")
            phase = "joining"
            return
        end

        -- Join the game
        local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        local patchPath = "/rest/v1/games?id=eq." .. game.id

        network.request("PATCH", patchPath, {
            player2_id = playerId,
            status = "playing",
            player2_heartbeat = timestamp,
            updated_at = timestamp
        }, function(patchStatus, patchData)
            if patchStatus >= 200 and patchStatus < 300 then
                gameId = game.id
                gameCode = game.code
                playerNumber = 2
                AudioManager.play("win")
                print("[NET] Joined game: " .. gameCode)

                -- Re-fetch to get full state
                network.request("GET", "/rest/v1/games?id=eq." .. game.id .. "&select=*", nil, function(_, freshData)
                    if freshData and freshData[1] then
                        self:startOnlineGame(freshData[1])
                    else
                        self:startOnlineGame(game)
                    end
                end)
            else
                self:showError("JOIN FAILED")
                phase = "joining"
            end
        end)
    end)
end

--- Transition to online game state
function Lobby:startOnlineGame(gameData)
    _G.stateMachine:switch("online_game", {
        gameId       = gameData.id,
        gameCode     = gameData.code,
        playerId     = playerId,
        playerNumber = playerNumber,
        gameData     = gameData,
    })
end

function Lobby:showError(msg)
    errorMessage = msg
    errorTimer = 0
    AudioManager.play("menuBack")
end

----------------------------------------------------------------
-- DRAW
----------------------------------------------------------------
function Lobby:draw()
    -- Background
    Colors.set(Colors.BG)
    love.graphics.rectangle("fill", 0, 0, 160, 144)

    -- Dither pattern
    Colors.set(Colors.DARK_PURPLE, 0.12)
    for y = 0, 143, 3 do
        for x = (y % 6 == 0 and 0 or 1), 159, 3 do
            love.graphics.rectangle("fill", x, y, 1, 1)
        end
    end

    Particles.draw()

    -- Title
    UI.drawCenteredShadowText("ONLINE", 4, Colors.BLUE, 2)

    if phase == "main" then
        self:drawMain()
    elseif phase == "creating" then
        self:drawSpinner("CREATING...")
    elseif phase == "waiting" then
        self:drawWaiting()
    elseif phase == "joining" then
        self:drawJoinInput()
    elseif phase == "connecting" then
        self:drawSpinner("CONNECTING...")
    end

    -- Error overlay
    if errorMessage then
        local alpha = math.max(0, 1 - errorTimer / 3)
        love.graphics.setColor(Colors.RED[1], Colors.RED[2], Colors.RED[3], alpha)
        local font = love.graphics.getFont()
        local w = font:getWidth(errorMessage)
        love.graphics.print(errorMessage, math.floor((160 - w) / 2), 130)
    end
end

function Lobby:drawMain()
    -- Separator
    Colors.set(Colors.BOARD)
    love.graphics.rectangle("fill", 30, 32, 100, 1)

    local startY = 40
    for i, option in ipairs(mainOptions) do
        UI.drawButton(option, startY + (i - 1) * 14, i == selectedOption, i == hoveredOption)
    end

    -- Description
    local descY = startY + #mainOptions * 14 + 8
    if selectedOption == 1 then
        UI.drawCenteredText("Host a new game", descY, Colors.DARK_GREY)
    elseif selectedOption == 2 then
        UI.drawCenteredText("Join with a code", descY, Colors.DARK_GREY)
    end
end

function Lobby:drawSpinner(text)
    local dots = string.rep(".", math.floor(timer * 3) % 4)
    UI.drawCenteredText(text .. dots, 60, Colors.YELLOW)
end

function Lobby:drawWaiting()
    -- Show game code prominently
    UI.drawCenteredText("YOUR CODE:", 30, Colors.TEXT_DIM)
    local bounce = math.floor(math.sin(timer * 6) * 2)
    UI.drawCenteredShadowText(gameCode, 42 + bounce, Colors.GREEN, 2)

    -- Separator
    Colors.set(Colors.BOARD)
    love.graphics.rectangle("fill", 30, 75, 100, 1)

    -- Waiting animation
    local dots = string.rep(".", math.floor(timer * 2) % 4)
    UI.drawCenteredText("WAITING FOR P2" .. dots, 85, Colors.YELLOW)

    -- Instructions
    UI.drawCenteredText("Share this code", 105, Colors.DARK_GREY)
    UI.drawButton("CANCEL", 125, false, hoveredBack)
end

function Lobby:drawJoinInput()
    UI.drawCenteredText("ENTER CODE:", 34, Colors.TEXT_DIM)

    -- Code input box
    local boxW = 60
    local boxX = math.floor((160 - boxW) / 2)
    local boxY = 52

    -- Background
    Colors.set(Colors.BLACK, 0.5)
    love.graphics.rectangle("fill", boxX - 2, boxY - 2, boxW + 4, 14)

    -- Border
    local borderAlpha = (math.sin(timer * 4) + 1) / 2 * 0.5 + 0.5
    Colors.set(Colors.BOARD, borderAlpha)
    love.graphics.rectangle("line", boxX - 2, boxY - 2, boxW + 4, 14)

    -- Code text
    Colors.set(Colors.WHITE)
    local display = joinCode:upper()
    -- Add cursor
    if math.floor(timer * 3) % 2 == 0 and #display < maxCodeLen then
        display = display .. "_"
    end
    local font = love.graphics.getFont()
    local textW = font:getWidth(display)
    love.graphics.print(display, math.floor((160 - textW) / 2), boxY)

    -- Char count
    Colors.set(#joinCode == maxCodeLen and Colors.GREEN or Colors.DARK_GREY)
    love.graphics.print(#joinCode .. "/" .. maxCodeLen, boxX + boxW - 14, boxY + 16)

    -- Clickable buttons
    UI.drawButton("JOIN GAME", 95, false, hoveredJoin)
    UI.drawButton("BACK", 115, false, hoveredBack)
end

----------------------------------------------------------------
-- INPUT
----------------------------------------------------------------
function Lobby:keypressed(key)
    if phase == "main" then
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
                self:createGame()
            elseif selectedOption == 2 then
                phase = "joining"
                joinCode = ""
            elseif selectedOption == 3 then
                _G.stateMachine:switch("menu")
            end
        elseif key == "escape" then
            AudioManager.play("menuBack")
            _G.stateMachine:switch("menu")
        end

    elseif phase == "joining" then
        if key == "escape" then
            AudioManager.play("menuBack")
            phase = "main"
        elseif key == "return" then
            self:joinGame()
        elseif key == "backspace" then
            if #joinCode > 0 then
                joinCode = joinCode:sub(1, -2)
                AudioManager.play("tick")
            end
        end

    elseif phase == "waiting" then
        if key == "escape" then
            AudioManager.play("menuBack")
            phase = "main"
            gameId = nil
        end
    end
end

function Lobby:textinput(text)
    if phase == "joining" then
        -- Only accept alphanumeric
        text = text:upper()
        if text:match("^[A-Z0-9]$") and #joinCode < maxCodeLen then
            joinCode = joinCode .. text
            AudioManager.play("tick")
        end
    end
end

function Lobby:mousemoved(x, y)
    hoveredOption = 0
    hoveredJoin = false
    hoveredBack = false

    if phase == "main" then
        local startY = 40
        for i, option in ipairs(mainOptions) do
            if UI.isMouseOverButton(option, startY + (i - 1) * 14, x, y) then
                hoveredOption = i
                if selectedOption ~= i then
                    selectedOption = i
                    AudioManager.play("menuSelect")
                end
                break
            end
        end
    elseif phase == "joining" then
        hoveredJoin = UI.isMouseOverButton("JOIN GAME", 95, x, y)
        hoveredBack = UI.isMouseOverButton("BACK", 115, x, y)
    elseif phase == "waiting" then
        hoveredBack = UI.isMouseOverButton("CANCEL", 125, x, y)
    end
end

function Lobby:mousepressed(x, y, button)
    if button ~= 1 then return end

    if phase == "main" then
        local startY = 40
        for i, option in ipairs(mainOptions) do
            if UI.isMouseOverButton(option, startY + (i - 1) * 14, x, y) then
                selectedOption = i
                AudioManager.play("menuConfirm")
                if i == 1 then
                    self:createGame()
                elseif i == 2 then
                    phase = "joining"
                    joinCode = ""
                elseif i == 3 then
                    _G.stateMachine:switch("menu")
                end
                return
            end
        end
    elseif phase == "joining" then
        if UI.isMouseOverButton("JOIN GAME", 95, x, y) then
            self:joinGame()
        elseif UI.isMouseOverButton("BACK", 115, x, y) then
            AudioManager.play("menuBack")
            phase = "main"
        end
    elseif phase == "waiting" then
        if UI.isMouseOverButton("CANCEL", 125, x, y) then
            AudioManager.play("menuBack")
            phase = "main"
            gameId = nil
        end
    end
end

return Lobby
