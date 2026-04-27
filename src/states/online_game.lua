-- [NET] Online Game State
-- Multiplayer gameplay via Supabase REST polling
-- Reuses Board, Renderer, UI, Tween, Particles, Screenshake, AudioManager

local Board = require("src.board")
local Colors = require("src.colors")
local Renderer = require("src.renderer")
local UI = require("src.ui")
local Tween = require("src.tween")
local Particles = require("src.particles")
local Screenshake = require("src.screenshake")
local AudioManager = require("src.audio_manager")
local network = require("src.network")
local json = require("src.json")

local OnlineGame = {}

-- Session data (from lobby)
local gameId
local gameCode
local playerId
local playerNumber  -- 1 or 2 (my player slot)

-- Game state
local board
local currentTurn   -- 1 or 2 (whose turn it is)
local hoverCol
local timer
local moveCount     -- tracks remote move_count for change detection

-- Animation
local dropping
local dropAnim
local dropCol
local dropRow
local dropPlayer

-- Win / end state
local winCells
local gameOver
local isDraw
local winTimer
local isForfeit

-- Polling
local pollTimer
local POLL_INTERVAL = 0.5
local HEARTBEAT_INTERVAL = 5.0
local heartbeatTimer
local FORFEIT_TIMEOUT = 15.0 -- seconds without heartbeat = forfeit

-- Status
local statusMessage
local lastPollData

--- Is it my turn?
local function isMyTurn()
    return currentTurn == playerNumber and not gameOver and not dropping
end

--- Is it opponent's turn?
local function isOpponentTurn()
    return currentTurn ~= playerNumber and not gameOver and not dropping
end

function OnlineGame:enter(params)
    params = params or {}
    gameId       = params.gameId
    gameCode     = params.gameCode
    playerId     = params.playerId
    playerNumber = params.playerNumber

    -- Initialize board from game data
    board = Board:new()
    if params.gameData and params.gameData.board_state then
        local bs = params.gameData.board_state
        if type(bs) == "table" then
            for col = 1, math.min(Board.COLS, #bs) do
                for row = 1, math.min(Board.ROWS, #(bs[col] or {})) do
                    board.grid[col][row] = bs[col][row] or 0
                end
            end
        end
    end

    currentTurn = (params.gameData and params.gameData.current_turn) or 1
    moveCount   = (params.gameData and params.gameData.move_count) or 0
    hoverCol    = 4
    timer       = 0
    dropping    = false
    dropAnim    = nil
    winCells    = nil
    gameOver    = false
    isDraw      = false
    isForfeit   = false
    winTimer    = 0
    pollTimer   = 0
    heartbeatTimer = 0
    statusMessage  = nil
    lastPollData   = nil
    Particles.clear()

    -- Send initial heartbeat
    self:sendHeartbeat()
    print("[NET] Online game started as P" .. playerNumber)
end

function OnlineGame:exit()
    Particles.clear()
end

function OnlineGame:update(dt)
    timer = timer + dt
    Particles.update(dt)
    Screenshake.update(dt)
    network.poll()

    -- Drop animation
    if dropping and dropAnim then
        local done = dropAnim:update(dt)
        if done then
            dropping = false
            board.grid[dropCol][dropRow] = dropPlayer
            AudioManager.play("land")

            -- Check win
            winCells = board:checkWin(dropCol, dropRow)
            if winCells then
                gameOver = true
                winTimer = 0
                Screenshake.trigger(3, 0.4)
                AudioManager.play("win")
                local color = dropPlayer == 1 and Colors.PLAYER1 or Colors.PLAYER2
                Particles.celebrate(winCells, Renderer.BOARD_OX, Renderer.BOARD_OY, Renderer.CELL, color)
            elseif board:isFull() then
                gameOver = true
                isDraw = true
                winTimer = 0
                AudioManager.play("draw")
            else
                currentTurn = currentTurn == 1 and 2 or 1
            end

            dropAnim = nil
        end
    end

    -- Game over transition
    if gameOver then
        winTimer = winTimer + dt
        if winTimer > 3.0 then
            self:goToGameOver()
        end

        -- Win particles
        if winCells and love.math.random() < dt * 3 then
            local idx = love.math.random(1, #winCells)
            local cell = winCells[idx]
            local cx = Renderer.BOARD_OX + (cell.col - 1) * Renderer.CELL + Renderer.CELL / 2
            local cy = Renderer.BOARD_OY + (cell.row - 1) * Renderer.CELL + Renderer.CELL / 2
            local color = dropPlayer == 1 and Colors.PLAYER1 or Colors.PLAYER2
            Particles.spawn(cx, cy, color, 3, 20, 0.6)
        end
        return
    end

    -- Heartbeat (every 5s)
    heartbeatTimer = heartbeatTimer + dt
    if heartbeatTimer >= HEARTBEAT_INTERVAL then
        heartbeatTimer = 0
        self:sendHeartbeat()
    end

    -- Poll opponent's state when it's their turn
    if isOpponentTurn() and not dropping then
        pollTimer = pollTimer + dt
        if pollTimer >= POLL_INTERVAL then
            pollTimer = 0
            self:pollGameState()
        end
    end
end

----------------------------------------------------------------
-- NETWORK ACTIONS
----------------------------------------------------------------

--- Send heartbeat to Supabase
function OnlineGame:sendHeartbeat()
    if not gameId then return end
    local field = playerNumber == 1 and "player1_heartbeat" or "player2_heartbeat"
    local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local body = {}
    body[field] = timestamp
    body["updated_at"] = timestamp

    network.request("PATCH", "/rest/v1/games?id=eq." .. gameId, body, function(status, data)
        -- Silent — heartbeat failures are not critical individually
    end)
end

--- Poll game state from Supabase
function OnlineGame:pollGameState()
    if not gameId then return end
    network.request("GET", "/rest/v1/games?id=eq." .. gameId .. "&select=*", nil, function(status, data)
        if status < 200 or status >= 300 or not data or not data[1] then return end

        local game = data[1]
        lastPollData = game

        -- Check for forfeit (opponent heartbeat too old)
        self:checkForfeit(game)

        -- Check if opponent played
        if game.move_count and game.move_count > moveCount then
            -- Opponent made a move!
            moveCount = game.move_count

            -- Sync the board from server
            if game.board_state and type(game.board_state) == "table" then
                for col = 1, math.min(Board.COLS, #game.board_state) do
                    for row = 1, math.min(Board.ROWS, #(game.board_state[col] or {})) do
                        board.grid[col][row] = game.board_state[col][row] or 0
                    end
                end
            end

            -- Animate the last move
            if game.last_move_col and game.last_move_row then
                local col = game.last_move_col
                local row = game.last_move_row
                local opponent = playerNumber == 1 and 2 or 1

                -- Temporarily clear the cell for animation
                board.grid[col][row] = 0

                dropping = true
                dropCol = col
                dropRow = row
                dropPlayer = opponent

                AudioManager.play("drop")

                local startY = Renderer.BOARD_OY - Renderer.CELL + Renderer.CELL / 2
                local endY = Renderer.BOARD_OY + (row - 1) * Renderer.CELL + Renderer.CELL / 2
                dropAnim = Tween:new(startY, endY, 0.3 + row * 0.04, "outBounce")

                local cx = Renderer.BOARD_OX + (col - 1) * Renderer.CELL + Renderer.CELL / 2
                Particles.spawn(cx, startY, opponent == 1 and Colors.PLAYER1 or Colors.PLAYER2, 4, 15, 0.4)
            else
                -- No animation data, just switch turns
                currentTurn = game.current_turn or (currentTurn == 1 and 2 or 1)
            end
        end

        -- Check for game-ending states from server
        if game.status == "abandoned" and not gameOver then
            gameOver = true
            isForfeit = true
            winTimer = 0
            dropPlayer = playerNumber -- I win
            AudioManager.play("win")
        elseif game.winner ~= nil and game.status == "finished" and not gameOver then
            gameOver = true
            winTimer = 0
            if game.winner == 0 then
                isDraw = true
                AudioManager.play("draw")
            else
                dropPlayer = game.winner
                AudioManager.play("win")
            end
        end
    end)
end

--- Check if opponent has disconnected (forfeit)
function OnlineGame:checkForfeit(game)
    if gameOver then return end
    
    -- Grace period: do not check for forfeit during the first 10 seconds 
    -- to allow both players' heartbeats to stabilize after a rematch or join
    if timer < 10.0 then return end

    local opponentField = playerNumber == 1 and "player2_heartbeat" or "player1_heartbeat"
    local myField = playerNumber == 1 and "player1_heartbeat" or "player2_heartbeat"
    local hb = game[opponentField]
    local myHb = game[myField]

    if hb and myHb then
        -- Parse ISO timestamps (the fractional seconds and timezone are ignored by match)
        local y, mo, d, h, mi, s = hb:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
        local myY, myMo, myD, myH, myMi, myS = myHb:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
        
        if y and myY then
            local hbTime = os.time({
                year = tonumber(y), month = tonumber(mo), day = tonumber(d),
                hour = tonumber(h), min = tonumber(mi), sec = tonumber(s),
            })
            local myHbTime = os.time({
                year = tonumber(myY), month = tonumber(myMo), day = tonumber(myD),
                hour = tonumber(myH), min = tonumber(myMi), sec = tonumber(myS),
            })
            
            local elapsed = myHbTime - hbTime

            if elapsed > FORFEIT_TIMEOUT then
                -- Opponent disconnected!
                gameOver = true
                isForfeit = true
                winTimer = 0
                dropPlayer = playerNumber -- I win
                AudioManager.play("win")

                -- Update server
                network.request("PATCH", "/rest/v1/games?id=eq." .. gameId, {
                    status = "finished",
                    winner = playerNumber,
                }, function() end)

                print("[NET] Opponent forfeited (heartbeat timeout)")
            end
        end
    end
end

--- Play a move locally and sync to Supabase
function OnlineGame:playMove()
    if dropping or gameOver then return end
    if not isMyTurn() then return end
    if not board:canDrop(hoverCol) then return end

    -- Find target row
    local targetRow = nil
    for row = Board.ROWS, 1, -1 do
        if board:getCell(hoverCol, row) == 0 then
            targetRow = row
            break
        end
    end
    if not targetRow then return end

    -- Start drop animation
    dropping = true
    dropCol = hoverCol
    dropRow = targetRow
    dropPlayer = playerNumber
    AudioManager.play("drop")

    local startY = Renderer.BOARD_OY - Renderer.CELL + Renderer.CELL / 2
    local endY = Renderer.BOARD_OY + (targetRow - 1) * Renderer.CELL + Renderer.CELL / 2
    dropAnim = Tween:new(startY, endY, 0.3 + targetRow * 0.04, "outBounce")

    local cx = Renderer.BOARD_OX + (hoverCol - 1) * Renderer.CELL + Renderer.CELL / 2
    Particles.spawn(cx, startY, playerNumber == 1 and Colors.PLAYER1 or Colors.PLAYER2, 4, 15, 0.4)

    -- Sync to Supabase (optimistic: animate immediately)
    local newBoard = {}
    for col = 1, Board.COLS do
        newBoard[col] = {}
        for row = 1, Board.ROWS do
            newBoard[col][row] = board.grid[col][row]
        end
    end
    newBoard[hoverCol][targetRow] = playerNumber

    -- Temporarily apply locally to check win condition
    board.grid[hoverCol][targetRow] = playerNumber
    local isWin = board:checkWin(hoverCol, targetRow) ~= nil
    local isFull = board:isFull()
    board.grid[hoverCol][targetRow] = 0 -- revert for animation

    local nextTurn = playerNumber == 1 and 2 or 1
    local newMoveCount = moveCount + 1
    local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

    local payload = {
        board_state   = newBoard,
        current_turn  = nextTurn,
        last_move_col = hoverCol,
        last_move_row = targetRow,
        move_count    = newMoveCount,
        updated_at    = timestamp,
    }

    if isWin then
        payload.status = "finished"
        payload.winner = playerNumber
    elseif isFull then
        payload.status = "finished"
        payload.winner = 0 -- Draw
    end

    network.request("PATCH", "/rest/v1/games?id=eq." .. gameId, payload, function(status, data)
        if status >= 200 and status < 300 then
            moveCount = newMoveCount
        else
            print("[NET] Move sync failed: " .. tostring(status))
        end
    end)
end

--- Transition to game over screen
function OnlineGame:goToGameOver()
    _G.stateMachine:switch("online_game_over", {
        winner       = isDraw and 0 or dropPlayer,
        isDraw       = isDraw,
        isForfeit    = isForfeit,
        gameId       = gameId,
        gameCode     = gameCode,
        playerId     = playerId,
        playerNumber = playerNumber,
    })
end

----------------------------------------------------------------
-- DRAW
----------------------------------------------------------------
function OnlineGame:draw()
    local shakeX, shakeY = Screenshake.getOffset()
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)

    -- Background
    Renderer.drawBackground()

    -- Header
    if not gameOver then
        -- Online indicator (pulsating)
        local alpha = (math.sin(love.timer.getTime() * 5) + 1) / 2 * 0.5 + 0.5
        Colors.set(Colors.GREEN, alpha)
        love.graphics.rectangle("fill", 2, 130, 3, 3)
        Colors.set(Colors.GREEN, alpha * 0.3)
        love.graphics.rectangle("fill", 1, 129, 5, 5) -- slight glow
        
        Colors.set(Colors.DARK_GREY)
        love.graphics.print("ROOM: " .. gameCode, 7, 128)

        UI.drawTurnIndicator(currentTurn, Renderer.BOARD_OX, Renderer.BOARD_OY)

        -- Waiting indicator during opponent's turn
        if isOpponentTurn() and not dropping then
            local dots = string.rep(".", math.floor(timer * 2) % 4)
            UI.drawCenteredText("WAITING" .. dots, 15, Colors.YELLOW)
        end

        -- My turn indicator
        if isMyTurn() and not dropping then
            local bounce = math.floor(math.sin(timer * 8) * 1.5)
            UI.drawCenteredShadowText("YOUR TURN!", 15 + bounce, Colors.GREEN)
        end
    else
        if isForfeit then
            UI.drawCenteredShadowText("FORFAIT!", 4, Colors.ORANGE)
        elseif isDraw then
            UI.drawCenteredShadowText("DRAW!", 4, Colors.LIGHT_GREY)
        else
            local color = dropPlayer == 1 and Colors.PLAYER1 or Colors.PLAYER2
            local name = dropPlayer == playerNumber and "YOU WIN!" or "YOU LOSE!"
            UI.drawCenteredShadowText(name, 4, color)
        end
    end

    -- Board
    Renderer.drawBoardFrame()
    Renderer.drawEmptyCells()

    -- Placed pieces
    for col = 1, Board.COLS do
        for row = 1, Board.ROWS do
            local cell = board:getCell(col, row)
            if cell ~= 0 then
                if not (dropping and col == dropCol and row == dropRow) then
                    Renderer.drawPiece(col, row, cell)
                end
            end
        end
    end

    -- Drop animation
    if dropping and dropAnim then
        local pixelY = dropAnim:getValue()
        Renderer.drawPieceAtPixelY(dropCol, pixelY, dropPlayer)
    end

    -- Hover preview (only on my turn)
    if isMyTurn() and not dropping and hoverCol >= 1 and hoverCol <= Board.COLS then
        if board:canDrop(hoverCol) then
            Renderer.drawHover(hoverCol, playerNumber)
        end
    end

    -- Win highlight
    if winCells then
        Renderer.drawWinHighlight(winCells, nil, nil, winTimer)
    end

    -- Column arrows (my turn only)
    if isMyTurn() and not dropping then
        Renderer.drawColumnArrows(hoverCol)
    end

    -- Particles
    Particles.draw()

    love.graphics.pop()
end

----------------------------------------------------------------
-- INPUT
----------------------------------------------------------------
function OnlineGame:keypressed(key)
    if gameOver then
        if key == "return" or key == "space" then
            self:goToGameOver()
        end
        return
    end

    if not isMyTurn() then
        if key == "escape" then
            -- Forfeit
            network.request("PATCH", "/rest/v1/games?id=eq." .. gameId, {
                status = "abandoned",
                winner = playerNumber == 1 and 2 or 1,
            }, function() end)
            _G.stateMachine:switch("menu")
        end
        return
    end

    if key == "left" or key == "a" then
        hoverCol = math.max(1, hoverCol - 1)
        AudioManager.play("move")
    elseif key == "right" or key == "d" then
        hoverCol = math.min(Board.COLS, hoverCol + 1)
        AudioManager.play("move")
    elseif key == "down" or key == "s" or key == "return" or key == "space" then
        self:playMove()
    elseif key == "escape" then
        -- Forfeit
        network.request("PATCH", "/rest/v1/games?id=eq." .. gameId, {
            status = "abandoned",
            winner = playerNumber == 1 and 2 or 1,
        }, function() end)
        _G.stateMachine:switch("menu")
    end
end

function OnlineGame:mousepressed(x, y, button)
    if button ~= 1 then return end

    if gameOver then
        self:goToGameOver()
        return
    end

    if isMyTurn() and not dropping then
        local boardX = x - Renderer.BOARD_OX
        if boardX >= 0 and boardX < Board.COLS * Renderer.CELL then
            hoverCol = math.floor(boardX / Renderer.CELL) + 1
            self:playMove()
        end
    end
end

function OnlineGame:mousemoved(x, y, dx, dy)
    if gameOver or dropping or not isMyTurn() then return end
    local boardX = x - Renderer.BOARD_OX
    if boardX >= 0 and boardX < Board.COLS * Renderer.CELL then
        hoverCol = math.floor(boardX / Renderer.CELL) + 1
    end
end

return OnlineGame
