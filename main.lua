-- Connect 4 — Pixel Art Edition
-- Main entry point

local PixelCanvas = require("src.pixel_canvas")
local StateMachine = require("src.state_machine")
local AudioManager = require("src.audio_manager")
local shaders = require("src.shaders")

-- Game systems
local pixelCanvas

function love.load()
    -- Pixel art rendering setup
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.mouse.setCursor(love.mouse.getSystemCursor("hand"))

    -- Initialize shaders
    shaders.init()

    -- Initialize audio
    AudioManager.init()
    AudioManager.setVolume(0.8)

    -- Initialize pixel canvas pipeline
    pixelCanvas = PixelCanvas:new()

    -- Initialize state machine (global for state access)
    _G.stateMachine = StateMachine:new()
    _G.stateMachine:register("menu", require("src.states.menu"))
    _G.stateMachine:register("game", require("src.states.game"))
    _G.stateMachine:register("game_over", require("src.states.game_over"))
    -- [NET] Online multiplayer states
    _G.stateMachine:register("lobby", require("src.states.lobby"))
    _G.stateMachine:register("online_game", require("src.states.online_game"))
    _G.stateMachine:register("online_game_over", require("src.states.online_game_over"))

    -- Start at menu
    _G.stateMachine:switch("menu")
end

function love.update(dt)
    -- Cap delta time to prevent physics explosions
    dt = math.min(dt, 1/30)
    _G.stateMachine:update(dt)
end

function love.draw()
    -- Begin low-res pixel rendering
    pixelCanvas:beginDraw()

    -- Draw current state at internal resolution
    _G.stateMachine:draw()

    -- End and upscale to window
    pixelCanvas:endDraw()
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen())
        pixelCanvas:calculateScale()
    end
    _G.stateMachine:keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button)
    -- Convert screen coordinates to pixel coordinates
    local px, py = pixelCanvas:screenToPixel(x, y)
    _G.stateMachine:mousepressed(px, py, button)
end

function love.mousemoved(x, y, dx, dy)
    -- Convert screen coordinates to pixel coordinates
    local px, py = pixelCanvas:screenToPixel(x, y)
    _G.stateMachine:mousemoved(px, py, dx, dy)
end

function love.mousereleased(x, y, button)
    -- Convert screen coordinates to pixel coordinates
    local px, py = pixelCanvas:screenToPixel(x, y)
    _G.stateMachine:mousereleased(px, py, button)
end

-- [NET] Text input forwarding for lobby code entry
function love.textinput(text)
    _G.stateMachine:textinput(text)
end

-- [NET] Clean shutdown of network thread
function love.quit()
    local ok, network = pcall(require, "src.network")
    if ok and network and network.isReady and network.isReady() then
        network.shutdown()
    end
end

function love.resize(w, h)
    pixelCanvas:resize(w, h)
    _G.stateMachine:resize(w, h)
end

--- Crash handler: log error to file, cleanup network, then show default error screen
function love.errorhandler(msg)
    local trace = debug.traceback(tostring(msg), 2)
    print("[CRASH] " .. trace)
    -- Save crash log
    pcall(function()
        love.filesystem.write("crash.log",
            os.date() .. "\n" .. trace)
    end)
    -- Cleanup network thread
    pcall(function()
        local ok, net = pcall(require, "src.network")
        if ok and net and net.isReady and net.isReady() then
            net.shutdown()
        end
    end)
    -- Delegate to LÖVE's default error handler
    return love.errhand and love.errhand(msg)
end
