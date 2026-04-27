-- Connect 4 Board Logic
-- 7 columns x 6 rows grid, win detection, drop mechanics

local Board = {}
Board.__index = Board

Board.COLS = 7
Board.ROWS = 6
Board.CONNECT = 4

function Board:new()
    local b = setmetatable({}, Board)
    b.grid = {}
    b:reset()
    return b
end

function Board:reset()
    self.grid = {}
    for col = 1, Board.COLS do
        self.grid[col] = {}
        for row = 1, Board.ROWS do
            self.grid[col][row] = 0
        end
    end
end

--- Get cell value: 0 = empty, 1 = player 1, 2 = player 2
function Board:getCell(col, row)
    if col < 1 or col > Board.COLS or row < 1 or row > Board.ROWS then
        return -1
    end
    return self.grid[col][row]
end

--- Check if a piece can be dropped in this column
function Board:canDrop(col)
    if col < 1 or col > Board.COLS then return false end
    return self.grid[col][1] == 0  -- top row empty
end

--- Drop a piece in a column, returns the row it landed on (gravity)
function Board:drop(col, player)
    if not self:canDrop(col) then return nil end
    -- Find the lowest empty row
    for row = Board.ROWS, 1, -1 do
        if self.grid[col][row] == 0 then
            self.grid[col][row] = player
            return row
        end
    end
    return nil
end

--- Check if the board is completely full (draw condition)
function Board:isFull()
    for col = 1, Board.COLS do
        if self.grid[col][1] == 0 then
            return false
        end
    end
    return true
end

--- Direction vectors: horizontal, vertical, diagonal-down-right, diagonal-down-left
--- (module-level constant to avoid allocation in hot path)
local DIRECTIONS = {
    {dc = 1, dr = 0},  -- horizontal
    {dc = 0, dr = 1},  -- vertical
    {dc = 1, dr = 1},  -- diagonal \
    {dc = 1, dr = -1}, -- diagonal /
}

--- Check for a win starting from the last placed piece at (col, row)
--- @param returnBoolOnly boolean|nil If true, returns a boolean instead of table to save memory
function Board:checkWin(col, row, returnBoolOnly)
    local player = self.grid[col][row]
    if player == 0 then return nil end

    for _, dir in ipairs(DIRECTIONS) do
        if returnBoolOnly then
            local count = 1
            local c, r = col + dir.dc, row + dir.dr
            while self:getCell(c, r) == player do
                count = count + 1
                c = c + dir.dc
                r = r + dir.dr
            end
            c, r = col - dir.dc, row - dir.dr
            while self:getCell(c, r) == player do
                count = count + 1
                c = c - dir.dc
                r = r - dir.dr
            end
            if count >= Board.CONNECT then return true end
        else
            local cells = {{col = col, row = row}}
            local c, r = col + dir.dc, row + dir.dr
            while self:getCell(c, r) == player do
                cells[#cells + 1] = {col = c, row = r}
                c = c + dir.dc
                r = r + dir.dr
            end
            c, r = col - dir.dc, row - dir.dr
            while self:getCell(c, r) == player do
                cells[#cells + 1] = {col = c, row = r}
                c = c - dir.dc
                r = r - dir.dr
            end
            if #cells >= Board.CONNECT then return cells end
        end
    end

    return nil
end

--- Get the number of pieces in a column (for hover height calculation)
function Board:getColumnHeight(col)
    for row = 1, Board.ROWS do
        if self.grid[col][row] ~= 0 then
            return Board.ROWS - row + 1
        end
    end
    return 0
end

return Board
