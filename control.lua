local network_logic = require("scripts.network_runtime")
local gui = require("scripts.terminal_gui")
local fluid_output_gui = require("scripts.fluid_output_gui")

-- Control.lua only wires game events into the runtime and terminal GUI modules.
gui.bind_network_logic(network_logic)
fluid_output_gui.bind_network_logic(network_logic)

local TOPOLOGY_EVENTS = {
	defines.events.on_built_entity,
	defines.events.on_robot_built_entity,
	defines.events.on_player_mined_entity,
	defines.events.on_robot_mined_entity,
	defines.events.on_entity_died,
	defines.events.script_raised_built,
	defines.events.script_raised_revive,
	defines.events.script_raised_destroy,
}

local TERMINAL_BUFFER_SYNC_INTERVAL_TICKS = 60 * 3
local TERMINAL_GUI_REFRESH_INTERVAL_TICKS = 60

local function has_open_windows()
	return gui.has_open_terminals() or fluid_output_gui.has_open_windows()
end

local function refresh_all_windows()
	gui.refresh_all()
	fluid_output_gui.refresh_all()
end

local function refresh_all_runtime_windows()
	gui.refresh_all_runtime()
end

local function update_blueprint_fluid_output_tags(event)
	local player = game.get_player(event.player_index)

	if not (player and player.valid) then
		return false
	end

	local blueprint = player.blueprint_to_setup

	if not (blueprint and blueprint.valid_for_read and blueprint.is_blueprint_setup()) then
		return false
	end

	local mapping = event.mapping and event.mapping.get and event.mapping.get()

	if not mapping then
		return false
	end

	local updated = false

	for entity_number, source_entity in pairs(mapping) do
		local tags = network_logic.get_fluid_output_blueprint_tags(source_entity)

		if tags then
			local blueprint_tags = blueprint.get_blueprint_entity_tags(entity_number) or {}

			for tag_name, tag_value in pairs(tags) do
				blueprint_tags[tag_name] = tag_value
			end

			blueprint.set_blueprint_entity_tags(entity_number, blueprint_tags)
			updated = true
		end
	end

	return updated
	end

local function flush_pending_opened_frames()
	gui.flush_pending_opened_frames()
	fluid_output_gui.flush_pending_opened_frames()
end

local function refresh_force_unlocks()
	for _, force in pairs(game.forces) do
		force.reset_recipes()
		force.reset_technology_effects()
	end
end

local function initialize_runtime()
	-- On init or config change, rebuild caches so the runtime always starts from live entities.
	refresh_force_unlocks()
	network_logic.init()
	gui.init()
	fluid_output_gui.init()
	network_logic.rebuild_all_networks()

	if has_open_windows() then
		refresh_all_windows()
	end
end

script.on_init(function()
	initialize_runtime()
end)

script.on_configuration_changed(function()
	initialize_runtime()
end)

script.on_event(TOPOLOGY_EVENTS, function(event)
	-- Any structural entity change can invalidate cable graphs, so rebuild through the runtime.
	if network_logic.on_topology_changed(event) then
		if has_open_windows() then
			refresh_all_windows()
		end
	end
end)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
	if network_logic.copy_fluid_output_settings(event.source, event.destination) then
		if has_open_windows() then
			refresh_all_windows()
		end
	end
end)

script.on_event(defines.events.on_player_setup_blueprint, function(event)
	update_blueprint_fluid_output_tags(event)
end)

script.on_event(defines.events.on_tick, function()
	-- A small tick loop keeps the network cache and GUI state in sync without heavy work every frame.
	flush_pending_opened_frames()
	network_logic.flush_pending_surface_visual_refreshes()

	if (game.tick % TERMINAL_BUFFER_SYNC_INTERVAL_TICKS) == 0 then
		network_logic.sync_terminal_buffers()
	end

	if network_logic.flush_pending_surface_rebuilds() then
		if has_open_windows() then
			refresh_all_windows()
		end
	end
end)


script.on_event(defines.events.on_gui_opened, function(event)
	gui.on_gui_opened(event)
	fluid_output_gui.on_gui_opened(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
	gui.on_gui_closed(event)
	fluid_output_gui.on_gui_closed(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
	gui.on_gui_click(event)
	fluid_output_gui.on_gui_click(event)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
	fluid_output_gui.on_gui_elem_changed(event)
end)

script.on_event(defines.events.on_gui_selected_tab_changed, function(event)
	gui.on_gui_selected_tab_changed(event)
end)

script.on_event(defines.events.on_player_left_game, function(event)
	gui.on_player_removed(event)
	fluid_output_gui.on_player_removed(event)
end)

script.on_event(defines.events.on_player_removed, function(event)
	gui.on_player_removed(event)
	fluid_output_gui.on_player_removed(event)
end)

script.on_nth_tick(network_logic.get_tick_interval(), function()
	network_logic.process_networks()

	if gui.has_open_terminals() and (game.tick % TERMINAL_GUI_REFRESH_INTERVAL_TICKS) == 0 then
		refresh_all_runtime_windows()
	end
end)
