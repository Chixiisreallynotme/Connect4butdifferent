-- AI Module
-- Minimax with alpha-beta pruning for Connect 4
-- Difficulty 1-10 maps to search depth and randomness

local Board = require("src.board")

local AI = {}
AI.__index = AI

--- Create a new AI with given difficulty (1-10)
function AI:new(difficulty)
    local ai = setmetatable({}, AI)
    ai.difficulty = math.max(1, math.min(10, difficulty or 5))
    -- Depth increases with difficulty: 1→1, 5→4, 10→8
    ai.maxDepth = math.floor(ai.difficulty * 0.8 + 0.5)
    if ai.maxDepth < 1 then ai.maxDepth = 1 end
    -- Randomness decreases with difficulty (chance of random move)
    ai.randomChance = math.max(0, 0.5 - ai.difficulty * 0.05)
    return ai
end

--- Evaluate the board position heuristically
local function evaluateWindow(c1, c2, c3, c4, player)
    local score = 0
    local opponent = player == 1 and 2 or 1
    local playerCount = 0
    local opponentCount = 0
    local emptyCount = 0

    local cells = {c1, c2, c3, c4}
    for i = 1, 4 do
        local cell = cells[i]
        if cell == player then playerCount = playerCount + 1
        elseif cell == opponent then opponentCount = opponentCount + 1
        else emptyCount = emptyCount + 1
        end
    end

    if playerCount == 4 then
        score = 100
    elseif playerCount == 3 and emptyCount == 1 then
        score = 5
    elseif playerCount == 2 and emptyCount == 2 then
        score = 2
    end

    if opponentCount == 3 and emptyCount == 1 then
        score = score - 4
    end

    return score
end

--- Score the entire board for a player
local function scorePosition(board, player)
    local score = 0

    -- Prefer center column
    for row = 1, Board.ROWS do
        if board:getCell(4, row) == player then
            score = score + 3
        end
    end

    -- Horizontal windows
    for row = 1, Board.ROWS do
        for col = 1, Board.COLS - 3 do
            score = score + evaluateWindow(
                board:getCell(col, row),
                board:getCell(col+1, row),
                board:getCell(col+2, row),
                board:getCell(col+3, row),
                player
            )
        end
    end

    -- Vertical windows
    for col = 1, Board.COLS do
        for row = 1, Board.ROWS - 3 do
            score = score + evaluateWindow(
                board:getCell(col, row),
                board:getCell(col, row+1),
                board:getCell(col, row+2),
                board:getCell(col, row+3),
                player
            )
        end
    end

    -- Diagonal \ windows
    for col = 1, Board.COLS - 3 do
        for row = 1, Board.ROWS - 3 do
            score = score + evaluateWindow(
                board:getCell(col, row),
                board:getCell(col+1, row+1),
                board:getCell(col+2, row+2),
                board:getCell(col+3, row+3),
                player
            )
        end
    end

    -- Diagonal / windows
    for col = 1, Board.COLS - 3 do
        for row = 4, Board.ROWS do
            score = score + evaluateWindow(
                board:getCell(col, row),
                board:getCell(col+1, row-1),
                board:getCell(col+2, row-2),
                board:getCell(col+3, row-3),
                player
            )
        end
    end

    return score
end

--- Check if the game has a terminal state
--- @param board Board the game board
--- @param lastCol number|nil column of last placed piece
--- @param lastRow number|nil row of last placed piece
local function isTerminal(board, lastCol, lastRow)
    if lastCol and lastRow then
        local p = board:getCell(lastCol, lastRow)
        if p ~= 0 and board:checkWin(lastCol, lastRow, true) then
            return true, p
        end
    end
    if board:isFull() then
        return true, 0  -- draw
    end
    return false, nil
end

--- Get valid columns (those that can accept a piece)
local function getValidCols(board)
    local valid = {}
    for col = 1, Board.COLS do
        if board:canDrop(col) then
            valid[#valid + 1] = col
        end
    end
    return valid
end

--- Simulate dropping a piece (returns a copy-like operation on the board)
local function simulateDrop(board, col, player)
    for row = Board.ROWS, 1, -1 do
        if board.grid[col][row] == 0 then
            board.grid[col][row] = player
            return row
        end
    end
    return nil
end

--- Undo a drop
local function undoDrop(board, col, row)
    board.grid[col][row] = 0
end

--- Minimax with alpha-beta pruning
local function minimax(board, depth, alpha, beta, maximizingPlayer, aiPlayer, lastCol, lastRow)
    local terminal, termWinner = isTerminal(board, lastCol, lastRow)
    local opponent = aiPlayer == 1 and 2 or 1

    if terminal then
        if termWinner == aiPlayer then return nil, 100000
        elseif termWinner == opponent then return nil, -100000
        else return nil, 0
        end
    end

    if depth == 0 then
        return nil, scorePosition(board, aiPlayer)
    end

    if maximizingPlayer then
        local maxScore = -math.huge
        local bestCol = nil
        local numBest = 0

        for col = 1, Board.COLS do
            if board:canDrop(col) then
                if not bestCol then bestCol = col end
                local row = simulateDrop(board, col, aiPlayer)
                if row then
                    local _, score = minimax(board, depth - 1, alpha, beta, false, aiPlayer, col, row)
                    undoDrop(board, col, row)

                    if score > maxScore then
                        maxScore = score
                        bestCol = col
                        numBest = 1
                    elseif score == maxScore then
                        numBest = numBest + 1
                        if love.math.random() < 1/numBest then
                            bestCol = col
                        end
                    end
                    alpha = math.max(alpha, score)
                    if alpha >= beta then break end
                end
            end
        end
        return bestCol, maxScore
    else
        local minScore = math.huge
        local bestCol = nil
        local numBest = 0

        for col = 1, Board.COLS do
            if board:canDrop(col) then
                if not bestCol then bestCol = col end
                local row = simulateDrop(board, col, opponent)
                if row then
                    local _, score = minimax(board, depth - 1, alpha, beta, true, aiPlayer, col, row)
                    undoDrop(board, col, row)

                    if score < minScore then
                        minScore = score
                        bestCol = col
                        numBest = 1
                    elseif score == minScore then
                        numBest = numBest + 1
                        if love.math.random() < 1/numBest then
                            bestCol = col
                        end
                    end
                    beta = math.min(beta, score)
                    if alpha >= beta then break end
                end
            end
        end
        return bestCol, minScore
    end
end

--- Choose the best column to play
function AI:chooseColumn(board, aiPlayer)
    -- Random chance for lower difficulties
    if love.math.random() < self.randomChance then
        local validCols = getValidCols(board)
        if #validCols > 0 then
            return validCols[love.math.random(1, #validCols)]
        end
    end

    -- First check: can we win immediately?
    for col = 1, Board.COLS do
        if board:canDrop(col) then
            local row = simulateDrop(board, col, aiPlayer)
            if row and board:checkWin(col, row) then
                undoDrop(board, col, row)
                return col
            end
            if row then undoDrop(board, col, row) end
        end
    end

    -- Second check: can opponent win immediately? Block it!
    local opponent = aiPlayer == 1 and 2 or 1
    for col = 1, Board.COLS do
        if board:canDrop(col) then
            local row = simulateDrop(board, col, opponent)
            if row and board:checkWin(col, row) then
                undoDrop(board, col, row)
                return col
            end
            if row then undoDrop(board, col, row) end
        end
    end

    -- Minimax search
    local bestCol, _ = minimax(board, self.maxDepth, -math.huge, math.huge, true, aiPlayer)
    return bestCol
end

return AI
