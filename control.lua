require("scripts.lib.main")
local NetworkSystem = require("scripts.network_system")
local TerminalGui = require("scripts.terminal_gui")


Gridorius.Events:OnNthTick(10, function(event, handler_id)
    if game then
        local network_system = NetworkSystem:new()
        Gridorius.state:set("network_system", network_system)
        TerminalGui.BindInterfaces()
        Gridorius.Events:RemoveNthTickEvent(10, handler_id)
    end
end)
