local network_logic = {}
local network_config = require("scripts.network_config")

-- Core runtime module for cable topology, terminal storage, and item routing.
local CABLE_NAME = "network-cable"
local ABSORBER_CABLE_NAME = "network-absorber-cable"
local FLUID_INPUT_NAME = "network-fluid-input"
local FLUID_OUTPUT_NAME = "network-fluid-output"
local FLUID_OUTPUT_BLUEPRINT_TAG = "items_network_selected_fluid_name"
local TERMINAL_NAME = "network-terminal"
local BUFFER_CHEST_NAME = "network-buffer-chest"
local FLUID_PIPE_TRANSFER_AMOUNT = 5000
local NETWORK_TICK_INTERVAL = 1
local NETWORK_PERIODIC_UPDATE_INTERVAL_TICKS = 60
local BUFFER_CHEST_REQUEST_INTERVAL_TICKS = 60
local MACHINE_INPUT_BUFFER_CACHE_TICKS = 120
local NETWORK_REF_AUDIT_BATCH_SIZE = 2
local DEFERRED_REBUILD_INTERVAL_TICKS = 20
local MAX_SURFACE_REBUILDS_PER_FLUSH = 1
local VISUAL_REBUILD_DELAY_TICKS = 120
local TERMINAL_SIGNAL_SECTION_CAPACITY = 100
local VISUAL_CONNECTION_COLOR = { r = 0.2, g = 0.9, b = 1.0, a = 0.9 }
local VISUAL_CONNECTION_WIDTH = 5
local VISUAL_CONNECTION_INSET = 0.16

local MACHINE_TYPES = {
	"assembling-machine",
	"furnace",
	"lab",
	"mining-drill",
}

local MACHINE_TYPE_SET = {
	["assembling-machine"] = true,
	["furnace"] = true,
	["lab"] = true,
	["mining-drill"] = true,
}

local CARDINAL_NEIGHBORS = {
	{ x = -1, y = 0 },
	{ x = 1, y = 0 },
	{ x = 0, y = -1 },
	{ x = 0, y = 1 },
}

local DEFERRED_TOPOLOGY_EVENT_SET = {
	[defines.events.on_built_entity] = true,
	[defines.events.on_robot_built_entity] = true,
	[defines.events.on_player_mined_entity] = true,
	[defines.events.on_robot_mined_entity] = true,
	[defines.events.on_entity_died] = true,
	[defines.events.script_raised_built] = true,
	[defines.events.script_raised_revive] = true,
	[defines.events.script_raised_destroy] = true,
}

local ABSORBABLE_CHEST_TYPES = {
	"container",
	"logistic-container",
	"infinity-container",
}

local ABSORBABLE_CHEST_TYPE_SET = {
	["container"] = true,
	["logistic-container"] = true,
	["infinity-container"] = true,
}

local update_network_item_cache
local update_surface_network_signals
local collect_touching_chests_for_cable
local get_network_for_terminal_data
local enable_entity_logistic_points
local remove_from_network

local function ensure_storage()
	-- All persistent runtime state is kept in `storage` so it survives saves and reloads.
	storage.cable_positions = storage.cable_positions or {}
	storage.terminal_data = storage.terminal_data or {}
	storage.fluid_output_data = storage.fluid_output_data or {}
	storage.connection_render_ids_by_surface = storage.connection_render_ids_by_surface or {}
	storage.network_numeric_ids_by_surface = storage.network_numeric_ids_by_surface or {}
	storage.pending_surface_rebuilds = storage.pending_surface_rebuilds or {}
	storage.pending_surface_visual_refreshes = storage.pending_surface_visual_refreshes or {}
	storage.pending_signal_updates = storage.pending_signal_updates or {}
	storage.next_pending_rebuild_tick = storage.next_pending_rebuild_tick or 0
	storage.next_network_numeric_id = storage.next_network_numeric_id or 1
	storage.networks_by_surface = storage.networks_by_surface or {}
	storage.position_to_network = storage.position_to_network or {}
	storage.processing_settings = storage.processing_settings or {
		extract_machines_per_tick = network_config.DEFAULT_EXTRACT_MACHINES_PER_TICK,
	}
end

local function normalize_extract_machines_per_tick(value)
	return network_config.normalize_extract_machines_per_tick(value)
end

local function normalize_processing_settings(raw_settings)
	raw_settings = raw_settings or {}

	return {
		extract_machines_per_tick = normalize_extract_machines_per_tick(raw_settings.extract_machines_per_tick),
	}
end

local function ensure_processing_settings()
	storage.processing_settings = normalize_processing_settings(storage.processing_settings)
	return storage.processing_settings
end

local function to_grid(value)
	return math.floor(value)
end

local function make_position_key(x, y)
	return x .. ":" .. y
end

local function entity_grid_position(entity)
	return to_grid(entity.position.x), to_grid(entity.position.y)
end

local function get_entity_from_event(event)
	return event.entity or event.created_entity or event.destination
end

local function is_valid_named_entity(entity, expected_name)
	return entity and entity.valid and entity.name == expected_name
end

local function is_terminal_entity(entity)
	return entity
		and entity.valid
		and entity.unit_number
		and entity.name == TERMINAL_NAME
		or false
end

local function is_buffer_chest_entity(entity)
	return entity
		and entity.valid
		and entity.unit_number
		and entity.name == BUFFER_CHEST_NAME
		or false
end

local function is_fluid_input_entity(entity)
	return entity
		and entity.valid
		and entity.unit_number
		and entity.name == FLUID_INPUT_NAME
		or false
end

local function is_fluid_output_entity(entity)
	return entity
		and entity.valid
		and entity.unit_number
		and entity.name == FLUID_OUTPUT_NAME
		or false
end

local function is_supported_machine(entity)
	return entity and entity.valid and MACHINE_TYPE_SET[entity.type] == true
end

local function is_topology_entity(entity)
	-- Only entities that change the graph should trigger a topology rebuild.
	if not entity or not entity.valid then
		return false
	end

	return entity.name == CABLE_NAME
		or entity.name == ABSORBER_CABLE_NAME
		or entity.name == FLUID_INPUT_NAME
		or entity.name == FLUID_OUTPUT_NAME
		or is_terminal_entity(entity)
		or is_buffer_chest_entity(entity)
		or MACHINE_TYPE_SET[entity.type] == true
end

local function record_terminal(entity, existing_terminal_data)
	if not is_terminal_entity(entity) then
		return
	end

	local grid_x, grid_y = entity_grid_position(entity)

	storage.terminal_data[entity.unit_number] = {
		entity = entity,
		unit_number = entity.unit_number,
		surface_index = entity.surface.index,
		position_key = make_position_key(grid_x, grid_y),
		network_id = nil,
		signal_output_active = existing_terminal_data and existing_terminal_data.signal_output_active or false,
		virtual_item_map = existing_terminal_data and existing_terminal_data.virtual_item_map or {},
		virtual_total_items = existing_terminal_data and existing_terminal_data.virtual_total_items or 0,
		virtual_fluid_map = existing_terminal_data and existing_terminal_data.virtual_fluid_map or {},
		virtual_total_fluids = existing_terminal_data and existing_terminal_data.virtual_total_fluids or 0,
	}
end

local function record_fluid_output(entity, existing_fluid_output_data)
	if not is_fluid_output_entity(entity) then
		return
	end

	local grid_x, grid_y = entity_grid_position(entity)

	storage.fluid_output_data[entity.unit_number] = {
		entity = entity,
		unit_number = entity.unit_number,
		surface_index = entity.surface.index,
		position_key = make_position_key(grid_x, grid_y),
		network_id = nil,
		selected_fluid_name = existing_fluid_output_data and existing_fluid_output_data.selected_fluid_name or nil,
	}
end

local function ensure_fluid_output_data(entity)
	if not is_fluid_output_entity(entity) then
		return nil
	end

	local fluid_output_data = storage.fluid_output_data[entity.unit_number]

	if not (fluid_output_data and fluid_output_data.entity and fluid_output_data.entity.valid) then
		record_fluid_output(entity, fluid_output_data)
		fluid_output_data = storage.fluid_output_data[entity.unit_number]
	end

	return fluid_output_data
end

local function rescan_surface_entities(surface)
	-- Rebuild the live cable and terminal cache for one surface before network assembly.
	local cable_positions = {}
	local existing_terminal_data_by_unit = {}
	local existing_fluid_output_data_by_unit = {}

	for _, cable in ipairs(surface.find_entities_filtered({ name = { CABLE_NAME, ABSORBER_CABLE_NAME, FLUID_INPUT_NAME, FLUID_OUTPUT_NAME } })) do
		local grid_x, grid_y = entity_grid_position(cable)
		cable_positions[make_position_key(grid_x, grid_y)] = {
			x = grid_x,
			y = grid_y,
			is_absorber = cable.name == ABSORBER_CABLE_NAME,
			is_fluid_input = cable.name == FLUID_INPUT_NAME,
			is_fluid_output = cable.name == FLUID_OUTPUT_NAME,
		}
	end

	storage.cable_positions[surface.index] = cable_positions

	for unit_number, terminal_data in pairs(storage.terminal_data) do
		if terminal_data.surface_index == surface.index then
			existing_terminal_data_by_unit[unit_number] = terminal_data
			storage.terminal_data[unit_number] = nil
		end
	end

	for unit_number, fluid_output_data in pairs(storage.fluid_output_data) do
		if fluid_output_data.surface_index == surface.index then
			existing_fluid_output_data_by_unit[unit_number] = fluid_output_data
			storage.fluid_output_data[unit_number] = nil
		end
	end

	for _, terminal in ipairs(surface.find_entities_filtered({ name = TERMINAL_NAME })) do
		record_terminal(terminal, existing_terminal_data_by_unit[terminal.unit_number])
	end

	for _, fluid_output in ipairs(surface.find_entities_filtered({ name = FLUID_OUTPUT_NAME })) do
		record_fluid_output(fluid_output, existing_fluid_output_data_by_unit[fluid_output.unit_number])
	end

end

local function enumerate_entity_tiles(entity, callback)
	local box = entity.bounding_box
	local left = math.floor(box.left_top.x + 0.0001)
	local top = math.floor(box.left_top.y + 0.0001)
	local right = math.ceil(box.right_bottom.x - 0.0001) - 1
	local bottom = math.ceil(box.right_bottom.y - 0.0001) - 1

	for tile_x = left, right do
		for tile_y = top, bottom do
			callback(tile_x, tile_y)
		end
	end
end

local function clear_surface_connection_renderings(surface_index)
	local render_ids = storage.connection_render_ids_by_surface[surface_index] or {}

	for _, render_id in ipairs(render_ids) do
		local render_object = rendering.get_object_by_id(render_id)

		if render_object then
			render_object.destroy()
		end
	end

	storage.connection_render_ids_by_surface[surface_index] = nil
end

local function store_surface_connection_rendering(surface_index, render_object)
	if not (render_object and render_object.valid) then
		return
	end

	local render_ids = storage.connection_render_ids_by_surface[surface_index]

	if not render_ids then
		render_ids = {}
		storage.connection_render_ids_by_surface[surface_index] = render_ids
	end

	render_ids[#render_ids + 1] = render_object.id
end

local function make_connection_target(tile_x, tile_y, neighbor)
	if neighbor.x < 0 then
		return { x = tile_x + VISUAL_CONNECTION_INSET, y = tile_y + 0.5 }
	elseif neighbor.x > 0 then
		return { x = tile_x + 1 - VISUAL_CONNECTION_INSET, y = tile_y + 0.5 }
	elseif neighbor.y < 0 then
		return { x = tile_x + 0.5, y = tile_y + VISUAL_CONNECTION_INSET }
	end

	return { x = tile_x + 0.5, y = tile_y + 1 - VISUAL_CONNECTION_INSET }
end

local function draw_entity_connection_lines(surface, entity, cable_positions)
	if not (entity and entity.valid) then
		return
	end

	enumerate_entity_tiles(entity, function(tile_x, tile_y)
		for _, neighbor in ipairs(CARDINAL_NEIGHBORS) do
			local cable_position = cable_positions[make_position_key(tile_x + neighbor.x, tile_y + neighbor.y)]

			if cable_position then
				store_surface_connection_rendering(surface.index, rendering.draw_line({
					surface = surface,
					from = { x = cable_position.x + 0.5, y = cable_position.y + 0.5 },
					to = make_connection_target(tile_x, tile_y, neighbor),
					color = VISUAL_CONNECTION_COLOR,
					width = VISUAL_CONNECTION_WIDTH,
					draw_on_ground = true,
				}))
			end
		end
	end)
end

local function draw_absorber_cable_connection_lines(surface, network_cable_positions, absorber_cable_keys)
	local processed_chests = {}

	for _, cable_key in ipairs(absorber_cable_keys or {}) do
		local cable_position = network_cable_positions[cable_key]

		if cable_position then
			for _, chest in ipairs(collect_touching_chests_for_cable(surface, cable_position.x, cable_position.y)) do
				local entity_key = chest.unit_number or (chest.name .. ":" .. chest.position.x .. ":" .. chest.position.y)

				if not processed_chests[entity_key] then
					processed_chests[entity_key] = true
					draw_entity_connection_lines(surface, chest, {
						[cable_key] = cable_position,
					})
				end
			end
		end
	end
end

local function draw_surface_connection_lines(surface, networks)
	-- Recreate the overlay from scratch so stale connection lines never remain visible.
	clear_surface_connection_renderings(surface.index)

	local cable_positions = storage.cable_positions[surface.index] or {}

	for _, network in pairs(networks or {}) do
		local network_cable_positions = {}

		for _, cable_key in ipairs(network.cable_keys or {}) do
			local cable_position = cable_positions[cable_key]

			if cable_position then
				network_cable_positions[cable_key] = cable_position
			end
		end

		for _, terminal_ref in ipairs(network.terminals or {}) do
			draw_entity_connection_lines(surface, terminal_ref.entity, network_cable_positions)
		end

		for _, buffer_chest_ref in ipairs(network.buffer_chests or {}) do
			draw_entity_connection_lines(surface, buffer_chest_ref.entity, network_cable_positions)
		end

		for _, machine_ref in ipairs(network.machines or {}) do
			draw_entity_connection_lines(surface, machine_ref.entity, network_cable_positions)
		end

		draw_absorber_cable_connection_lines(surface, network_cable_positions, network.absorber_cable_keys)
	end
end

local function collect_primary_touched_network_id(entity, position_to_network)
	-- If an entity touches several networks, choose the smallest id so the result stays deterministic.
	local selected_network_id = nil

	enumerate_entity_tiles(entity, function(tile_x, tile_y)
		for _, neighbor in ipairs(CARDINAL_NEIGHBORS) do
			local neighbor_key = make_position_key(tile_x + neighbor.x, tile_y + neighbor.y)
			local network_id = position_to_network[neighbor_key]

			if network_id and (not selected_network_id or network_id < selected_network_id) then
				selected_network_id = network_id
			end
		end
	end)

	return selected_network_id
end

local function build_surface_networks(surface)
	-- Flood-fill each cable island, then attach terminals and machines that touch that island.
	local cable_positions = storage.cable_positions[surface.index] or {}
	local position_to_network = {}
	local visited = {}
	local networks = {}
	local active_network_roots = {}
	local surface_network_numeric_ids = storage.network_numeric_ids_by_surface[surface.index] or {}

	storage.network_numeric_ids_by_surface[surface.index] = surface_network_numeric_ids

	for position_key, position in pairs(cable_positions) do
		if not visited[position_key] then
			-- Breadth-first search walks one connected cable cluster at a time.
			local queue = { position_key }
			local queue_index = 1
			local cable_keys = {}
			local min_key = position_key

			visited[position_key] = true
			cable_keys[#cable_keys + 1] = position_key
			
			while queue_index <= #queue do
				local current_key = queue[queue_index]
				local current_position = cable_positions[current_key]
				queue_index = queue_index + 1

				if current_key < min_key then
					min_key = current_key
				end

				for _, neighbor in ipairs(CARDINAL_NEIGHBORS) do
					local neighbor_key = make_position_key(current_position.x + neighbor.x, current_position.y + neighbor.y)

					if cable_positions[neighbor_key] and not visited[neighbor_key] then
						visited[neighbor_key] = true
						queue[#queue + 1] = neighbor_key
						cable_keys[#cable_keys + 1] = neighbor_key
					end
				end
			end

			active_network_roots[min_key] = true

			local network_id = surface_network_numeric_ids[min_key]

			if not network_id then
				network_id = storage.next_network_numeric_id
				storage.next_network_numeric_id = network_id + 1
				surface_network_numeric_ids[min_key] = network_id
			end

			local network = {
				id = network_id,
				surface_index = surface.index,
				cable_keys = cable_keys,
				absorber_cable_keys = {},
				fluid_input_keys = {},
				fluid_output_keys = {},
				terminals = {},
				buffer_chests = {},
				signal_dirty = false,
				next_fill_machine_index = 1,
				next_extract_machine_index = 1,
				next_absorber_cable_index = 1,
				next_fluid_input_index = 1,
				next_fluid_output_index = 1,
				next_buffer_chest_index = 1,
				buffer_chest_process_budget = 0,
				next_terminal_ref_check_index = 1,
				next_machine_ref_check_index = 1,
				next_buffer_chest_ref_check_index = 1,
				next_insert_terminal_index = 1,
				next_remove_terminal_index = 1,
				machines = {},
				machine_counts = {},
			}

			for _, cable_key in ipairs(cable_keys) do
				if cable_positions[cable_key] and cable_positions[cable_key].is_absorber then
					network.absorber_cable_keys[#network.absorber_cable_keys + 1] = cable_key
				end

				if cable_positions[cable_key] and cable_positions[cable_key].is_fluid_input then
					network.fluid_input_keys[#network.fluid_input_keys + 1] = cable_key
				end

				if cable_positions[cable_key] and cable_positions[cable_key].is_fluid_output then
					network.fluid_output_keys[#network.fluid_output_keys + 1] = cable_key
				end

				position_to_network[cable_key] = network_id
			end

			networks[network_id] = network
		end
	end

	for root_key in pairs(surface_network_numeric_ids) do
		if not active_network_roots[root_key] then
			surface_network_numeric_ids[root_key] = nil
		end
	end

	for unit_number, terminal_data in pairs(storage.terminal_data) do
		if terminal_data.surface_index == surface.index then
			local terminal = terminal_data.entity

			if is_terminal_entity(terminal) then
				local selected_network_id = collect_primary_touched_network_id(terminal, position_to_network)

				if selected_network_id then
					local network = networks[selected_network_id]

					terminal_data.network_id = selected_network_id
					network.terminals[#network.terminals + 1] = {
						entity = terminal,
						unit_number = unit_number,
					}
				else
					terminal_data.network_id = nil
				end
			else
				storage.terminal_data[unit_number] = nil
			end
		end
	end

	for unit_number, fluid_output_data in pairs(storage.fluid_output_data) do
		if fluid_output_data.surface_index == surface.index then
			if is_fluid_output_entity(fluid_output_data.entity) then
				fluid_output_data.network_id = position_to_network[fluid_output_data.position_key]
			else
				storage.fluid_output_data[unit_number] = nil
			end
		end
	end

	for _, machine in ipairs(surface.find_entities_filtered({ type = MACHINE_TYPES })) do
		if is_supported_machine(machine) and machine.unit_number then
			local selected_network_id = collect_primary_touched_network_id(machine, position_to_network)

			if selected_network_id then
				local network = networks[selected_network_id]

				network.machines[#network.machines + 1] = {
					entity = machine,
					unit_number = machine.unit_number,
					name = machine.name,
					type = machine.type,
				}
				network.machine_counts[machine.name] = (network.machine_counts[machine.name] or 0) + 1
			end
		end
	end

	for _, buffer_chest in ipairs(surface.find_entities_filtered({ name = BUFFER_CHEST_NAME })) do
		if is_buffer_chest_entity(buffer_chest) then
			local selected_network_id = collect_primary_touched_network_id(buffer_chest, position_to_network)
			enable_entity_logistic_points(buffer_chest)

			if selected_network_id then
				local network = networks[selected_network_id]

				network.buffer_chests[#network.buffer_chests + 1] = {
					entity = buffer_chest,
					unit_number = buffer_chest.unit_number,
				}
			end
		end
	end

	storage.networks_by_surface[surface.index] = networks
	storage.position_to_network[surface.index] = position_to_network
end

local function ensure_terminal_behavior(terminal_data)
	-- Terminals emit item counts through a circuit control behavior rather than a real inventory.
	local terminal = terminal_data and terminal_data.entity

	if not is_terminal_entity(terminal) then
		return nil
	end

	return terminal.get_or_create_control_behavior()
end

local function terminal_has_real_circuit_connections(terminal)
	if not is_terminal_entity(terminal) then
		return false
	end

	local connectors = terminal.get_wire_connectors(false)

	for _, connector in pairs(connectors or {}) do
		if connector
			and connector.valid
			and (connector.wire_type == defines.wire_type.red or connector.wire_type == defines.wire_type.green)
			and connector.real_connection_count > 0
		then
			return true
		end
	end

	return false
end

local function collect_network_signal_terminal_data(network)
	local signal_terminals = {}

	for _, terminal_ref in ipairs(network.terminals or {}) do
		local terminal_data = storage.terminal_data[terminal_ref.unit_number]

		if terminal_data and terminal_has_real_circuit_connections(terminal_data.entity) then
			signal_terminals[#signal_terminals + 1] = terminal_data
		end
	end

	return signal_terminals
end

local function ensure_signal_sections(behavior, required_sections)
	-- Spread network signals across as many manual sections as the combinator needs.
	if not (behavior and behavior.valid) then
		return {}
	end

	required_sections = math.max(1, required_sections or 1)
	local sections = {}

	for section_index = 1, required_sections do
		local section = behavior.get_section(section_index)

		if not section then
			section = behavior.add_section()
		end

		if not (section and section.valid) then
			break
		end

		sections[#sections + 1] = section
	end

	while behavior.sections_count > #sections do
		behavior.remove_section(behavior.sections_count)
	end

	return sections
	end

local function clear_signal_section(section)
	if not (section and section.valid) then
		return
	end

	for slot_index = section.filters_count, 1, -1 do
		section.clear_slot(slot_index)
	end
end

local function enable_logistic_point(logistic_point)
	if logistic_point and logistic_point.valid and not logistic_point.enabled then
		logistic_point.enabled = true
	end
end

	enable_entity_logistic_points = function(entity)
	if not (entity and entity.valid) then
		return
	end

	if entity.get_requester_point then
		enable_logistic_point(entity.get_requester_point())
	end

	if not entity.get_logistic_point then
		return
	end

	for _, member_index in pairs(defines.logistic_member_index) do
		enable_logistic_point(entity.get_logistic_point(member_index))
	end
end

local function get_buffer_chest_main_inventory(buffer_chest)
	if not is_buffer_chest_entity(buffer_chest) then
		return nil
	end

	return buffer_chest.get_inventory(defines.inventory.chest)
end

local function get_buffer_chest_trash_inventory(buffer_chest)
	if not is_buffer_chest_entity(buffer_chest) then
		return nil
	end

	return buffer_chest.get_inventory(defines.inventory.logistic_container_trash)
end

local function get_buffer_chest_request_point(buffer_chest)
	if not is_buffer_chest_entity(buffer_chest) then
		return nil
	end

	local logistic_point = buffer_chest.get_requester_point()


	if logistic_point and logistic_point.enabled and logistic_point.valid then
		return logistic_point
	end

	return nil
end

local function normalize_quality(quality)
	if not quality then
		return nil
	end

	if type(quality) == "string" then
		return quality
	end

	if type(quality) == "userdata" or type(quality) == "table" then
		return quality.name
	end

	return quality
end

local function compile_buffer_chest_request_filter(logistic_filter)
	if not logistic_filter then
		return nil
	end

	local raw_value = logistic_filter.value or logistic_filter
	local filter_type = nil
	local filter_name = nil
	local filter_quality = nil
	local filter_comparator = nil

	if type(raw_value) == "string" then
		filter_name = raw_value
	else
		filter_type = raw_value and (raw_value.type or logistic_filter.type) or nil
		filter_name = raw_value and (raw_value.name or logistic_filter.name) or nil
		filter_quality = normalize_quality(raw_value and (raw_value.quality or logistic_filter.quality) or nil)
		filter_comparator = raw_value and (raw_value.comparator or logistic_filter.comparator) or nil
	end

	local requested_count = math.max(
		logistic_filter.count or 0,
		logistic_filter.max_count or 0,
		logistic_filter.min or 0,
		logistic_filter.max or 0
	)

	if (filter_type == nil or filter_type == "item") and filter_name and requested_count > 0 then
		return {
			type = "item",
			name = filter_name,
			quality = filter_quality,
			comparator = filter_comparator,
			count = requested_count,
		}
	end

	return nil
end

local function make_item_id(item_name, quality)
	-- Factorio 2.0 APIs accept either plain item names or quality-aware item ids.
	quality = normalize_quality(quality)

	if quality then
		return {
			name = item_name,
			quality = quality,
		}
	end

	return item_name
end

local function make_item_stack(item_name, count, quality)
	quality = normalize_quality(quality)

	local stack = {
		name = item_name,
		count = count,
	}

	if quality then
		stack.quality = quality
	end

	return stack
end

local function deliver_item_to_player(player, item_name, count, quality)
	-- Put the item into the player's inventory first, then spill the remainder near the player.
	if not (player and player.valid and count and count > 0) then
		return 0
	end

	local item_stack = make_item_stack(item_name, count, quality)
	local inventory = player.get_main_inventory()

	if inventory and inventory.valid then
		local inserted = inventory.insert(item_stack)

		if inserted >= count then
			return inserted
		end

		if player.surface and player.position then
			local remainder = count - inserted
			player.surface.spill_item_stack(player.position, make_item_stack(item_name, remainder, quality), true, player.force, false)
			return count
		end

		return inserted
	end

	return player.insert(make_item_stack(item_name, count, quality))
end

local function make_item_key(item_name, quality)
	quality = normalize_quality(quality)
	return item_name .. "|" .. (quality or "normal")
end

local function sort_item_entries(items)
	-- Sort by count first so the GUI shows the most important stacks at the top.
	table.sort(items, function(left, right)
		if left.count == right.count then
			if left.name == right.name then
				return (normalize_quality(left.quality) or "normal") < (normalize_quality(right.quality) or "normal")
			end

			return left.name < right.name
		end

		return left.count > right.count
	end)
end

local function get_terminal_data(unit_number)
	return unit_number and storage.terminal_data[unit_number] or nil
end

local function get_fluid_output_data(unit_number)
	return unit_number and storage.fluid_output_data[unit_number] or nil
end

local function ensure_terminal_virtual_storage(terminal_data)
	terminal_data.virtual_item_map = terminal_data.virtual_item_map or {}
	terminal_data.virtual_total_items = terminal_data.virtual_total_items or 0
	terminal_data.virtual_fluid_map = terminal_data.virtual_fluid_map or {}
	terminal_data.virtual_total_fluids = terminal_data.virtual_total_fluids or 0
end

local function make_resource_key(resource_type, resource_name, quality)
	if resource_type == "item" then
		quality = normalize_quality(quality)
		return resource_name .. "|" .. (quality or "normal")
	end

	return "fluid|" .. resource_name
end

local function build_sorted_item_list(item_map)
	local items = {}

	for _, item_data in pairs(item_map or {}) do
		items[#items + 1] = item_data
	end

	sort_item_entries(items)

	return items
end

local function collect_terminal_items(terminal_data)
	-- Snapshot the terminal's virtual inventory for GUI refreshes and circuit output.
	ensure_terminal_virtual_storage(terminal_data)
	local item_map = {}

	for resource_key, item_data in pairs(terminal_data.virtual_item_map) do
		item_map[resource_key] = item_data
	end

	for resource_key, fluid_data in pairs(terminal_data.virtual_fluid_map) do
		item_map[resource_key] = fluid_data
	end

	local items = build_sorted_item_list(item_map)
	return items, #items, terminal_data.virtual_total_items + terminal_data.virtual_total_fluids
end

local function get_terminal_virtual_item_count(terminal_data, item_name, quality)
	ensure_terminal_virtual_storage(terminal_data)

	local item_data = terminal_data.virtual_item_map[make_item_key(item_name, quality)]
	return item_data and item_data.count or 0
end

local function terminal_has_any_items(terminal_data)
	-- A terminal stays protected while it still represents active storage.
	local has_virtual_items = terminal_data
		and (((terminal_data.virtual_total_items or 0) > 0) or ((terminal_data.virtual_total_fluids or 0) > 0))
		or false

	return has_virtual_items
end

local function update_terminal_entity_state(terminal_data)
	-- Keep the terminal non-minable while it still holds items or participates in a network.
	local terminal = terminal_data and terminal_data.entity

	if not is_terminal_entity(terminal) then
		return
	end

	local has_items = terminal_has_any_items(terminal_data)
	local network = get_network_for_terminal_data(terminal_data)
	local can_remove = (not has_items) or (network ~= nil and #network.terminals > 1)

	terminal.minable_flag = can_remove
	terminal.destructible = can_remove

	if not can_remove and terminal.to_be_deconstructed() then
		terminal.cancel_deconstruction(terminal.force)
	end
end

local function add_to_terminal_virtual_storage(terminal_data, item_name, count, quality)
	if not (terminal_data and count and count > 0) then
		return 0
	end

	ensure_terminal_virtual_storage(terminal_data)
	quality = normalize_quality(quality)

	local item_key = make_item_key(item_name, quality)
	local existing = terminal_data.virtual_item_map[item_key]

	if existing then
		existing.count = existing.count + count
	else
		terminal_data.virtual_item_map[item_key] = {
			type = "item",
			name = item_name,
			quality = quality,
			count = count,
		}
	end

	terminal_data.virtual_total_items = terminal_data.virtual_total_items + count
	update_terminal_entity_state(terminal_data)

	return count
end

local function add_to_terminal_virtual_fluid_storage(terminal_data, fluid_name, amount)
	if not (terminal_data and amount and amount > 0) then
		return 0
	end

	ensure_terminal_virtual_storage(terminal_data)
	amount = math.max(0, math.floor(amount))

	if amount <= 0 then
		return 0
	end

	local fluid_key = make_resource_key("fluid", fluid_name)
	local existing = terminal_data.virtual_fluid_map[fluid_key]

	if existing then
		existing.count = existing.count + amount
	else
		terminal_data.virtual_fluid_map[fluid_key] = {
			type = "fluid",
			name = fluid_name,
			count = amount,
		}
	end

	terminal_data.virtual_total_fluids = terminal_data.virtual_total_fluids + amount
	update_terminal_entity_state(terminal_data)

	return amount
end

local function remove_from_terminal_virtual_storage(terminal_data, item_name, requested_count, quality)
	if not (terminal_data and requested_count and requested_count > 0) then
		return 0
	end

	ensure_terminal_virtual_storage(terminal_data)

	local item_key = make_item_key(item_name, quality)
	local existing = terminal_data.virtual_item_map[item_key]

	if not existing then
		return 0
	end

	local removed = math.min(existing.count, requested_count)
	existing.count = existing.count - removed
	terminal_data.virtual_total_items = math.max(0, terminal_data.virtual_total_items - removed)

	if existing.count <= 0 then
		terminal_data.virtual_item_map[item_key] = nil
	end

	update_terminal_entity_state(terminal_data)

	return removed
end

local function get_terminal_virtual_fluid_count(terminal_data, fluid_name)
	ensure_terminal_virtual_storage(terminal_data)

	local fluid_data = terminal_data.virtual_fluid_map[make_resource_key("fluid", fluid_name)]
	return fluid_data and fluid_data.count or 0
end

local function remove_from_terminal_virtual_fluid_storage(terminal_data, fluid_name, requested_amount)
	if not (terminal_data and requested_amount and requested_amount > 0) then
		return 0
	end

	ensure_terminal_virtual_storage(terminal_data)
	requested_amount = math.max(0, math.floor(requested_amount))

	if requested_amount <= 0 then
		return 0
	end

	local fluid_key = make_resource_key("fluid", fluid_name)
	local existing = terminal_data.virtual_fluid_map[fluid_key]

	if not existing then
		return 0
	end

	local removed = math.min(existing.count, requested_amount)
	existing.count = existing.count - removed
	terminal_data.virtual_total_fluids = math.max(0, terminal_data.virtual_total_fluids - removed)

	if existing.count <= 0 then
		terminal_data.virtual_fluid_map[fluid_key] = nil
	end

	update_terminal_entity_state(terminal_data)

	return removed
end

local function get_network_by_id(surface_index, network_id)
	local surface_networks = storage.networks_by_surface[surface_index] or {}
	return surface_networks[network_id]
end

get_network_for_terminal_data = function(terminal_data)
	if not (terminal_data and terminal_data.network_id) then
		return nil
	end

	return get_network_by_id(terminal_data.surface_index, terminal_data.network_id)
end

local function get_preferred_network_terminal_data(network, preferred_unit_number)
	if not preferred_unit_number then
		return nil
	end

	local preferred_terminal_data = get_terminal_data(preferred_unit_number)

	if preferred_terminal_data and preferred_terminal_data.network_id == network.id then
		return preferred_terminal_data
	end

	return nil
end

local function sync_terminal_buffer(terminal_data)
	update_terminal_entity_state(terminal_data)

	return false
end

local function sync_surface_terminal_buffers(surface_index)
	local changed = false

	for unit_number, terminal_data in pairs(storage.terminal_data) do
		if terminal_data.surface_index == surface_index then
			if is_terminal_entity(terminal_data.entity) then
				if sync_terminal_buffer(terminal_data) then
					changed = true
				end
			else
				storage.terminal_data[unit_number] = nil
			end
		end
	end

	if changed then
		update_surface_network_signals(surface_index, storage.networks_by_surface[surface_index])
	end

	return changed
end

local function get_item_prototype(item_name)
	return item_name and prototypes.item[item_name] or nil
end

local function rebuild_network_item_cache(network)
	local item_map = {}
	local item_types = 0
	local total_items = 0

	for _, terminal_ref in ipairs(network.terminals) do
		local terminal_data = get_terminal_data(terminal_ref.unit_number)

		if terminal_data then
			for _, item_stack in pairs(terminal_data.virtual_item_map or {}) do
				local item_key = make_item_key(item_stack.name, item_stack.quality)
				local existing = item_map[item_key]

				if existing then
					existing.count = existing.count + item_stack.count
				else
					item_map[item_key] = {
						type = "item",
						name = item_stack.name,
						quality = item_stack.quality,
						count = item_stack.count,
					}
					item_types = item_types + 1
				end

				total_items = total_items + item_stack.count
			end

			for _, fluid_stack in pairs(terminal_data.virtual_fluid_map or {}) do
				local fluid_key = make_resource_key("fluid", fluid_stack.name)
				local existing = item_map[fluid_key]

				if existing then
					existing.count = existing.count + fluid_stack.count
				else
					item_map[fluid_key] = {
						type = "fluid",
						name = fluid_stack.name,
						count = fluid_stack.count,
					}
					item_types = item_types + 1
				end

				total_items = total_items + fluid_stack.count
			end
		end
	end

	network.item_cache_tick = game.tick
	network.item_cache_map = item_map
	network.item_cache_items = build_sorted_item_list(item_map)
	network.item_cache_item_types = item_types
	network.item_cache_total_items = total_items
end

local function ensure_network_item_cache(network)
	if network.item_cache_tick == game.tick and network.item_cache_map then
		return
	end

	rebuild_network_item_cache(network)
end

local function mark_network_signal_dirty(network)
	if not network then
		return
	end

	network.signal_dirty = true

	local surface_updates = storage.pending_signal_updates[network.surface_index]

	if not surface_updates then
		surface_updates = {
			order = {},
			queued_ids = {},
			next_index = 1,
		}
		storage.pending_signal_updates[network.surface_index] = surface_updates
	end

	if surface_updates.queued_ids[network.id] then
		return
	end

	surface_updates.queued_ids[network.id] = true
	surface_updates.order[#surface_updates.order + 1] = network.id
end

local function update_network_resource_cache(network, resource_type, resource_name, quality, count_delta)
	if not (network.item_cache_tick == game.tick and network.item_cache_map) then
		return
	end

	local item_key = make_resource_key(resource_type, resource_name, quality)
	local existing = network.item_cache_map[item_key]

	if existing then
		existing.count = existing.count + count_delta

		if existing.count <= 0 then
			network.item_cache_map[item_key] = nil
			network.item_cache_item_types = math.max(0, network.item_cache_item_types - 1)
		end
	elseif count_delta > 0 then
		network.item_cache_map[item_key] = {
			type = resource_type,
			name = resource_name,
			quality = resource_type == "item" and quality or nil,
			count = count_delta,
		}
		network.item_cache_item_types = network.item_cache_item_types + 1
	else
		return
	end

	network.item_cache_total_items = math.max(0, network.item_cache_total_items + count_delta)
	network.item_cache_items = nil
	mark_network_signal_dirty(network)
end

update_network_item_cache = function(network, item_name, quality, count_delta)
	update_network_resource_cache(network, "item", item_name, quality, count_delta)
end

local function update_network_fluid_cache(network, fluid_name, count_delta)
	update_network_resource_cache(network, "fluid", fluid_name, nil, count_delta)
end

local function get_network_item_snapshot(network)
	ensure_network_item_cache(network)

	if not network.item_cache_items then
		network.item_cache_items = build_sorted_item_list(network.item_cache_map)
	end

	return network.item_cache_items, network.item_cache_item_types, network.item_cache_total_items
end

local function get_item_fuel_value(item_name)
	local item_prototype = get_item_prototype(item_name)

	if not (item_prototype and item_prototype.fuel_category and item_prototype.fuel_value > 0) then
		return 0
	end

	return item_prototype.fuel_value
end

local function burner_accepts_item(burner, item_name)
	if not (burner and burner.valid and item_name) then
		return false
	end

	local item_prototype = get_item_prototype(item_name)

	return item_prototype
		and item_prototype.fuel_category
		and burner.fuel_categories[item_prototype.fuel_category] == true
		and item_prototype.fuel_value > 0
		or false
end

local function get_burner_total_fuel_value(burner)
	if not (burner and burner.valid) then
		return 0
	end

	local total = burner.heat + burner.remaining_burning_fuel

	for slot_index = 1, #burner.inventory do
		local item_stack = burner.inventory[slot_index]

		if item_stack and item_stack.valid_for_read then
			total = total + (get_item_fuel_value(item_stack.name) * item_stack.count)
		end
	end

	return total
end

local function find_best_network_fuel(network, burner)
	local best_fuel = nil

	ensure_network_item_cache(network)

	for _, item_stack in pairs(network.item_cache_map) do
		if item_stack.type ~= "item" then
			goto continue
		end

		if burner_accepts_item(burner, item_stack.name) and item_stack.count > 0 then
			local fuel_value = get_item_fuel_value(item_stack.name)

			if fuel_value > 0 and (not best_fuel or fuel_value > best_fuel.fuel_value) then
				best_fuel = {
					name = item_stack.name,
					quality = item_stack.quality,
					fuel_value = fuel_value,
				}
			end
		end

		::continue::
	end

	return best_fuel
end

local function get_network_item_count(network, item_name, quality)
	ensure_network_item_cache(network)

	local item_data = network.item_cache_map[make_item_key(item_name, quality)]
	return item_data and item_data.count or 0
end

local function get_network_fluid_count(network, fluid_name)
	ensure_network_item_cache(network)

	local fluid_data = network.item_cache_map[make_resource_key("fluid", fluid_name)]
	return fluid_data and fluid_data.count or 0
end

local function item_quality_matches(actual_quality, requested_quality, comparator)
	actual_quality = normalize_quality(actual_quality) or "normal"
	requested_quality = normalize_quality(requested_quality)

	if not requested_quality then
		return true
	end

	if comparator == "=" or not comparator then
		return actual_quality == requested_quality
	end

	return actual_quality == requested_quality
end

local function get_inventory_matching_item_count(inventory, item_name, quality, comparator)
	if not inventory then
		return 0
	end

	local total = 0

	for slot_index = 1, #inventory do
		local item_stack = inventory[slot_index]

		if item_stack
			and item_stack.valid_for_read
			and item_stack.name == item_name
			and item_quality_matches(item_stack.quality, quality, comparator)
		then
			total = total + item_stack.count
		end
	end

	return total
end

local function collect_matching_network_item_stacks(network, item_name, quality, comparator)
	ensure_network_item_cache(network)

	local stacks = {}

	for _, item_stack in pairs(network.item_cache_map or {}) do
		if  item_stack.name == item_name
			and item_stack.count > 0
			and item_quality_matches(item_stack.quality, quality, comparator)
		then
			stacks[#stacks + 1] = {
				type = "item",
				name = item_stack.name,
				quality = item_stack.quality,
				count = item_stack.count,
			}
		end
	end

	table.sort(stacks, function(left, right)
		local left_quality = left.quality or "normal"
		local right_quality = right.quality or "normal"

		if left_quality == right_quality then
			if left.count == right.count then
				return left.name < right.name
			end

			return left.count > right.count
		end

		if left_quality == "normal" then
			return true
		end

		if right_quality == "normal" then
			return false
		end

		return left_quality < right_quality
	end)

	return stacks
end

local function remove_matching_items_from_network(network, item_name, requested_count, quality, comparator)
	if requested_count <= 0 then
		return {}, 0
	end

	local removed_stacks = {}
	local remaining = requested_count

	for _, item_stack in ipairs(collect_matching_network_item_stacks(network, item_name, quality, comparator)) do
		if remaining <= 0 then
			break
		end

		local removed = remove_from_network(network, item_name, remaining, item_stack.quality)

		if removed > 0 then
			removed_stacks[#removed_stacks + 1] = make_item_stack(item_name, removed, item_stack.quality)
			remaining = remaining - removed
		end
	end

	return removed_stacks, requested_count - remaining
end

local function get_matching_network_item_count(network, item_name, quality, comparator)
	local total = 0

	for _, item_stack in ipairs(collect_matching_network_item_stacks(network, item_name, quality, comparator)) do
		total = total + item_stack.count
	end

	return total
end

local function get_network_insertable_count(network, item_name, quality)
	if #network.terminals > 0 then
		return 2147483647
	end

	return 0
end

local function normalize_terminal_index(terminals_count, index)
	if terminals_count <= 0 then
		return 1
	end

	return ((math.floor(index or 1) - 1) % terminals_count) + 1
end

remove_from_network = function(network, item_name, requested_count, quality)
	local removed_total = 0
	local remaining = requested_count
	local terminals_count = #network.terminals

	if terminals_count <= 0 or remaining <= 0 then
		return 0
	end

	local start_index = normalize_terminal_index(terminals_count, network.next_remove_terminal_index)
	local last_index = start_index

	for offset = 0, terminals_count - 1 do
		if remaining <= 0 then
			break
		end

		local terminal_index = ((start_index + offset - 1) % terminals_count) + 1
		local terminal_ref = network.terminals[terminal_index]
		last_index = terminal_index

		if terminal_ref then
			local terminal_data = get_terminal_data(terminal_ref.unit_number)

			if terminal_data then
				local removed = remove_from_terminal_virtual_storage(terminal_data, item_name, remaining, quality)

				if removed > 0 then
					removed_total = removed_total + removed
					remaining = remaining - removed
					update_network_item_cache(network, item_name, quality, -removed)
				end
			end
		end
	end

	network.next_remove_terminal_index = normalize_terminal_index(terminals_count, last_index + 1)

	return removed_total
end

local function insert_into_network(network, item_name, requested_count, quality, preferred_unit_number)
	local terminals_count = #network.terminals

	if terminals_count <= 0 or requested_count <= 0 then
		return 0
	end

	local terminal_data = get_preferred_network_terminal_data(network, preferred_unit_number)

	if terminal_data then
		add_to_terminal_virtual_storage(terminal_data, item_name, requested_count, quality)
		update_network_item_cache(network, item_name, quality, requested_count)
		network.next_insert_terminal_index = normalize_terminal_index(terminals_count, network.next_insert_terminal_index + 1)
		return requested_count
	end

	local start_index = normalize_terminal_index(terminals_count, network.next_insert_terminal_index)
	local last_index = start_index

	for offset = 0, terminals_count - 1 do
		local terminal_index = ((start_index + offset - 1) % terminals_count) + 1
		local terminal_ref = network.terminals[terminal_index]
		last_index = terminal_index

		if terminal_ref then
			terminal_data = get_terminal_data(terminal_ref.unit_number)

			if terminal_data then
				add_to_terminal_virtual_storage(terminal_data, item_name, requested_count, quality)
				update_network_item_cache(network, item_name, quality, requested_count)
				network.next_insert_terminal_index = normalize_terminal_index(terminals_count, terminal_index + 1)
				return requested_count
			end
		end
	end

	network.next_insert_terminal_index = normalize_terminal_index(terminals_count, last_index + 1)

	return 0
end

local function insert_fluid_into_network(network, fluid_name, requested_amount, preferred_unit_number)
	local terminals_count = #network.terminals

	if terminals_count <= 0 or requested_amount <= 0 then
		return 0
	end

	local terminal_data = get_preferred_network_terminal_data(network, preferred_unit_number)

	if terminal_data then
		add_to_terminal_virtual_fluid_storage(terminal_data, fluid_name, requested_amount)
		update_network_fluid_cache(network, fluid_name, requested_amount)
		network.next_insert_terminal_index = normalize_terminal_index(terminals_count, network.next_insert_terminal_index + 1)
		return requested_amount
	end

	local start_index = normalize_terminal_index(terminals_count, network.next_insert_terminal_index)
	local last_index = start_index

	for offset = 0, terminals_count - 1 do
		local terminal_index = ((start_index + offset - 1) % terminals_count) + 1
		local terminal_ref = network.terminals[terminal_index]
		last_index = terminal_index

		if terminal_ref then
			terminal_data = get_terminal_data(terminal_ref.unit_number)

			if terminal_data then
				add_to_terminal_virtual_fluid_storage(terminal_data, fluid_name, requested_amount)
				update_network_fluid_cache(network, fluid_name, requested_amount)
				network.next_insert_terminal_index = normalize_terminal_index(terminals_count, terminal_index + 1)
				return requested_amount
			end
		end
	end

	network.next_insert_terminal_index = normalize_terminal_index(terminals_count, last_index + 1)

	return 0
end

local function remove_fluid_from_network(network, fluid_name, requested_amount)
	local removed_total = 0
	local remaining = math.max(0, math.floor(requested_amount or 0))
	local terminals_count = #network.terminals

	if terminals_count <= 0 or remaining <= 0 then
		return 0
	end

	local start_index = normalize_terminal_index(terminals_count, network.next_remove_terminal_index)
	local last_index = start_index

	for offset = 0, terminals_count - 1 do
		if remaining <= 0 then
			break
		end

		local terminal_index = ((start_index + offset - 1) % terminals_count) + 1
		local terminal_ref = network.terminals[terminal_index]
		last_index = terminal_index

		if terminal_ref then
			local terminal_data = get_terminal_data(terminal_ref.unit_number)

			if terminal_data then
				local removed = remove_from_terminal_virtual_fluid_storage(terminal_data, fluid_name, remaining)

				if removed > 0 then
					removed_total = removed_total + removed
					remaining = remaining - removed
					update_network_fluid_cache(network, fluid_name, -removed)
				end
			end
		end
	end

	network.next_remove_terminal_index = normalize_terminal_index(terminals_count, last_index + 1)

	return removed_total
end

local function top_up_machine_fuel(network, entity)
	-- Burner-style machines can draw compatible fuel from network storage before crafting.
	local burner = entity and entity.burner or nil

	if not (burner and burner.valid) then
		return
	end

	local fuel_inventory = burner.inventory

	if not fuel_inventory then
		return
	end

	local target_fuel_value = math.max(burner.heat_capacity * 2, 1)
	local current_fuel_value = get_burner_total_fuel_value(burner)

	while current_fuel_value < target_fuel_value do
		local best_fuel = find_best_network_fuel(network, burner)

		if not best_fuel then
			break
		end

		local item_id = make_item_id(best_fuel.name, best_fuel.quality)

		if fuel_inventory.get_insertable_count(item_id) <= 0 then
			break
		end

		local removed = remove_from_network(network, best_fuel.name, 1, best_fuel.quality)

		if removed <= 0 then
			break
		end

		local inserted = fuel_inventory.insert(make_item_stack(best_fuel.name, removed, best_fuel.quality))

		if inserted < removed then
			insert_into_network(network, best_fuel.name, removed - inserted, best_fuel.quality)
		end

		if inserted <= 0 then
			break
		end

		current_fuel_value = current_fuel_value + (best_fuel.fuel_value * inserted)
	end
end

local function move_output_into_network(network, output_inventory)
	-- Machine output is drained into the shared network inventory in small, safe batches.
	if not output_inventory then
		return
	end

	for slot_index = 1, #output_inventory do
		local item_stack = output_inventory[slot_index]

		if not (item_stack and item_stack.valid_for_read) then
			goto continue
		end

		local item_name = item_stack.name
		local item_quality = item_stack.quality
		local transferable = math.min(item_stack.count, get_network_insertable_count(network, item_name, item_quality))

		if transferable > 0 then
			local removed = output_inventory.remove(make_item_stack(item_name, transferable, item_quality))

			if removed > 0 then
				local inserted = insert_into_network(network, item_name, removed, item_quality)

				if inserted < removed then
					output_inventory.insert(make_item_stack(item_name, removed - inserted, item_quality))
				end
			end
		end

		::continue::
	end
end

local function move_recipe_fluid_outputs_into_network(network, entity, recipe)
	if not (entity and entity.valid and recipe and recipe.products) then
		return
	end

	local fluid_contents = entity.get_fluid_contents()

	for _, product in ipairs(recipe.products) do
		if product.type ~= "fluid" then
			goto continue
		end

		local available = math.max(0, math.floor(fluid_contents[product.name] or 0))

		if available <= 0 then
			goto continue
		end

		local removed = math.max(0, math.floor(entity.remove_fluid({ name = product.name, amount = available }) or 0))

		if removed <= 0 then
			goto continue
		end

		local inserted = insert_fluid_into_network(network, product.name, removed)

		if inserted < removed then
			entity.insert_fluid({ name = product.name, amount = removed - inserted })
		end

		::continue::
	end
end

local function is_absorbable_chest(entity)
	-- Only ordinary storage chests are eligible for absorber-cable pickup.
	if not (entity and entity.valid) then
		return false
	end

	if entity.name == TERMINAL_NAME or entity.name == BUFFER_CHEST_NAME then
		return false
	end

	return ABSORBABLE_CHEST_TYPE_SET[entity.type] == true
end

local function collect_buffer_chest_request_filters_from_sections(sections)
	local request_filters = {}

	for _, section in ipairs(sections or {}) do
		if section and section.valid and section.active then
			for _, section_filter in ipairs(section.filters or {}) do
				local compiled_filter = compile_buffer_chest_request_filter(section_filter)

				if compiled_filter then
					request_filters[#request_filters + 1] = compiled_filter
				end
			end
		end
	end

	return request_filters
end

local function get_buffer_chest_request_filters(buffer_chest, request_point)
	if not (buffer_chest and buffer_chest.valid and request_point and request_point.valid) then
		return {}
	end

	local compiled_filters = {}

	for _, logistic_filter in pairs(request_point.filters or {}) do
		local compiled_filter = compile_buffer_chest_request_filter(logistic_filter)

		if compiled_filter then
			compiled_filters[#compiled_filters + 1] = compiled_filter
		end
	end

	if #compiled_filters > 0 then
		return compiled_filters
	end

	local entity_sections = buffer_chest.get_logistic_sections()

	if entity_sections and entity_sections.valid then
		local section_filters = collect_buffer_chest_request_filters_from_sections(entity_sections.sections)

		if #section_filters > 0 then
			return section_filters
		end
	end

	return collect_buffer_chest_request_filters_from_sections(request_point.sections)
end

local function request_items_into_buffer_chest(network, buffer_chest)
	local request_point = get_buffer_chest_request_point(buffer_chest)
	local main_inventory = get_buffer_chest_main_inventory(buffer_chest)

	if not (request_point and request_point.valid and main_inventory and main_inventory.valid) then
		return
	end

	local inventory = main_inventory

	local request_filters = get_buffer_chest_request_filters(buffer_chest, request_point)

	if #request_filters == 0 then
		return
	end

	for _, logistic_filter in ipairs(request_filters) do
		if logistic_filter.name and logistic_filter.count and logistic_filter.count > 0 then
			local current_count = get_inventory_matching_item_count(
				inventory,
				logistic_filter.name,
				logistic_filter.quality,
				logistic_filter.comparator
			)
			local missing_count = logistic_filter.count - current_count

			if missing_count > 0 then
				local removed_stacks = remove_matching_items_from_network(
					network,
					logistic_filter.name,
					missing_count,
					logistic_filter.quality,
					logistic_filter.comparator
				)

				for _, removed_stack in ipairs(removed_stacks) do
					local inserted = inventory.insert(removed_stack)

					if inserted < removed_stack.count then
						insert_into_network(network, removed_stack.name, removed_stack.count - inserted, removed_stack.quality)
					end
				end
			end
		end
	end
end

local function process_network_buffer_chest(network, buffer_chest_ref)
	local buffer_chest = buffer_chest_ref and buffer_chest_ref.entity or nil

	if not is_buffer_chest_entity(buffer_chest) then
		return
	end

	local trash_inventory = get_buffer_chest_trash_inventory(buffer_chest)

	if trash_inventory and trash_inventory.valid and not trash_inventory.is_empty() then
		move_output_into_network(network, trash_inventory)
	end

	request_items_into_buffer_chest(network, buffer_chest)
end

local function process_network_buffer_chests(network)
	local buffer_chests = network.buffer_chests or {}
	local buffer_chest_count = #buffer_chests

	if buffer_chest_count <= 0 then
		network.buffer_chest_process_budget = 0
		return
	end

	network.buffer_chest_process_budget = (network.buffer_chest_process_budget or 0)
		+ (buffer_chest_count / BUFFER_CHEST_REQUEST_INTERVAL_TICKS)

	local batch_size = math.min(buffer_chest_count, math.floor(network.buffer_chest_process_budget))

	if batch_size <= 0 then
		return
	end

	network.buffer_chest_process_budget = math.max(0, network.buffer_chest_process_budget - batch_size)
	local buffer_chest_index = normalize_terminal_index(buffer_chest_count, network.next_buffer_chest_index)

	for _ = 1, batch_size do
		process_network_buffer_chest(network, buffer_chests[buffer_chest_index])
		buffer_chest_index = normalize_terminal_index(buffer_chest_count, buffer_chest_index + 1)
	end

	network.next_buffer_chest_index = buffer_chest_index
end

local function get_absorbable_inventory(entity)
	if not is_absorbable_chest(entity) then
		return nil
	end

	local inventory = entity.get_inventory(defines.inventory.chest)

	if inventory then
		return inventory
	end

	return nil
end

local function chest_touches_cable_tile(chest, cable_x, cable_y)
	local touching = false

	enumerate_entity_tiles(chest, function(tile_x, tile_y)
		if touching then
			return
		end

		for _, neighbor in ipairs(CARDINAL_NEIGHBORS) do
			if tile_x == (cable_x + neighbor.x) and tile_y == (cable_y + neighbor.y) then
				touching = true
				break
			end
		end
	end)

	return touching
end

collect_touching_chests_for_cable = function(surface, cable_x, cable_y)
	local touching_chests = {}
	local entities = surface.find_entities_filtered({
		area = {
			{ x = cable_x - 1, y = cable_y - 1 },
			{ x = cable_x + 2, y = cable_y + 2 },
		},
		type = ABSORBABLE_CHEST_TYPES,
	})

	for _, entity in ipairs(entities) do
		if is_absorbable_chest(entity) and chest_touches_cable_tile(entity, cable_x, cable_y) then
			touching_chests[#touching_chests + 1] = entity
		end
	end

	return touching_chests
end

local function absorb_touching_chests(network, max_cables_per_tick)
	local absorber_cable_keys = network.absorber_cable_keys or {}
	local absorber_count = #absorber_cable_keys

	if absorber_count <= 0 then
		return
	end

	local surface = game.surfaces[network.surface_index]

	if not (surface and surface.valid) then
		return
	end

	local cable_positions = storage.cable_positions[network.surface_index] or {}
	local cables_to_process = math.min(absorber_count, math.max(1, max_cables_per_tick))
	local cable_index = normalize_terminal_index(absorber_count, network.next_absorber_cable_index)
	local processed_chests = {}

	for _ = 1, cables_to_process do
		local cable_key = absorber_cable_keys[cable_index]
		local cable_position = cable_key and cable_positions[cable_key] or nil

		if cable_position then
			for _, chest in ipairs(collect_touching_chests_for_cable(surface, cable_position.x, cable_position.y)) do
				local chest_key = chest.unit_number or (chest.name .. ":" .. cable_position.x .. ":" .. cable_position.y)

				if not processed_chests[chest_key] then
					processed_chests[chest_key] = true

					local inventory = get_absorbable_inventory(chest)

					if inventory and not inventory.is_empty() then
						move_output_into_network(network, inventory)
					end
				end
			end
		end

		cable_index = normalize_terminal_index(absorber_count, cable_index + 1)
	end

	network.next_absorber_cable_index = cable_index
end

local function absorb_fluid_input(network, fluid_input)
	if not is_fluid_input_entity(fluid_input) then
		return
	end

	for fluid_name, amount in pairs(fluid_input.get_fluid_contents() or {}) do
		local transferable = math.max(0, math.floor(amount))

		if transferable > 0 then
			local removed = math.max(0, math.floor(fluid_input.remove_fluid({ name = fluid_name, amount = transferable }) or 0))

			if removed > 0 then
				insert_fluid_into_network(network, fluid_name, removed)
			end
		end
	end
end

local function absorb_fluid_inputs(network, max_inputs_per_tick)
	local fluid_input_keys = network.fluid_input_keys or {}
	local fluid_input_count = #fluid_input_keys

	if fluid_input_count <= 0 then
		return
	end

	local surface = game.surfaces[network.surface_index]

	if not (surface and surface.valid) then
		return
	end

	local cable_positions = storage.cable_positions[network.surface_index] or {}
	local inputs_to_process = math.min(fluid_input_count, math.max(1, max_inputs_per_tick))
	local input_index = normalize_terminal_index(fluid_input_count, network.next_fluid_input_index)

	for _ = 1, inputs_to_process do
		local cable_key = fluid_input_keys[input_index]
		local cable_position = cable_key and cable_positions[cable_key] or nil

		if cable_position then
			local fluid_input = surface.find_entity(FLUID_INPUT_NAME, {
				x = cable_position.x + 0.5,
				y = cable_position.y + 0.5,
			})

			if fluid_input then
				absorb_fluid_input(network, fluid_input)
			end
		end

		input_index = normalize_terminal_index(fluid_input_count, input_index + 1)
	end

	network.next_fluid_input_index = input_index
end

local function process_fluid_output(network, fluid_output)
	if not is_fluid_output_entity(fluid_output) then
		return
	end

	local fluid_output_data = get_fluid_output_data(fluid_output.unit_number)

	if not (fluid_output_data and fluid_output_data.selected_fluid_name) then
		return
	end

	local selected_fluid_name = fluid_output_data.selected_fluid_name
	local fluid_contents = fluid_output.get_fluid_contents() or {}
	local current_amount = 0

	for fluid_name, amount in pairs(fluid_contents) do
		local normalized_amount = math.max(0, math.floor(amount or 0))

		if normalized_amount > 0 and fluid_name ~= selected_fluid_name then
			return
		end

		if fluid_name == selected_fluid_name then
			current_amount = normalized_amount
		end
	end

	local missing_amount = math.max(0, FLUID_PIPE_TRANSFER_AMOUNT - current_amount)
	local requested_amount = math.min(missing_amount, get_network_fluid_count(network, selected_fluid_name))

	if requested_amount <= 0 then
		return
	end

	local removed = remove_fluid_from_network(network, selected_fluid_name, requested_amount)

	if removed <= 0 then
		return
	end

	local inserted = math.max(0, math.floor(fluid_output.insert_fluid({ name = selected_fluid_name, amount = removed }) or 0))

	if inserted < removed then
		insert_fluid_into_network(network, selected_fluid_name, removed - inserted)
	end
end

local function process_fluid_outputs(network, max_outputs_per_tick)
	local fluid_output_keys = network.fluid_output_keys or {}
	local fluid_output_count = #fluid_output_keys

	if fluid_output_count <= 0 then
		return
	end

	local surface = game.surfaces[network.surface_index]

	if not (surface and surface.valid) then
		return
	end

	local cable_positions = storage.cable_positions[network.surface_index] or {}
	local outputs_to_process = math.min(fluid_output_count, math.max(1, max_outputs_per_tick))
	local output_index = normalize_terminal_index(fluid_output_count, network.next_fluid_output_index)

	for _ = 1, outputs_to_process do
		local cable_key = fluid_output_keys[output_index]
		local cable_position = cable_key and cable_positions[cable_key] or nil

		if cable_position then
			local fluid_output = surface.find_entity(FLUID_OUTPUT_NAME, {
				x = cable_position.x + 0.5,
				y = cable_position.y + 0.5,
			})

			if fluid_output then
				process_fluid_output(network, fluid_output)
			end
		end

		output_index = normalize_terminal_index(fluid_output_count, output_index + 1)
	end

	network.next_fluid_output_index = output_index
end

local function move_fluid_output_contents_into_network(fluid_output_data)
	if not fluid_output_data then
		return
	end

	local fluid_output = fluid_output_data.entity

	if not is_fluid_output_entity(fluid_output) then
		return
	end

	local network = fluid_output_data.network_id and get_network_by_id(fluid_output_data.surface_index, fluid_output_data.network_id) or nil

	if not network then
		return
	end

	for fluid_name, amount in pairs(fluid_output.get_fluid_contents() or {}) do
		local transferable = math.max(0, math.floor(amount or 0))

		if transferable > 0 then
			local removed = math.max(0, math.floor(fluid_output.remove_fluid({ name = fluid_name, amount = transferable }) or 0))

			if removed > 0 then
				local inserted = insert_fluid_into_network(network, fluid_name, removed)

				if inserted < removed then
					fluid_output.insert_fluid({ name = fluid_name, amount = removed - inserted })
				end
			end
		end
	end
end

local function collect_network_items(network)
	return get_network_item_snapshot(network)
end



local function build_signal_filters(items)
	local filters = {}

	for index, item_data in ipairs(items) do
		local resource_type = item_data.type or "item"
		local value = {
			name = item_data.name,
			quality = "normal",
			comparator = "=",
		}

		if resource_type == "fluid" then
			value.type = "fluid"
		else
			value.quality = normalize_quality(item_data.quality) or "normal"
		end

		filters[index] = {
			value = value,
			min = math.max(0, math.floor(item_data.count or 0)),
		}
	end

	return filters
end


local function apply_signal_filters(sections, filters)
	local next_filter_index = 1

	for _, section in ipairs(sections) do
		clear_signal_section(section)
		local section_has_filters = false

		for slot_index = 1, TERMINAL_SIGNAL_SECTION_CAPACITY do
			local filter = filters[next_filter_index]

			if not filter then
				break
			end

			section.set_slot(slot_index, filter)
			section_has_filters = true
			next_filter_index = next_filter_index + 1
		end

		section.active = section_has_filters
	end
end

local function update_terminal_signal_output(terminal_data, filters)
	local behavior = ensure_terminal_behavior(terminal_data)
	
	if not behavior then
		return
	end

	local required_sections = math.max(1, math.ceil(#filters / TERMINAL_SIGNAL_SECTION_CAPACITY))
	local sections = ensure_signal_sections(behavior, required_sections)

	if #sections <= 0 then
		return
	end

	apply_signal_filters(sections, filters)

	behavior.enabled = #filters > 0
	terminal_data.signal_output_active = #filters > 0
end

local function clear_terminal_signal_output(terminal_data)
	local terminal = terminal_data and terminal_data.entity

	if not is_terminal_entity(terminal) then
		return
	end

	local behavior = terminal.get_control_behavior()
	terminal_data.signal_output_active = false

	if not (behavior and behavior.valid) then
		return
	end

	for section_index = 1, behavior.sections_count do
		local section = behavior.get_section(section_index)

		if section and section.valid then
			clear_signal_section(section)
			section.active = false
		end
	end

	while behavior.sections_count > 1 do
		behavior.remove_section(behavior.sections_count)
	end

	behavior.enabled = false
end

update_surface_network_signals = function(surface_index, networks)
	local updated = {}

	for _, network in pairs(networks or {}) do
		if #network.terminals > 0 then
			local signal_terminals = collect_network_signal_terminal_data(network)

			if #signal_terminals > 0 then
				local items = collect_network_items(network)
				local filters = build_signal_filters(items)

				for _, terminal_data in ipairs(signal_terminals) do
					pcall(update_terminal_signal_output, terminal_data, filters)
					updated[terminal_data.unit_number] = true
				end
			end
		end

		network.signal_dirty = false
	end

	for unit_number, terminal_data in pairs(storage.terminal_data) do
		if terminal_data.surface_index == surface_index and terminal_data.signal_output_active and not updated[unit_number] then
			pcall(clear_terminal_signal_output, terminal_data)
		end
	end
end

local function update_network_signal_outputs(network)
	if not network then
		return
	end

	if #network.terminals <= 0 then
		network.signal_dirty = false
		return
	end

	local signal_terminals = collect_network_signal_terminal_data(network)

	if #signal_terminals <= 0 then
		network.signal_dirty = false
		return
	end

	local items = collect_network_items(network)
	local filters = build_signal_filters(items)

	for _, terminal_data in ipairs(signal_terminals) do
		pcall(update_terminal_signal_output, terminal_data, filters)
	end

	network.signal_dirty = false
end

local function flush_pending_network_signal_updates(max_networks_per_surface)
	if max_networks_per_surface <= 0 then
		return
	end

	for surface_index, surface_updates in pairs(storage.pending_signal_updates or {}) do
		local networks = storage.networks_by_surface[surface_index] or {}
		local processed = 0

		while processed < max_networks_per_surface do
			local next_index = surface_updates.next_index or 1
			local network_id = surface_updates.order[next_index]

			if not network_id then
				break
			end

			surface_updates.next_index = next_index + 1
			surface_updates.queued_ids[network_id] = nil
			processed = processed + 1

			update_network_signal_outputs(networks[network_id])
		end

		if (surface_updates.next_index or 1) > #surface_updates.order then
			storage.pending_signal_updates[surface_index] = nil
		end
	end
end

local function get_machine_target_craft_buffer(machine_ref, entity, recipe, refill_interval_ticks)
	local cache = machine_ref.input_buffer_cache
	local recipe_energy = math.max(recipe.energy or 0.5, 0.001)
	local crafting_speed = math.max(0, entity.crafting_speed or 0)

	if cache
		and cache.recipe_name == recipe.name
		and cache.recipe_energy == recipe_energy
		and cache.crafting_speed == crafting_speed
		and cache.refill_interval_ticks == refill_interval_ticks
		and (game.tick < cache.next_refresh_tick)
	then
		return cache.target_craft_buffer
	end

	local crafts_per_refill = (crafting_speed * refill_interval_ticks) / (recipe_energy * 60)
	local target_craft_buffer = math.max(2, math.ceil(crafts_per_refill) + 1)

	machine_ref.input_buffer_cache = {
		recipe_name = recipe.name,
		recipe_energy = recipe_energy,
		crafting_speed = crafting_speed,
		refill_interval_ticks = refill_interval_ticks,
		target_craft_buffer = target_craft_buffer,
		next_refresh_tick = game.tick + MACHINE_INPUT_BUFFER_CACHE_TICKS,
	}

	return target_craft_buffer
end

local function top_up_recipe_inputs(network, machine_ref, entity, input_inventory, recipe, recipe_quality, refill_interval_ticks)
	if not (machine_ref and entity and entity.valid and recipe) then
		return
	end

	local target_craft_buffer = get_machine_target_craft_buffer(machine_ref, entity, recipe, refill_interval_ticks)
	local fluid_contents = entity.get_fluid_contents()

	for _, ingredient in ipairs(recipe.ingredients) do
		if ingredient.type == "item" then
			if not input_inventory then
				goto continue
			end

			local ingredient_quality = normalize_quality(ingredient.quality or recipe_quality)
			local item_id = make_item_id(ingredient.name, ingredient_quality)
			local ingredient_amount = math.max(1, math.ceil(ingredient.amount or 1))
			local target_buffer_count = ingredient_amount * target_craft_buffer
			local current_count = get_inventory_matching_item_count(input_inventory, ingredient.name, ingredient_quality, "=")
			local missing_count = math.max(0, target_buffer_count - current_count)
			local removable = get_network_item_count(network, ingredient.name, ingredient_quality)
			local insertable = input_inventory.get_insertable_count(item_id)
			local requested = math.min(missing_count, removable, insertable)

			if requested > 0 then
				local removed = remove_from_network(network, ingredient.name, requested, ingredient_quality)

				if removed > 0 then
					local inserted = input_inventory.insert(make_item_stack(ingredient.name, removed, ingredient_quality))

					if inserted < removed then
						insert_into_network(network, ingredient.name, removed - inserted, ingredient_quality)
					end
				end
			end
		elseif ingredient.type == "fluid" then
			local ingredient_amount = math.max(1, math.ceil(ingredient.amount or 1))
			local target_buffer_amount = ingredient_amount * target_craft_buffer
			local current_amount = fluid_contents[ingredient.name] or 0
			local missing_amount = math.max(0, math.ceil(target_buffer_amount - current_amount))
			local removable = get_network_fluid_count(network, ingredient.name)
			local requested = math.min(missing_amount, removable)

			if requested > 0 then
				local removed = remove_fluid_from_network(network, ingredient.name, requested)

				if removed > 0 then
					local inserted = math.max(0, math.floor(entity.insert_fluid({ name = ingredient.name, amount = removed }) or 0))

					if inserted < removed then
						insert_fluid_into_network(network, ingredient.name, removed - inserted)
					end

					if inserted > 0 then
						fluid_contents[ingredient.name] = current_amount + inserted
					end
				end
			end
		end

		::continue::
	end
end


local function process_assembler(network, machine_ref, do_fill_inputs, do_extract_outputs, refill_interval_ticks)
	local entity = machine_ref.entity
	local recipe, recipe_quality = entity.get_recipe()
	local input_inventory = entity.get_inventory(defines.inventory.crafter_input)
	local output_inventory = entity.get_output_inventory()

	if do_fill_inputs then
		top_up_machine_fuel(network, entity)
		top_up_recipe_inputs(network, machine_ref, entity, input_inventory, recipe, recipe_quality, refill_interval_ticks)
	end

	if do_extract_outputs then
		move_output_into_network(network, output_inventory)
		move_recipe_fluid_outputs_into_network(network, entity, recipe)
	end
end


local function process_furnace(network, machine_ref, do_fill_inputs, do_extract_outputs, refill_interval_ticks)
	local entity = machine_ref.entity
	local recipe, recipe_quality = entity.get_recipe()
	local source_inventory = entity.get_inventory(defines.inventory.crafter_input)
	local result_inventory = entity.get_output_inventory()

	if do_fill_inputs then
		top_up_machine_fuel(network, entity)
		top_up_recipe_inputs(network, machine_ref, entity, source_inventory, recipe, recipe_quality, refill_interval_ticks)
	end

	if do_extract_outputs then
		move_output_into_network(network, result_inventory)
		move_recipe_fluid_outputs_into_network(network, entity, recipe)
	end
end

local function process_mining_drill(network, entity, do_extract_outputs)
	if do_extract_outputs then
		top_up_machine_fuel(network, entity)
		local output_inventory = entity.get_output_inventory()
		move_output_into_network(network, output_inventory)
	end
end

local function process_lab(network, machine_ref, do_fill_inputs, do_extract_outputs)
	local entity = machine_ref.entity

	if not (entity and entity.valid) then
		return
	end

	local input_inventory = entity.get_inventory(defines.inventory.lab_input)

	if not (input_inventory and input_inventory.valid) then
		return
	end

	if not do_fill_inputs then
		return
	end

	local lab_inputs = entity.prototype.lab_inputs or {}

	if #lab_inputs <= 0 then
		return
	end

	local supported_science_packs = {}
	local current_counts = {}
	local network_stacks_by_name = {}
	local target_buffer_count = 2

	for _, science_pack_name in ipairs(lab_inputs) do
		if science_pack_name then
			supported_science_packs[science_pack_name] = true
		end
	end

	for slot_index = 1, #input_inventory do
		local item_stack = input_inventory[slot_index]

		if item_stack and item_stack.valid_for_read and supported_science_packs[item_stack.name] then
			current_counts[item_stack.name] = (current_counts[item_stack.name] or 0) + item_stack.count
		end
	end

	ensure_network_item_cache(network)

	for _, item_stack in pairs(network.item_cache_map or {}) do
		if (item_stack.type == nil or item_stack.type == "item")
			and item_stack.count > 0
			and supported_science_packs[item_stack.name]
		then
			local stacks = network_stacks_by_name[item_stack.name]

			if not stacks then
				stacks = {}
				network_stacks_by_name[item_stack.name] = stacks
			end

			stacks[#stacks + 1] = {
				name = item_stack.name,
				quality = item_stack.quality,
				count = item_stack.count,
			}
		end
	end

	for _, stacks in pairs(network_stacks_by_name) do
		table.sort(stacks, function(left, right)
			local left_quality = left.quality or "normal"
			local right_quality = right.quality or "normal"

			if left_quality == right_quality then
				if left.count == right.count then
					return left.name < right.name
				end

				return left.count > right.count
			end

			if left_quality == "normal" then
				return true
			end

			if right_quality == "normal" then
				return false
			end

			return left_quality < right_quality
		end)
	end

	for _, science_pack_name in ipairs(lab_inputs) do
		if not science_pack_name then
			goto continue_fill
		end

		local current_count = current_counts[science_pack_name] or 0
		local missing_count = math.max(0, target_buffer_count - current_count)
		local requested = missing_count

		if requested > 0 then
			for _, network_stack in ipairs(network_stacks_by_name[science_pack_name] or {}) do
				if requested <= 0 then
					break
				end

				local removed = remove_from_network(network, science_pack_name, requested, network_stack.quality)

				if removed <= 0 then
					goto continue_removed_stack
				end

				local removed_stack = make_item_stack(science_pack_name, removed, network_stack.quality)
				local inserted = entity.insert(removed_stack)

				if inserted <= 0 then
					inserted = input_inventory.insert(removed_stack)
				end

				if inserted > 0 then
					current_counts[science_pack_name] = current_count + inserted
					current_count = current_counts[science_pack_name]
					requested = math.max(0, target_buffer_count - current_count)
				end

				if inserted < removed_stack.count then
					insert_into_network(network, removed_stack.name, removed_stack.count - inserted, removed_stack.quality)
				end

				::continue_removed_stack::
			end
		end

		::continue_fill::
	end
end

local function process_network_machine(machine_ref, network, do_fill_inputs, do_extract_outputs, refill_interval_ticks)
	-- Input refill and output extraction are split so each machine can be throttled independently.
	local entity = machine_ref and machine_ref.entity

	if not (entity and entity.valid) then
		return
	end

	if machine_ref.type == "assembling-machine" then
		process_assembler(network, machine_ref, do_fill_inputs, do_extract_outputs, refill_interval_ticks)
	elseif machine_ref.type == "furnace" then
		process_furnace(network, machine_ref, do_fill_inputs, do_extract_outputs, refill_interval_ticks)
	elseif machine_ref.type == "lab" then
		process_lab(network, machine_ref, do_fill_inputs, do_extract_outputs)
	elseif machine_ref.type == "mining-drill" then
		process_mining_drill(network, entity, do_extract_outputs)
	end
end

local function network_has_invalid_refs(network)
	local function audit_refs(refs, index_field, validator)
		local refs_count = #refs

		if refs_count <= 0 then
			network[index_field] = 1
			return false
		end

		local ref_index = normalize_terminal_index(refs_count, network[index_field])
		local refs_to_check = math.min(refs_count, NETWORK_REF_AUDIT_BATCH_SIZE)

		for _ = 1, refs_to_check do
			local ref = refs[ref_index]

			if not validator(ref and ref.entity) then
				return true
			end

			ref_index = normalize_terminal_index(refs_count, ref_index + 1)
		end

		network[index_field] = ref_index
		return false
	end

	if audit_refs(network.terminals, "next_terminal_ref_check_index", is_terminal_entity) then
		return true
	end

	if audit_refs(network.machines, "next_machine_ref_check_index", is_supported_machine) then
		return true
	end

	if audit_refs(network.buffer_chests or {}, "next_buffer_chest_ref_check_index", is_buffer_chest_entity) then
		return true
	end

	return false
end

function network_logic.init()
	ensure_storage()
end

function network_logic.is_terminal(entity)
	return is_terminal_entity(entity)
end

function network_logic.is_fluid_output(entity)
	return is_fluid_output_entity(entity)
end

function network_logic.is_topology_entity(entity)
	return is_topology_entity(entity)
end

function network_logic.get_tick_interval()
	return NETWORK_TICK_INTERVAL
end

function network_logic.rebuild_surface(surface)
	ensure_storage()

	if not (surface and surface.valid) then
		return
	end

	rescan_surface_entities(surface)
	build_surface_networks(surface)
	sync_surface_terminal_buffers(surface.index)
	storage.pending_surface_visual_refreshes[surface.index] = nil
	storage.pending_signal_updates[surface.index] = nil
	draw_surface_connection_lines(surface, storage.networks_by_surface[surface.index])
	update_surface_network_signals(surface.index, storage.networks_by_surface[surface.index])
end

local function rebuild_surface_runtime(surface, defer_visual_refresh)
	rescan_surface_entities(surface)
	build_surface_networks(surface)
	sync_surface_terminal_buffers(surface.index)
	storage.pending_signal_updates[surface.index] = nil
	update_surface_network_signals(surface.index, storage.networks_by_surface[surface.index])

	if defer_visual_refresh then
		storage.pending_surface_visual_refreshes[surface.index] = game.tick + VISUAL_REBUILD_DELAY_TICKS
	else
		storage.pending_surface_visual_refreshes[surface.index] = nil
		draw_surface_connection_lines(surface, storage.networks_by_surface[surface.index])
	end
end

function network_logic.rebuild_all_networks()
	ensure_storage()

	for _, surface in pairs(game.surfaces) do
		network_logic.rebuild_surface(surface)
	end
end

function network_logic.flush_pending_surface_rebuilds()
	ensure_storage()

	if game.tick < (storage.next_pending_rebuild_tick or 0) then
		return false
	end

	local pending_surface_rebuilds = storage.pending_surface_rebuilds
	local surface_indexes = {}

	for surface_index in pairs(pending_surface_rebuilds) do
		surface_indexes[#surface_indexes + 1] = surface_index
	end

	if #surface_indexes == 0 then
		return false
	end

	table.sort(surface_indexes)
	storage.next_pending_rebuild_tick = game.tick + DEFERRED_REBUILD_INTERVAL_TICKS

	local rebuilt_count = 0

	for _, surface_index in ipairs(surface_indexes) do
		if rebuilt_count >= MAX_SURFACE_REBUILDS_PER_FLUSH then
			break
		end

		pending_surface_rebuilds[surface_index] = nil
		rebuilt_count = rebuilt_count + 1

		local surface = game.surfaces[surface_index]

		if surface and surface.valid then
			rebuild_surface_runtime(surface, true)
		end
	end

	return rebuilt_count > 0
end

function network_logic.flush_pending_surface_visual_refreshes()
	ensure_storage()

	local refreshed = false

	for surface_index, due_tick in pairs(storage.pending_surface_visual_refreshes) do
		if game.tick >= due_tick and not storage.pending_surface_rebuilds[surface_index] then
			local surface = game.surfaces[surface_index]

			if surface and surface.valid then
				draw_surface_connection_lines(surface, storage.networks_by_surface[surface.index])
			end

			storage.pending_surface_visual_refreshes[surface_index] = nil
			refreshed = true
		end
	end

	return refreshed
end

function network_logic.sync_terminal_buffers()
	ensure_storage()

	local dirty_surfaces = {}

	for unit_number, terminal_data in pairs(storage.terminal_data) do
		if is_terminal_entity(terminal_data.entity) then
			if sync_terminal_buffer(terminal_data) then
				dirty_surfaces[terminal_data.surface_index] = true
			end
		else
			storage.terminal_data[unit_number] = nil
		end
	end

	for surface_index in pairs(dirty_surfaces) do
		update_surface_network_signals(surface_index, storage.networks_by_surface[surface_index])
	end

	return next(dirty_surfaces) ~= nil
end

function network_logic.on_topology_changed(event)
	ensure_storage()

	local entity = get_entity_from_event(event)

	if not is_topology_entity(entity) then
		return false
	end

	if is_buffer_chest_entity(entity) then
		enable_entity_logistic_points(entity)
	end

	if event.tags then
		network_logic.apply_fluid_output_blueprint_tags(entity, event.tags)
	end

	if DEFERRED_TOPOLOGY_EVENT_SET[event.name] then
		storage.pending_surface_rebuilds[entity.surface.index] = true
		return false
	end

	network_logic.rebuild_surface(entity.surface)

	return true
end

function network_logic.process_networks()
	-- Main runtime tick: absorb items, feed machines, extract outputs, and refresh dirty signals.
	ensure_storage()
	local processing_settings = ensure_processing_settings()
	local extract_machines_per_tick = processing_settings.extract_machines_per_tick
	local do_periodic_network_update = (game.tick % NETWORK_PERIODIC_UPDATE_INTERVAL_TICKS) == 0
	local absorb_batch_size = extract_machines_per_tick * NETWORK_PERIODIC_UPDATE_INTERVAL_TICKS

	local dirty_surfaces = {}

	for surface_index, networks in pairs(storage.networks_by_surface) do
		for _, network in pairs(networks) do
			if network_has_invalid_refs(network) then
				dirty_surfaces[surface_index] = true
				break
			end

			if #network.terminals > 0 then
				if do_periodic_network_update then
					absorb_touching_chests(network, absorb_batch_size)
					absorb_fluid_inputs(network, absorb_batch_size)
				end

				process_fluid_outputs(network, math.max(1, extract_machines_per_tick))

				process_network_buffer_chests(network)

				local machines_count = #network.machines

				if machines_count > 0 then
					local fill_index = normalize_terminal_index(machines_count, network.next_fill_machine_index)
					local fill_batch_size = math.min(machines_count, extract_machines_per_tick)
					local refill_interval_ticks = math.max(1, math.ceil(machines_count / fill_batch_size))
					local extract_batch_size = math.min(machines_count, extract_machines_per_tick)
					local extract_index = normalize_terminal_index(machines_count, network.next_extract_machine_index)

					for _ = 1, fill_batch_size do
						process_network_machine(network.machines[fill_index], network, true, false, refill_interval_ticks)
						fill_index = normalize_terminal_index(machines_count, fill_index + 1)
					end

					for _ = 1, extract_batch_size do
						process_network_machine(network.machines[extract_index], network, false, true, refill_interval_ticks)
						extract_index = normalize_terminal_index(machines_count, extract_index + 1)
					end

					network.next_fill_machine_index = fill_index
					network.next_extract_machine_index = extract_index
				end
			end
		end
	end

	for surface_index in pairs(dirty_surfaces) do
		network_logic.rebuild_surface(game.surfaces[surface_index])
	end

	flush_pending_network_signal_updates(math.max(1, extract_machines_per_tick))
end

function network_logic.get_processing_settings()
	ensure_storage()
	local settings = ensure_processing_settings()

	return {
		extract_machines_per_tick = settings.extract_machines_per_tick,
	}
end

function network_logic.set_processing_settings(extract_machines_per_tick)
	ensure_storage()

	storage.processing_settings = normalize_processing_settings({
		extract_machines_per_tick = extract_machines_per_tick,
	})

	return network_logic.get_processing_settings()
end

function network_logic.get_terminal_snapshot(unit_number)
	ensure_storage()

	local terminal_data = storage.terminal_data[unit_number]

	if not terminal_data then
		return nil
	end

	local terminal = terminal_data.entity

	if not is_terminal_entity(terminal) then
		storage.terminal_data[unit_number] = nil
		return nil
	end

	local snapshot = {
		terminal = terminal,
		terminal_count = 1,
		network_id = terminal_data.network_id,
		connected = terminal_data.network_id ~= nil,
		item_types = 0,
		total_items = 0,
		items = {},
		machines = {},
		machine_total = 0,
	}

	if not terminal_data.network_id then
		snapshot.items, snapshot.item_types, snapshot.total_items = collect_terminal_items(terminal_data)
		return snapshot
	end

	local surface_networks = storage.networks_by_surface[terminal.surface.index] or {}
	local network = surface_networks[terminal_data.network_id]

	if not network then
		snapshot.connected = false
		return snapshot
	end

	snapshot.terminal_count = #network.terminals
	snapshot.items, snapshot.item_types, snapshot.total_items = collect_network_items(network)

	for machine_name, machine_count in pairs(network.machine_counts) do
		snapshot.machine_total = snapshot.machine_total + machine_count
		snapshot.machines[#snapshot.machines + 1] = {
			name = machine_name,
			count = machine_count,
		}
	end

	table.sort(snapshot.machines, function(left, right)
		if left.count == right.count then
			return left.name < right.name
		end

		return left.count > right.count
	end)

	return snapshot
end

function network_logic.get_fluid_output_snapshot(unit_number)
	ensure_storage()

	local fluid_output_data = storage.fluid_output_data[unit_number]

	if not fluid_output_data then
		return nil
	end

	local fluid_output = fluid_output_data.entity

	if not is_fluid_output_entity(fluid_output) then
		storage.fluid_output_data[unit_number] = nil
		return nil
	end

	local snapshot = {
		entity = fluid_output,
		connected = false,
		network_id = fluid_output_data.network_id,
		selected_fluid_name = fluid_output_data.selected_fluid_name,
		available_amount = 0,
		current_amount = 0,
	}

	if fluid_output_data.selected_fluid_name then
		snapshot.current_amount = math.max(0, math.floor((fluid_output.get_fluid_contents() or {})[fluid_output_data.selected_fluid_name] or 0))
	end

	if not fluid_output_data.network_id then
		return snapshot
	end

	local surface_networks = storage.networks_by_surface[fluid_output.surface.index] or {}
	local network = surface_networks[fluid_output_data.network_id]

	if not network then
		snapshot.network_id = nil
		return snapshot
	end

	snapshot.connected = true

	if fluid_output_data.selected_fluid_name then
		snapshot.available_amount = get_network_fluid_count(network, fluid_output_data.selected_fluid_name)
	end

	return snapshot
end

function network_logic.set_fluid_output_filter(unit_number, fluid_name)
	ensure_storage()

	local fluid_output_data = storage.fluid_output_data[unit_number]

	if not fluid_output_data then
		return false
	end

	if fluid_name and not prototypes.fluid[fluid_name] then
		fluid_name = nil
	end

	if fluid_output_data.selected_fluid_name == fluid_name then
		return true
	end

	fluid_output_data.selected_fluid_name = fluid_name
	move_fluid_output_contents_into_network(fluid_output_data)

	return true
end

function network_logic.get_fluid_output_blueprint_tags(entity)
	ensure_storage()

	if not is_fluid_output_entity(entity) then
		return nil
	end

	local fluid_output_data = storage.fluid_output_data[entity.unit_number]

	if not (fluid_output_data and fluid_output_data.selected_fluid_name) then
		return nil
	end

	return {
		[FLUID_OUTPUT_BLUEPRINT_TAG] = fluid_output_data.selected_fluid_name,
	}
end

function network_logic.apply_fluid_output_blueprint_tags(entity, tags)
	ensure_storage()

	if not (is_fluid_output_entity(entity) and type(tags) == "table") then
		return false
	end

	local fluid_name = tags[FLUID_OUTPUT_BLUEPRINT_TAG]

	if fluid_name ~= nil and not prototypes.fluid[fluid_name] then
		fluid_name = nil
	end

	if fluid_name == nil and tags[FLUID_OUTPUT_BLUEPRINT_TAG] == nil then
		return false
	end

	local fluid_output_data = ensure_fluid_output_data(entity)

	if not fluid_output_data then
		return false
	end

	return network_logic.set_fluid_output_filter(fluid_output_data.unit_number, fluid_name)
end

function network_logic.copy_fluid_output_settings(source_entity, destination_entity)
	ensure_storage()

	if not (is_fluid_output_entity(source_entity) and is_fluid_output_entity(destination_entity)) then
		return false
	end

	local source_data = storage.fluid_output_data[source_entity.unit_number]

	if not source_data then
		return false
	end

	return network_logic.set_fluid_output_filter(destination_entity.unit_number, source_data.selected_fluid_name)
end

function network_logic.take_terminal_item(unit_number, player, item_name, quality, requested_count)
	ensure_storage()

	if not (player and player.valid and item_name) then
		return 0
	end

	local terminal_data = storage.terminal_data[unit_number]

	if not terminal_data then
		return 0
	end

	local terminal = terminal_data.entity

	if not is_terminal_entity(terminal) then
		storage.terminal_data[unit_number] = nil
		return 0
	end

	local network_id = terminal_data.network_id
	local surface_networks = storage.networks_by_surface[terminal.surface.index] or {}
	local network = network_id and surface_networks[network_id] or nil
	local available_count = network
		and get_network_item_count(network, item_name, quality)
		or get_terminal_virtual_item_count(terminal_data, item_name, quality)

	if available_count <= 0 then
		return 0
	end

	local item_prototype = get_item_prototype(item_name)
	local clamped_requested_count = math.min(
		available_count,
		math.max(1, math.floor(requested_count or (item_prototype and item_prototype.stack_size or 1)))
	)
	local removed = network
		and remove_from_network(network, item_name, clamped_requested_count, quality)
		or remove_from_terminal_virtual_storage(terminal_data, item_name, clamped_requested_count, quality)

	if removed <= 0 then
		return 0
	end

	local inserted = deliver_item_to_player(player, item_name, removed, quality)

	if inserted < removed then
		if network then
			insert_into_network(network, item_name, removed - inserted, quality, unit_number)
		else
			add_to_terminal_virtual_storage(terminal_data, item_name, removed - inserted, quality)
			update_terminal_entity_state(terminal_data)
		end
	end

	if inserted > 0 and network then
		update_surface_network_signals(terminal.surface.index, surface_networks)
	end

	return inserted
end

return network_logic
