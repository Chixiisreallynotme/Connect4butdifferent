-- Renderer Module
-- Draws the Connect 4 board, pieces, hover preview, and win highlights
-- All coordinates are in internal pixel resolution (160x144)

local Colors = require("src.colors")
local Board = require("src.board")

local Renderer = {}

local CELL = 8  -- 8x8 pixel cells
local PIECE_RADIUS = 3  -- 6x6 piece in 8x8 cell
local BOARD_W = Board.COLS * CELL  -- 56
local BOARD_H = Board.ROWS * CELL  -- 48

-- Board position (centered horizontally, slightly below center vertically)
Renderer.BOARD_OX = math.floor((160 - BOARD_W) / 2)  -- 52
Renderer.BOARD_OY = 50
Renderer.CELL = CELL

--- Draw the dithered background
function Renderer.drawBackground()
    -- Dark blue background with subtle dither pattern
    Colors.set(Colors.BG)
    love.graphics.rectangle("fill", 0, 0, 160, 144)

    -- Subtle dot pattern
    Colors.set(Colors.DARK_BLUE, 0.3)
    for y = 0, 143, 4 do
        for x = 0, 159, 4 do
            love.graphics.rectangle("fill", x, y, 1, 1)
        end
    end
end

--- Draw the board frame
function Renderer.drawBoardFrame(ox, oy)
    ox = ox or Renderer.BOARD_OX
    oy = oy or Renderer.BOARD_OY

    -- Board shadow
    Colors.set(Colors.BLACK, 0.3)
    love.graphics.rectangle("fill", ox + 1, oy + 1, BOARD_W, BOARD_H)

    -- Board body
    Colors.set(Colors.BOARD)
    love.graphics.rectangle("fill", ox, oy, BOARD_W, BOARD_H)

    -- Board border (1px)
    Colors.set(Colors.BOARD_DARK)
    love.graphics.rectangle("line", ox, oy, BOARD_W, BOARD_H)
end

--- Draw empty cell holes
function Renderer.drawEmptyCells(ox, oy)
    ox = ox or Renderer.BOARD_OX
    oy = oy or Renderer.BOARD_OY

    for col = 1, Board.COLS do
        for row = 1, Board.ROWS do
            local cx = ox + (col - 1) * CELL + CELL / 2
            local cy = oy + (row - 1) * CELL + CELL / 2
            -- Dark circle for empty slot
            Colors.set(Colors.CELL_EMPTY)
            love.graphics.rectangle("fill",
                cx - PIECE_RADIUS, cy - PIECE_RADIUS,
                PIECE_RADIUS * 2, PIECE_RADIUS * 2)
        end
    end
end

--- Draw a single piece at grid position
function Renderer.drawPiece(col, row, player, ox, oy, alpha)
    ox = ox or Renderer.BOARD_OX
    oy = oy or Renderer.BOARD_OY
    alpha = alpha or 1

    local cx = ox + (col - 1) * CELL + CELL / 2
    local cy = oy + (row - 1) * CELL + CELL / 2

    local color = player == 1 and Colors.PLAYER1 or Colors.PLAYER2
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.rectangle("fill",
        cx - PIECE_RADIUS, cy - PIECE_RADIUS,
        PIECE_RADIUS * 2, PIECE_RADIUS * 2)

    -- Inner highlight (1px lighter spot)
    love.graphics.setColor(1, 1, 1, 0.25 * alpha)
    love.graphics.rectangle("fill",
        cx - PIECE_RADIUS + 1, cy - PIECE_RADIUS + 1,
        2, 2)
end

--- Draw a piece at pixel Y position (for drop animation)
function Renderer.drawPieceAtPixelY(col, pixelY, player, ox)
    ox = ox or Renderer.BOARD_OX

    local cx = ox + (col - 1) * CELL + CELL / 2

    local color = player == 1 and Colors.PLAYER1 or Colors.PLAYER2
    Colors.set(color)
    love.graphics.rectangle("fill",
        cx - PIECE_RADIUS, pixelY - PIECE_RADIUS,
        PIECE_RADIUS * 2, PIECE_RADIUS * 2)

    -- Inner highlight
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.rectangle("fill",
        cx - PIECE_RADIUS + 1, pixelY - PIECE_RADIUS + 1,
        2, 2)
end

--- Draw all placed pieces on the board
function Renderer.drawAllPieces(board, ox, oy)
    ox = ox or Renderer.BOARD_OX
    oy = oy or Renderer.BOARD_OY

    for col = 1, Board.COLS do
        for row = 1, Board.ROWS do
            local cell = board:getCell(col, row)
            if cell ~= 0 then
                Renderer.drawPiece(col, row, cell, ox, oy)
            end
        end
    end
end

--- Draw hover preview above the board
function Renderer.drawHover(col, player, ox, oy)
    if col < 1 or col > Board.COLS then return end
    ox = ox or Renderer.BOARD_OX
    oy = oy or Renderer.BOARD_OY

    local cx = ox + (col - 1) * CELL + CELL / 2
    local cy = oy - CELL + CELL / 2

    local color = player == 1 and Colors.HOVER_P1 or Colors.HOVER_P2
    local pulse = math.sin(love.timer.getTime() * 6) * 0.3 + 0.7
    love.graphics.setColor(color[1], color[2], color[3], pulse)
    love.graphics.rectangle("fill",
        cx - PIECE_RADIUS, cy - PIECE_RADIUS,
        PIECE_RADIUS * 2, PIECE_RADIUS * 2)

    -- Column indicator line
    love.graphics.setColor(color[1], color[2], color[3], 0.2)
    love.graphics.rectangle("fill", ox + (col - 1) * CELL, oy, CELL, BOARD_H)
end

--- Draw win highlight (sparkling cells)
function Renderer.drawWinHighlight(cells, ox, oy, timer)
    ox = ox or Renderer.BOARD_OX
    oy = oy or Renderer.BOARD_OY

    local shaders = require("src.shaders")
    shaders.applySparkle(timer)
    
    for _, cell in ipairs(cells) do
        local cx = ox + (cell.col - 1) * CELL + CELL / 2
        local cy = oy + (cell.row - 1) * CELL + CELL / 2

        -- Sparkly border/box around winning pieces
        Colors.set(Colors.WHITE)
        love.graphics.rectangle("fill",
            cx - PIECE_RADIUS - 1, cy - PIECE_RADIUS - 1,
            PIECE_RADIUS * 2 + 2, PIECE_RADIUS * 2 + 2)
    end
    shaders.reset()
end

--- Draw column selector arrows (bottom)
function Renderer.drawColumnArrows(selectedCol, ox, oy)
    ox = ox or Renderer.BOARD_OX
    oy = oy or Renderer.BOARD_OY

    local arrowY = oy + BOARD_H + 3
    for col = 1, Board.COLS do
        local cx = ox + (col - 1) * CELL + CELL / 2
        if col == selectedCol then
            Colors.set(Colors.WHITE)
        else
            Colors.set(Colors.DARK_GREY)
        end
        -- Small triangle/arrow pointing up
        love.graphics.rectangle("fill", cx - 1, arrowY, 3, 2)
        love.graphics.rectangle("fill", cx, arrowY - 1, 1, 1)
    end
end

return Renderer
