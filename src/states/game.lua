-- Game State
-- Main gameplay: 2 players or 1 player vs AI

local Board = require("src.board")
local Colors = require("src.colors")
local Renderer = require("src.renderer")
local UI = require("src.ui")
local Tween = require("src.tween")
local Particles = require("src.particles")
local Screenshake = require("src.screenshake")
local AudioManager = require("src.audio_manager")
local AI = require("src.ai")

local Game = {}

-- Game state variables
local board
local currentPlayer
local hoverCol
local timer

-- Mode
local gameMode = "human"  -- "human" or "cpu"
local aiPlayer = nil      -- AI instance
local aiThinking = false
local aiThinkTimer = 0
local AI_THINK_DELAY = 0.5  -- seconds before AI plays (feels more natural)
local lastGameMode = nil
local lastDifficulty = nil

-- Animation state
local dropping = false
local dropAnim = nil
local dropCol = 0
local dropRow = 0
local dropPlayer = 0

-- Win state
local winCells = nil
local gameOver = false
local isDraw = false
local winTimer = 0

function Game:enter(params)
    params = params or {}

    -- Store mode for rematch
    gameMode = params.mode or lastGameMode or "human"
    local difficulty = params.difficulty or lastDifficulty or 5
    lastGameMode = gameMode
    lastDifficulty = difficulty

    -- Initialize AI if CPU mode
    if gameMode == "cpu" then
        aiPlayer = AI:new(difficulty)
    else
        aiPlayer = nil
    end

    board = Board:new()
    currentPlayer = 1
    hoverCol = 4
    timer = 0
    dropping = false
    dropAnim = nil
    winCells = nil
    gameOver = false
    isDraw = false
    winTimer = 0
    aiThinking = false
    aiThinkTimer = 0
    Particles.clear()
end

function Game:exit()
    Particles.clear()
end

--- Check if it's the AI's turn
local function isAITurn()
    return gameMode == "cpu" and currentPlayer == 2 and not gameOver and not dropping
end

function Game:update(dt)
    timer = timer + dt
    Particles.update(dt)
    Screenshake.update(dt)

    -- AI thinking
    if isAITurn() and not aiThinking then
        aiThinking = true
        aiThinkTimer = 0
    end

    if aiThinking then
        aiThinkTimer = aiThinkTimer + dt
        -- Animate hover during "thinking"
        if aiThinkTimer < AI_THINK_DELAY then
            -- Quick hover scan animation
            local scanCol = math.floor(timer * 8) % Board.COLS + 1
            hoverCol = scanCol
        else
            -- AI makes its move
            local col = aiPlayer:chooseColumn(board, 2)
            if col then
                hoverCol = col
                self:doDrop()
            end
            aiThinking = false
        end
    end

    -- Update drop animation
    if dropping and dropAnim then
        local done = dropAnim:update(dt)
        if done then
            dropping = false
            -- Place the piece on the board
            board.grid[dropCol][dropRow] = dropPlayer
            AudioManager.play("land")

            -- Check for win
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
                currentPlayer = currentPlayer == 1 and 2 or 1
            end

            dropAnim = nil
        end
    end

    -- Update win timer
    if gameOver then
        winTimer = winTimer + dt
        if winTimer > 3.0 then
            local result = {
                winner = isDraw and 0 or dropPlayer,
                isDraw = isDraw,
                mode = gameMode,
                difficulty = lastDifficulty,
            }
            _G.stateMachine:switch("game_over", result)
        end

        if winCells and love.math.random() < dt * 3 then
            local idx = love.math.random(1, #winCells)
            local cell = winCells[idx]
            local cx = Renderer.BOARD_OX + (cell.col - 1) * Renderer.CELL + Renderer.CELL / 2
            local cy = Renderer.BOARD_OY + (cell.row - 1) * Renderer.CELL + Renderer.CELL / 2
            local color = dropPlayer == 1 and Colors.PLAYER1 or Colors.PLAYER2
            Particles.spawn(cx, cy, color, 3, 20, 0.6)
        end
    end
end

function Game:draw()
    local shakeX, shakeY = Screenshake.getOffset()

    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)

    -- Background
    Renderer.drawBackground()

    -- Header: mode + turn
    if not gameOver then
        -- Mode label
        if gameMode == "cpu" then
            Colors.set(Colors.DARK_GREY)
            love.graphics.print("CPU:" .. lastDifficulty, 2, 2)
        end
        UI.drawTurnIndicator(currentPlayer, Renderer.BOARD_OX, Renderer.BOARD_OY)

        -- AI thinking indicator
        if aiThinking then
            local dots = string.rep(".", math.floor(timer * 3) % 4)
            Colors.set(Colors.YELLOW)
            love.graphics.print("THINKING" .. dots, Renderer.BOARD_OX, 15)
        end
    else
        if isDraw then
            UI.drawCenteredShadowText("DRAW!", 4, Colors.LIGHT_GREY)
        else
            local color = dropPlayer == 1 and Colors.PLAYER1 or Colors.PLAYER2
            local name
            if gameMode == "cpu" then
                name = dropPlayer == 1 and "YOU WIN!" or "CPU WINS!"
            else
                name = dropPlayer == 1 and "P1 WINS!" or "P2 WINS!"
            end
            UI.drawCenteredShadowText(name, 4, color)
        end
    end

    -- Draw board
    Renderer.drawBoardFrame()
    Renderer.drawEmptyCells()

    -- Draw placed pieces
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

    -- Draw dropping piece animation
    if dropping and dropAnim then
        local pixelY = dropAnim:getValue()
        Renderer.drawPieceAtPixelY(dropCol, pixelY, dropPlayer)
    end

    -- Draw hover preview (not during AI turn unless thinking animation)
    local showHover = not dropping and not gameOver and hoverCol >= 1 and hoverCol <= Board.COLS
    if showHover and (gameMode == "human" or (gameMode == "cpu" and (currentPlayer == 1 or aiThinking))) then
        if board:canDrop(hoverCol) then
            Renderer.drawHover(hoverCol, currentPlayer)
        end
    end

    -- Win highlight
    if winCells then
        Renderer.drawWinHighlight(winCells, nil, nil, winTimer)
    end

    -- Column arrows (only for human player)
    if not gameOver and not dropping and not isAITurn() then
        Renderer.drawColumnArrows(hoverCol)
    end

    -- Particles
    Particles.draw()

    love.graphics.pop()
end

--- Drop a piece in the current hover column
function Game:doDrop()
    if dropping or gameOver then return end
    if not board:canDrop(hoverCol) then return end

    local targetRow = nil
    for row = Board.ROWS, 1, -1 do
        if board:getCell(hoverCol, row) == 0 then
            targetRow = row
            break
        end
    end
    if not targetRow then return end

    dropping = true
    dropCol = hoverCol
    dropRow = targetRow
    dropPlayer = currentPlayer

    AudioManager.play("drop")

    local startY = Renderer.BOARD_OY - Renderer.CELL + Renderer.CELL / 2
    local endY = Renderer.BOARD_OY + (targetRow - 1) * Renderer.CELL + Renderer.CELL / 2
    dropAnim = Tween:new(startY, endY, 0.3 + targetRow * 0.04, "outBounce")

    local cx = Renderer.BOARD_OX + (hoverCol - 1) * Renderer.CELL + Renderer.CELL / 2
    Particles.spawn(cx, startY, currentPlayer == 1 and Colors.PLAYER1 or Colors.PLAYER2, 4, 15, 0.4)
end

function Game:keypressed(key)
    if gameOver then
        if key == "return" or key == "space" then
            local result = {
                winner = isDraw and 0 or dropPlayer,
                isDraw = isDraw,
                mode = gameMode,
                difficulty = lastDifficulty,
            }
            _G.stateMachine:switch("game_over", result)
        end
        return
    end

    -- Block input during AI turn
    if isAITurn() then return end

    if key == "left" or key == "a" then
        hoverCol = math.max(1, hoverCol - 1)
        AudioManager.play("move")
    elseif key == "right" or key == "d" then
        hoverCol = math.min(Board.COLS, hoverCol + 1)
        AudioManager.play("move")
    elseif key == "down" or key == "s" or key == "return" or key == "space" then
        self:doDrop()
    elseif key == "escape" then
        _G.stateMachine:switch("menu")
    end
end

function Game:mousepressed(x, y, button)
    if button ~= 1 then return end
    
    if gameOver then
        local result = {
            winner = isDraw and 0 or dropPlayer,
            isDraw = isDraw,
            mode = gameMode,
            difficulty = lastDifficulty,
        }
        _G.stateMachine:switch("game_over", result)
        return
    end

    if not isAITurn() and not dropping then
        -- Check if mouse is over any column
        local boardX = x - Renderer.BOARD_OX
        if boardX >= 0 and boardX < Board.COLS * Renderer.CELL then
            hoverCol = math.floor(boardX / Renderer.CELL) + 1
            self:doDrop()
        end
    end
end

function Game:mousemoved(x, y, dx, dy)
    if gameOver or dropping or isAITurn() then return end
    local boardX = x - Renderer.BOARD_OX
    if boardX >= 0 and boardX < Board.COLS * Renderer.CELL then
        hoverCol = math.floor(boardX / Renderer.CELL) + 1
    end
end

return Game
