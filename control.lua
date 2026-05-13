local new_network_logic = require("scripts.network_runtime")
local terminal_gui = require("scripts.terminal_gui")

terminal_gui.bind_network_logic(new_network_logic)

local BUILD_EVENTS = {
	defines.events.on_built_entity,
	defines.events.on_robot_built_entity,
	defines.events.script_raised_built,
	defines.events.script_raised_revive,
}

local MINING_EVENTS = {
	defines.events.on_player_mined_entity,
	defines.events.on_robot_mined_entity,
	defines.events.on_entity_died,
	defines.events.script_raised_destroy,
}

script.on_event(BUILD_EVENTS, function(event)
	new_network_logic.handle_entity_build(event)
end)

script.on_event(MINING_EVENTS, function(event)
	new_network_logic.handle_entity_mining(event)
end)

script.on_nth_tick(1, function()
	new_network_logic.handle_tick()
end)

script.on_event(defines.events.on_gui_opened, function(event)
	terminal_gui.on_gui_open(event)
	-- fluid_output_gui.on_gui_opened(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
	terminal_gui.on_gui_closed(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
	terminal_gui.on_gui_click(event)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
	terminal_gui.on_gui_element_changed(event)
end)

-- script.on_event(defines.events.on_gui_elem_changed, function(event)
-- end)

-- script.on_event(defines.events.on_gui_selected_tab_changed, function(event)
-- 	gui.on_gui_selected_tab_changed(event)
-- end)