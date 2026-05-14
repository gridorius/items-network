local new_network_logic = require("scripts.network_runtime")
require("scripts.lib.main")



-- terminal_gui.bind_network_logic(new_network_logic)

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

local test_interface = Gridorius.Gui:CreateDefaultFrame("test_frame", "Title")
	:AppendChild(
		Gridorius.Gui:CreateFlow("test_flow", "vertical")
		:AppendChild(
			Gridorius.Gui:CreateButton("test_button", "Click me!")
		)
	)

Gridorius.Gui:BindInterface("network-terminal", test_interface, function(player)
	return player.gui.screen
end, true)
