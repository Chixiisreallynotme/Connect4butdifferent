function love.conf(t)
    t.identity = "connect4"
    t.version = "11.5"
    t.console = false

    t.window.title = "Connect 4"
    t.window.width = 800
    t.window.height = 720
    t.window.resizable = false
    t.window.vsync = 1
    t.window.msaa = 0
    t.window.icon = "logo.png"

    -- Disable unused modules for performance
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false
    t.modules.touch = false
end
