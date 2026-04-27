--- Tilemap Loader & Renderer
-- Lightweight tilemap system for LÖVE 2D.
-- Supports loading from a 2D Lua table and rendering with SpriteBatch.
-- For Tiled (.tmx) maps, consider using the `sti` library.

local Tilemap = {}
Tilemap.__index = Tilemap

--- Create a new tilemap.
-- @param tilesheetPath string  path to the tilesheet image
-- @param tileWidth number      width of each tile in pixels
-- @param tileHeight number     height of each tile in pixels
-- @param mapData table         2D array of tile IDs (1-based, 0 = empty)
function Tilemap:new(tilesheetPath, tileWidth, tileHeight, mapData)
    local sheet = love.graphics.newImage(tilesheetPath)
    sheet:setFilter("nearest", "nearest")

    local sheetW, sheetH = sheet:getDimensions()
    local cols = math.floor(sheetW / tileWidth)
    local rows = math.floor(sheetH / tileHeight)
    local totalTiles = cols * rows

    -- Generate quads for each tile ID
    local quads = {}
    for i = 1, totalTiles do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        quads[i] = love.graphics.newQuad(
            col * tileWidth, row * tileHeight,
            tileWidth, tileHeight,
            sheetW, sheetH
        )
    end

    local map = setmetatable({
        sheet = sheet,
        quads = quads,
        tileW = tileWidth,
        tileH = tileHeight,
        data = mapData,
        mapRows = #mapData,
        mapCols = #mapData[1],
        batch = nil,
    }, Tilemap)

    map:rebuild()
    return map
end

--- Rebuild the SpriteBatch from map data.
-- Call this after modifying self.data.
function Tilemap:rebuild()
    local batch = love.graphics.newSpriteBatch(self.sheet, self.mapRows * self.mapCols, "static")
    batch:clear()
    for row = 1, self.mapRows do
        for col = 1, self.mapCols do
            local id = self.data[row][col]
            if id and id > 0 and self.quads[id] then
                batch:add(
                    self.quads[id],
                    (col - 1) * self.tileW,
                    (row - 1) * self.tileH
                )
            end
        end
    end
    self.batch = batch
end

--- Draw the tilemap.
-- @param offsetX number (optional)
-- @param offsetY number (optional)
function Tilemap:draw(offsetX, offsetY)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.batch, offsetX or 0, offsetY or 0)
end

--- Get the tile ID at a given grid position.
-- @param col number (1-based)
-- @param row number (1-based)
-- @return number tile ID or 0
function Tilemap:getTile(col, row)
    if row >= 1 and row <= self.mapRows and col >= 1 and col <= self.mapCols then
        return self.data[row][col] or 0
    end
    return 0
end

--- Set a tile at a given grid position and rebuild the batch.
-- @param col number (1-based)
-- @param row number (1-based)
-- @param id number tile ID
function Tilemap:setTile(col, row, id)
    if row >= 1 and row <= self.mapRows and col >= 1 and col <= self.mapCols then
        self.data[row][col] = id
        self:rebuild()
    end
end

--- Convert world pixel coordinates to grid coordinates.
-- @param px number  pixel X
-- @param py number  pixel Y
-- @return number, number  col, row (1-based)
function Tilemap:worldToGrid(px, py)
    return math.floor(px / self.tileW) + 1, math.floor(py / self.tileH) + 1
end

--- Convert grid coordinates to world pixel coordinates (top-left of tile).
-- @param col number (1-based)
-- @param row number (1-based)
-- @return number, number  px, py
function Tilemap:gridToWorld(col, row)
    return (col - 1) * self.tileW, (row - 1) * self.tileH
end

--- Get map dimensions in pixels.
-- @return number, number  width, height
function Tilemap:getPixelDimensions()
    return self.mapCols * self.tileW, self.mapRows * self.tileH
end

return Tilemap
