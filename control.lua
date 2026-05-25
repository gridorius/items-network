require("scripts.lib.main")
local NetworkSystem = require("scripts.network_system")
local Constants = require("scripts.constants")
local util = require("__core__/lualib/util")

Gridorius.Events:UseEvents(
    defines.events.on_gui_click,
    defines.events.on_gui_opened,
    defines.events.on_gui_closed,
    defines.events.on_research_finished,
    defines.events.on_player_rotated_entity,
    defines.events.on_runtime_mod_setting_changed,
    defines.events.on_gui_elem_changed,
    defines.events.on_gui_text_changed,
    defines.events.on_string_translated
);

Gridorius.Events:UseEvents(table.unpack(Constants.BUILD_EVENTS))
Gridorius.Events:UseEvents(table.unpack(Constants.MINING_EVENTS))
Gridorius.Events:UseTick(1, 10, 60)

local function request_translations()
    storage.translation = {}
    local localised_strings = {}
    for _, item in pairs(prototypes.item) do
        if item.localised_name and item.localised_name ~= "" then
            table.insert(localised_strings, item.localised_name)
        end
    end
    for _, fluid in pairs(prototypes.fluid) do
        if fluid.hidden == false and fluid.localised_name and fluid.localised_name ~= "" then
            table.insert(localised_strings, fluid.localised_name)
        end
    end
    game.connected_players[1].request_translations(localised_strings)
end

local function on_string_translated(event)
    if event.translated and event.result and event.localised_string and event.localised_string[1] then
        local item_name = util.split(event.localised_string[1], ".")[2]
        if item_name then
            storage.translation[item_name] = event.result
        else
            storage.translation[event.localised_string[1]] = event.result
        end
    end
end

Gridorius.Events:On(defines.events.on_string_translated, on_string_translated)
Gridorius:InitGui()
local TerminalGui = require("scripts.terminal_gui")

Gridorius.Events:OnNthTick(10, function(event, handler_id)
    if game then
        request_translations()
        local network_system = NetworkSystem:new()
        Gridorius.state:set("network_system", network_system)
        TerminalGui.BindInterfaces()
        Gridorius.Events:RemoveNthTickEvent(10, handler_id)
    end
end)
