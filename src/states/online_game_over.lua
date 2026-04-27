-- [NET] Online Game Over State
-- Shows result, handles bilateral rematch with 60s timeout
-- FORFEIT text is INTENTIONALLY misspelled — do NOT correct it

local Colors = require("src.colors")
local UI = require("src.ui")
local Particles = require("src.particles")
local AudioManager = require("src.audio_manager")
local network = require("src.network")
local Board = require("src.board")
local json = require("src.json")

local OnlineGameOver = {}

-- Result data
local winner       -- 0=draw, 1=P1, 2=P2
local isDraw
local isForfeit
local gameId
local gameCode
local playerId
local playerNumber

-- UI
local timer
local selectedOption
local hoveredOption = 0
local options = {}

-- Rematch state
local myRematch        -- did I request rematch?
local opponentRematch  -- did opponent request rematch?
local rematchTimer     -- countdown for timeout
local REMATCH_TIMEOUT = 60.0
local pollTimer
local POLL_INTERVAL = 1.0
local heartbeatTimer
local opponentLeft

-- Prevent multiple overlapping requests
local transitioning = false

function OnlineGameOver:enter(params)
    params = params or {}
    winner       = params.winner or 0
    isDraw       = params.isDraw or false
    isForfeit    = params.isForfeit or false
    gameId       = params.gameId
    gameCode     = params.gameCode
    playerId     = params.playerId
    playerNumber = params.playerNumber

    timer          = 0
    selectedOption = 1
    hoveredOption  = 0
    myRematch      = false
    opponentRematch = false
    transitioning   = false
    rematchTimer   = 0
    pollTimer      = 0
    heartbeatTimer = 0
    opponentLeft   = false
    Particles.clear()

    if isForfeit then
        options = {"MENU"}
    else
        options = {"REJOUER", "MENU"}
    end

    if not isDraw and not isForfeit then
        local color = winner == playerNumber and Colors.GREEN or Colors.RED
        for i = 1, 3 do
            Particles.spawn(
                80 + love.math.random(-30, 30),
                50 + love.math.random(-10, 10),
                color, 15, 50, 2
            )
        end
    end
end

function OnlineGameOver:exit()
    Particles.clear()
end

function OnlineGameOver:update(dt)
    timer = timer + dt
    Particles.update(dt)
    network.poll()

    -- Celebration particles
    if not isDraw and not isForfeit and love.math.random() < dt * 2 then
        local color = winner == 1 and Colors.PLAYER1 or Colors.PLAYER2
        Particles.spawn(
            love.math.random(20, 140),
            love.math.random(30, 70),
            color, 4, 15, 1.5
        )
    end

    -- Heartbeat
    heartbeatTimer = heartbeatTimer + dt
    if heartbeatTimer >= 5.0 then
        heartbeatTimer = 0
        local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        local field = playerNumber == 1 and "player1_heartbeat" or "player2_heartbeat"
        network.request("PATCH", "/rest/v1/games?id=eq." .. gameId, {
            [field] = timestamp,
            updated_at = timestamp
        }, function() end)
    end

    -- Polling for opponent status (rematch / abandoned)
    pollTimer = pollTimer + dt
    if pollTimer >= POLL_INTERVAL then
        pollTimer = 0
        self:pollOpponentStatus()
    end

    -- Rematch timeout
    if myRematch then
        rematchTimer = rematchTimer + dt

        -- Timeout
        if rematchTimer >= REMATCH_TIMEOUT then
            AudioManager.play("menuBack")
            self:leaveGame()
            return
        end
    end
end

--- Request rematch on Supabase
function OnlineGameOver:requestRematch()
    myRematch = true
    rematchTimer = 0
    AudioManager.play("menuConfirm")

    local field = playerNumber == 1 and "rematch_p1" or "rematch_p2"
    local body = {}
    body[field] = true

    network.request("PATCH", "/rest/v1/games?id=eq." .. gameId, body, function(status, data)
        if status < 200 or status >= 300 then
            print("[NET] Rematch request failed")
        end
    end)
end

--- Poll Supabase for opponent's status
function OnlineGameOver:pollOpponentStatus()
    if not gameId or transitioning or opponentLeft then return end
    
    network.request("GET", "/rest/v1/games?id=eq." .. gameId .. "&select=*", nil, function(status, data)
        if status < 200 or status >= 300 or not data or not data[1] then return end

        local game = data[1]

        -- If opponent explicitly left
        if game.status == "abandoned" then
            self:handleOpponentLeft()
            return
        end

        -- Check heartbeat timeout
        local hbField = playerNumber == 1 and "player2_heartbeat" or "player1_heartbeat"
        local myHbField = playerNumber == 1 and "player1_heartbeat" or "player2_heartbeat"
        local hb = game[hbField]
        local myHb = game[myHbField]
        
        if hb and myHb then
            local y, mo, d, h, mi, s = hb:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            local myY, myMo, myD, myH, myMi, myS = myHb:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            if y and myY then
                local hbTime = os.time({year=tonumber(y), month=tonumber(mo), day=tonumber(d), hour=tonumber(h), min=tonumber(mi), sec=tonumber(s)})
                local myHbTime = os.time({year=tonumber(myY), month=tonumber(myMo), day=tonumber(myD), hour=tonumber(myH), min=tonumber(myMi), sec=tonumber(myS)})
                if myHbTime - hbTime > 15 then
                    self:handleOpponentLeft()
                    return
                end
            end
        end

        local opponentField = playerNumber == 1 and "rematch_p2" or "rematch_p1"

        if game.status == "playing" then
            -- Host already reset the game! We can join the rematch locally
            transitioning = true
            self:joinRematch()
            return
        end

        if game[opponentField] then
            opponentRematch = true
            -- Both want rematch!
            if myRematch and playerNumber == 1 and not transitioning then
                transitioning = true
                -- Host is responsible for resetting the database
                self:startRematch()
            end
            -- Player 2 will keep polling until status == "playing"
        end
    end)
end

function OnlineGameOver:handleOpponentLeft()
    opponentLeft = true
    myRematch = false
    opponentRematch = false
    options = {"MENU"}
    selectedOption = 1
    network.request("PATCH", "/rest/v1/games?id=eq." .. gameId, {status = "abandoned"}, function() end)
end

function OnlineGameOver:leaveGame()
    if gameId then
        network.request("PATCH", "/rest/v1/games?id=eq." .. gameId, {status = "abandoned"}, function() end)
    end
    _G.stateMachine:switch("menu")
end

--- Join a rematch already reset by the host
function OnlineGameOver:joinRematch()
    AudioManager.play("win")
    
    -- Fetch the fresh game data reset by P1
    network.request("GET", "/rest/v1/games?id=eq." .. gameId .. "&select=*", nil, function(_, freshData)
        local gameData = (freshData and freshData[1]) or nil
        _G.stateMachine:switch("online_game", {
            gameId       = gameId,
            gameCode     = gameCode,
            playerId     = playerId,
            playerNumber = playerNumber,
            gameData     = gameData,
        })
    end)
end

--- Start a rematch on the same game slot
function OnlineGameOver:startRematch()
    AudioManager.play("win")

    -- Reset the game state on Supabase
    -- Ensure freshBoard is explicitly constructed to avoid JSON encoding issues
    local freshBoard = {}
    for col = 1, Board.COLS do
        freshBoard[col] = {0, 0, 0, 0, 0, 0}
    end

    local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    network.request("PATCH", "/rest/v1/games?id=eq." .. gameId, {
        board_state   = freshBoard,
        current_turn  = 1,
        last_move_col = json.null,
        last_move_row = json.null,
        move_count    = 0,
        winner        = json.null,
        status        = "playing",
        rematch_p1    = false,
        rematch_p2    = false,
        player1_heartbeat = timestamp,
        player2_heartbeat = timestamp,
        updated_at    = timestamp,
    }, function(status, data)
        -- Fetch fresh game data
        network.request("GET", "/rest/v1/games?id=eq." .. gameId .. "&select=*", nil, function(_, freshData)
            local gameData = (freshData and freshData[1]) or {
                id = gameId,
                code = gameCode,
                current_turn = 1,
                move_count = 0,
                board_state = freshBoard,
            }
            _G.stateMachine:switch("online_game", {
                gameId       = gameId,
                gameCode     = gameCode,
                playerId     = playerId,
                playerNumber = playerNumber,
                gameData     = gameData,
            })
        end)
    end)
end

----------------------------------------------------------------
-- DRAW
----------------------------------------------------------------

--- Draw pixel art crown (copied from game_over.lua style)
local function drawCrown(cx, topY)
    local bounce = math.floor(math.sin(timer * 4) * 1.5)
    local y = topY + bounce

    Colors.set(Colors.YELLOW)
    love.graphics.rectangle("fill", cx - 12, y + 8, 25, 4)
    love.graphics.rectangle("fill", cx - 12, y + 2, 4, 6)
    love.graphics.rectangle("fill", cx - 11, y, 2, 2)
    love.graphics.rectangle("fill", cx - 6, y + 5, 2, 3)
    love.graphics.rectangle("fill", cx - 2, y + 1, 5, 7)
    love.graphics.rectangle("fill", cx - 1, y - 1, 3, 2)
    love.graphics.rectangle("fill", cx + 5, y + 5, 2, 3)
    love.graphics.rectangle("fill", cx + 9, y + 2, 4, 6)
    love.graphics.rectangle("fill", cx + 10, y, 2, 2)

    Colors.set(Colors.ORANGE)
    love.graphics.rectangle("fill", cx - 12, y + 11, 25, 1)
    love.graphics.rectangle("fill", cx - 8, y + 6, 2, 2)
    love.graphics.rectangle("fill", cx - 4, y + 6, 2, 2)
    love.graphics.rectangle("fill", cx + 3, y + 6, 2, 2)
    love.graphics.rectangle("fill", cx + 7, y + 6, 2, 2)

    Colors.set(Colors.RED)
    love.graphics.rectangle("fill", cx - 8, y + 8, 3, 2)
    Colors.set(Colors.BLUE)
    love.graphics.rectangle("fill", cx - 1, y + 8, 3, 2)
    Colors.set(Colors.GREEN)
    love.graphics.rectangle("fill", cx + 6, y + 8, 3, 2)

    Colors.set(Colors.WHITE)
    love.graphics.rectangle("fill", cx - 8, y + 8, 1, 1)
    love.graphics.rectangle("fill", cx - 1, y + 8, 1, 1)
    love.graphics.rectangle("fill", cx + 6, y + 8, 1, 1)
    love.graphics.rectangle("fill", cx - 11, y, 1, 1)
    love.graphics.rectangle("fill", cx - 1, y - 1, 1, 1)
    love.graphics.rectangle("fill", cx + 10, y, 1, 1)
end

function OnlineGameOver:draw()
    -- Background
    Colors.set(Colors.BG)
    love.graphics.rectangle("fill", 0, 0, 160, 144)

    Colors.set(Colors.DARK_PURPLE, 0.1)
    for y = 0, 143, 3 do
        for x = (y % 6 == 0 and 0 or 1), 159, 3 do
            love.graphics.rectangle("fill", x, y, 1, 1)
        end
    end

    Particles.draw()

    if isForfeit then
        -- Forfeit message — INTENTIONALLY misspelled, DO NOT CORRECT
        local forfeitText = "Le joueur a adonnes, le nul, donc ta gagner, juste parqu'il a abondonnes donc toi aussi t'est nul"

        -- Word wrap at ~24 chars per line for 160px width
        local y = 16
        local words = {}
        for word in forfeitText:gmatch("%S+") do
            words[#words + 1] = word
        end

        local lines = {}
        local currentLine = ""
        for _, word in ipairs(words) do
            local test = currentLine == "" and word or (currentLine .. " " .. word)
            if #test > 22 then
                lines[#lines + 1] = currentLine
                currentLine = word
            else
                currentLine = test
            end
        end
        if currentLine ~= "" then
            lines[#lines + 1] = currentLine
        end

        for i, line in ipairs(lines) do
            UI.drawCenteredText(line, y + (i - 1) * 9, Colors.ORANGE)
        end

    elseif isDraw then
        UI.drawCenteredShadowText("DRAW!", 20, Colors.LIGHT_GREY, 2)
        UI.drawCenteredText("No winner", 48, Colors.TEXT_DIM)
    else
        local iWon = (winner == playerNumber)
        local color = winner == 1 and Colors.PLAYER1 or Colors.PLAYER2

        if iWon then
            drawCrown(80, 4)
            UI.drawCenteredShadowText("YOU WIN!", 16, color, 2)
            UI.drawCenteredText("Well played!", 46, Colors.WHITE)
        else
            UI.drawCenteredShadowText("YOU LOSE!", 20, color, 2)
            UI.drawCenteredText("Try again!", 46, Colors.TEXT_DIM)
        end
    end

    -- Separator
    Colors.set(Colors.BOARD)
    love.graphics.rectangle("fill", 30, 64, 100, 1)

    -- Menu options
    local startY = 74
    for i, option in ipairs(options) do
        UI.drawButton(option, startY + (i - 1) * 14, i == selectedOption, i == hoveredOption)
    end

    -- Rematch indicators (READY checkmarks)
    local arrowY = 74
    local slide = math.floor(math.sin(timer * 6) * 2)

    -- My rematch arrow
    if myRematch then
        local x = 12 + slide
        Colors.set(Colors.GREEN)
        
        -- Draw a polished checkmark
        love.graphics.rectangle("fill", x, arrowY + 2, 1, 1)
        love.graphics.rectangle("fill", x + 1, arrowY + 3, 1, 1)
        love.graphics.rectangle("fill", x + 2, arrowY + 2, 1, 1)
        love.graphics.rectangle("fill", x + 3, arrowY + 1, 1, 1)
        love.graphics.rectangle("fill", x + 4, arrowY, 1, 1)

        -- Label
        Colors.set(Colors.GREEN)
        love.graphics.print("READY", x - 6, arrowY + 6)
    end

    -- Opponent rematch arrow
    if opponentRematch then
        local x = 142 - slide
        Colors.set(Colors.GREEN)
        
        -- Draw a polished checkmark
        love.graphics.rectangle("fill", x, arrowY + 2, 1, 1)
        love.graphics.rectangle("fill", x + 1, arrowY + 3, 1, 1)
        love.graphics.rectangle("fill", x + 2, arrowY + 2, 1, 1)
        love.graphics.rectangle("fill", x + 3, arrowY + 1, 1, 1)
        love.graphics.rectangle("fill", x + 4, arrowY, 1, 1)

        -- Label
        Colors.set(Colors.GREEN)
        love.graphics.print("READY", x - 24, arrowY + 6)
    end

    -- Rematch waiting message or opponent left
    if opponentLeft and not isForfeit then
        local bounce = math.floor(math.sin(timer * 8) * 1.5)
        UI.drawCenteredText("L'autre joueur est parti.", 105 + bounce, Colors.ORANGE)
    elseif myRematch and not opponentRematch then
        local remaining = math.max(0, math.floor(REMATCH_TIMEOUT - rematchTimer))
        local dots = string.rep(".", math.floor(timer * 2) % 4)
        local bounce = math.floor(math.sin(timer * 8) * 1.5)
        UI.drawCenteredText("WAITING" .. dots .. " " .. remaining .. "s", 105 + bounce, Colors.YELLOW)
    end

    -- Game code
    Colors.set(Colors.DARK_GREY)
    love.graphics.print("ROOM: " .. gameCode, 7, 128)
end

----------------------------------------------------------------
-- INPUT
----------------------------------------------------------------
function OnlineGameOver:keypressed(key)
    if myRematch and not opponentRematch and not opponentLeft then
        -- Waiting for opponent, only ESC works
        if key == "escape" then
            AudioManager.play("menuBack")
            self:leaveGame()
        end
        return
    end

    if key == "up" or key == "w" then
        selectedOption = selectedOption - 1
        if selectedOption < 1 then selectedOption = #options end
        AudioManager.play("menuSelect")
    elseif key == "down" or key == "s" then
        selectedOption = selectedOption + 1
        if selectedOption > #options then selectedOption = 1 end
        AudioManager.play("menuSelect")
    elseif key == "return" or key == "space" then
        if options[selectedOption] == "REJOUER" then
            self:requestRematch()
        elseif options[selectedOption] == "MENU" then
            AudioManager.play("menuConfirm")
            self:leaveGame()
        end
    elseif key == "escape" then
        AudioManager.play("menuBack")
        self:leaveGame()
    end
end

function OnlineGameOver:mousemoved(x, y)
    hoveredOption = 0
    if myRematch and not opponentRematch and not opponentLeft then return end

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

function OnlineGameOver:mousepressed(x, y, button)
    if button == 1 and not (myRematch and not opponentRematch and not opponentLeft) then
        local startY = 74
        for i, _ in ipairs(options) do
            if UI.isMouseOverButton(options[i], startY + (i - 1) * 14, x, y) then
                selectedOption = i
                if options[i] == "REJOUER" then
                    self:requestRematch()
                elseif options[i] == "MENU" then
                    AudioManager.play("menuConfirm")
                    self:leaveGame()
                end
                return
            end
        end
    end
end

return OnlineGameOver
