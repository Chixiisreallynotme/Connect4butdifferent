--- State Machine
-- A lightweight, reusable state machine for LÖVE 2D games.
-- Each state is a table with optional methods:
--   enter(params), exit(), update(dt), draw(),
--   keypressed(key), keyreleased(key),
--   mousepressed(x, y, button), mousereleased(x, y, button),
--   resize(w, h), textinput(text)

local StateMachine = {}
StateMachine.__index = StateMachine

--- Create a new state machine.
function StateMachine:new()
    return setmetatable({
        states = {},    -- registered state tables keyed by name
        current = nil,  -- current state table
        name = nil,     -- current state name
    }, StateMachine)
end

--- Register a state by name.
-- @param name string
-- @param state table  a state object with lifecycle methods
function StateMachine:register(name, state)
    self.states[name] = state
end

--- Switch to a new state.
-- Calls exit() on the current state, then enter(params) on the new one.
-- @param name string
-- @param params table (optional) data passed to enter()
function StateMachine:switch(name, params)
    assert(self.states[name], "State '" .. name .. "' not registered.")
    if self.current and self.current.exit then
        self.current:exit()
    end
    self.current = self.states[name]
    self.name = name
    if self.current.enter then
        self.current:enter(params or {})
    end
end

--- Forward love.update(dt)
function StateMachine:update(dt)
    if self.current and self.current.update then
        self.current:update(dt)
    end
end

--- Forward love.draw()
function StateMachine:draw()
    if self.current and self.current.draw then
        self.current:draw()
    end
end

--- Forward love.keypressed()
function StateMachine:keypressed(key, scancode, isrepeat)
    if self.current and self.current.keypressed then
        self.current:keypressed(key, scancode, isrepeat)
    end
end

--- Forward love.keyreleased()
function StateMachine:keyreleased(key)
    if self.current and self.current.keyreleased then
        self.current:keyreleased(key)
    end
end

--- Forward love.mousepressed()
function StateMachine:mousepressed(x, y, button, istouch)
    if self.current and self.current.mousepressed then
        self.current:mousepressed(x, y, button, istouch)
    end
end

--- Forward love.mousereleased()
function StateMachine:mousereleased(x, y, button)
    if self.current and self.current.mousereleased then
        self.current:mousereleased(x, y, button)
    end
end

--- Forward love.resize()
function StateMachine:resize(w, h)
    if self.current and self.current.resize then
        self.current:resize(w, h)
    end
end

--- Forward love.textinput()
function StateMachine:textinput(text)
    if self.current and self.current.textinput then
        self.current:textinput(text)
    end
end

return StateMachine
