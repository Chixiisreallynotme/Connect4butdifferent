-- State Machine
-- Manages game states (menu, game, game_over) with enter/exit transitions

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine:new()
    return setmetatable({
        states = {},
        current = nil,
        currentName = nil,
    }, StateMachine)
end

function StateMachine:register(name, state)
    self.states[name] = state
end

function StateMachine:switch(name, params)
    assert(self.states[name], "Unknown state: " .. tostring(name))
    if self.current and self.current.exit then
        self.current:exit()
    end
    self.currentName = name
    self.current = self.states[name]
    if self.current and self.current.enter then
        self.current:enter(params)
    end
end

function StateMachine:update(dt)
    if self.current and self.current.update then
        self.current:update(dt)
    end
end

function StateMachine:draw()
    if self.current and self.current.draw then
        self.current:draw()
    end
end

function StateMachine:keypressed(key, scancode, isrepeat)
    if self.current and self.current.keypressed then
        self.current:keypressed(key, scancode, isrepeat)
    end
end

function StateMachine:mousepressed(x, y, button)
    if self.current and self.current.mousepressed then
        self.current:mousepressed(x, y, button)
    end
end

function StateMachine:mousemoved(x, y, dx, dy)
    if self.current and self.current.mousemoved then
        self.current:mousemoved(x, y, dx, dy)
    end
end

function StateMachine:mousereleased(x, y, button)
    if self.current and self.current.mousereleased then
        self.current:mousereleased(x, y, button)
    end
end

-- [NET] Text input forwarding for lobby code entry
function StateMachine:textinput(text)
    if self.current and self.current.textinput then
        self.current:textinput(text)
    end
end

function StateMachine:resize(w, h)
    if self.current and self.current.resize then
        self.current:resize(w, h)
    end
end

return StateMachine
