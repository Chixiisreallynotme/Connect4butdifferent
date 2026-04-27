-- PICO-8 Inspired Color Palette
-- All colors in LÖVE's 0-1 range

local Colors = {}

-- PICO-8 palette (16 colors)
Colors.BLACK       = {0/255, 0/255, 0/255}
Colors.DARK_BLUE   = {29/255, 43/255, 83/255}
Colors.DARK_PURPLE = {126/255, 37/255, 83/255}
Colors.DARK_GREEN  = {0/255, 135/255, 81/255}
Colors.BROWN       = {171/255, 82/255, 54/255}
Colors.DARK_GREY   = {95/255, 87/255, 79/255}
Colors.LIGHT_GREY  = {194/255, 195/255, 199/255}
Colors.WHITE       = {255/255, 241/255, 232/255}
Colors.RED         = {255/255, 0/255, 77/255}
Colors.ORANGE      = {255/255, 163/255, 0/255}
Colors.YELLOW      = {255/255, 236/255, 39/255}
Colors.GREEN       = {0/255, 228/255, 54/255}
Colors.BLUE        = {41/255, 173/255, 255/255}
Colors.INDIGO      = {131/255, 118/255, 156/255}
Colors.PINK        = {255/255, 119/255, 168/255}
Colors.PEACH       = {255/255, 204/255, 170/255}

-- Game-specific color assignments
Colors.BG          = Colors.DARK_BLUE
Colors.BOARD       = Colors.INDIGO
Colors.BOARD_DARK  = Colors.DARK_PURPLE
Colors.CELL_EMPTY  = Colors.DARK_BLUE
Colors.PLAYER1     = Colors.RED
Colors.PLAYER2     = Colors.YELLOW
Colors.HOVER_P1    = Colors.PINK
Colors.HOVER_P2    = Colors.PEACH
Colors.TEXT         = Colors.WHITE
Colors.TEXT_DIM     = Colors.LIGHT_GREY
Colors.HIGHLIGHT   = Colors.GREEN
Colors.TITLE       = Colors.BLUE

--- Set love color from a palette color
function Colors.set(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
end

return Colors
