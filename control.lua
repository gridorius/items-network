require("scripts.lib.main")
local NetworkSystem = require("scripts.network_system")
local TerminalGui = require("scripts.terminal_gui")


script.on_nth_tick(10, function()
    if game then
        local network_system = NetworkSystem:new()
        Gridorius.state:set("network_system", network_system)
        TerminalGui.BindInterfaces()
        script.on_nth_tick(10, nil)
    end
end)


-- end)
