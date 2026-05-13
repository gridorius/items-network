local new_network_logic = {
	networks = {},
	initialized = false,
	distribute_queue = {},
}
local network_config = require("scripts.network_config")

local SERVER_NAME = "network-server"
local CABLE_NAME = "network-cable"
local CONNECTOR_NAME = "network-connector"
local TERMINAL_NAME = "network-terminal"
local BUFFER_CHEST_NAME = "network-buffer-chest"
local FLUID_INPUT = "network-fluid-input"
local FLUID_OUTPUT = "network-fluid-output"
local REBUILD_DELAY = 60

local MACHINE_TYPES = {
	"assembling-machine",
	"furnace",
	"lab",
	"mining-drill",
	"rocket-silo",
}

local ABSORBABLE_CHEST_TYPES = {
	"container",
	"infinity-container",
}


local function ensure_storage()
	storage.networks = storage.networks or {}
	storage.cables = storage.cables or {}
	storage.terminals = storage.terminals or {}
	storage.pipes = storage.pipes or {}
	storage.network_changed = storage.network_changed or {}
	storage.rebuild_delay = storage.rebuild_delay or REBUILD_DELAY
	storage.last_network_id = storage.last_network_id or 0
end

local function get_next_network_id()
	storage.last_network_id = storage.last_network_id + 1
	return storage.last_network_id
end

local function emit_changes(surface_index)
	storage.network_changed[surface_index] = true
	storage.rebuild_delay = REBUILD_DELAY
end

local function init_network_data(network_id, network_data)
	storage.networks[network_id] = {
		items = network_data and network_data.items or {
			-- Example: ["iron-ore"] = {
			--     ["normal"] = 100,
			--     ["legendary"] = 50,
			-- }
		},
		fluids = network_data and network_data.fluids or {
			-- Example: ["crude-oil"] = 1000
		},
		fluid_inputs = network_data and network_data.fluid_inputs or {},
		fluid_outputs = network_data and network_data.fluid_outputs or {},
		chests = network_data and network_data.chests or {},
		machines = network_data and network_data.machines or {},
		terminals = network_data and network_data.terminals or {},
		use_fuels = network_data and network_data.use_fuels or {},
	}
end

local function is_topology_entity(entity)
	if not entity or not entity.valid then
		return false
	end

	return entity.name == TERMINAL_NAME
		or entity.name == BUFFER_CHEST_NAME
end

local is_machine_entity = function(entity)
	if not entity or not entity.valid then
		return false
	end

	for _, type in pairs(MACHINE_TYPES) do
		if entity.type == type then
			return true
		end
	end

	return false
end

local is_chest_entity = function(entity)
	if not entity or not entity.valid then
		return false
	end

	for _, type in pairs(ABSORBABLE_CHEST_TYPES) do
		if entity.type == type then
			return true
		end
	end

	return false
end

local function get_entity_from_event(event)
	return event.entity or event.created_entity or event.destination
end

local function merge_networks(target_id, source_id)
	if target_id == source_id then return end
	local target_network = storage.networks[target_id]
	local source_network = storage.networks[source_id]
	if not target_network or not source_network then return end

	-- Merge items
	for item_name, tiers in pairs(source_network.items) do
		target_network.items[item_name] = target_network.items[item_name] or {}
		for tier, count in pairs(tiers) do
			target_network.items[item_name][tier] = (target_network.items[item_name][tier] or 0) + count
		end
	end

	storage.networks[source_id] = nil
	game.print("Merged network " .. source_id .. " into " .. target_id)
end

local function connect_neighbor(network_id, entity, visited)
	visited = visited or {}

	if visited[entity.unit_number] then
		return
	end
	visited[entity.unit_number] = true
	if entity.name == CABLE_NAME then
		if(not storage.cables[entity.unit_number]) then
			storage.cables[entity.unit_number] = {
				entity = entity,
				network_id = network_id,
			}
		else
			storage.cables[entity.unit_number].network_id = network_id
		end
		connect_neighbor(network_id, entity, visited)
	end
	if entity.name == CONNECTOR_NAME then
		local connected_entity = storage.connector_entity and storage.connector_entity[entity.unit_number]
		if connected_entity and connected_entity.valid  then
			if is_machine_entity(connected_entity) then
				new_network_logic.get_network(network_id):add_machine(connected_entity)
			end
			if  connected_entity.name == FLUID_INPUT then
				new_network_logic.get_network(network_id):add_fluid_input(connected_entity)
			end
			if connected_entity.name == FLUID_OUTPUT then
				new_network_logic.get_network(network_id):add_fluid_output(connected_entity)
			end
			if is_chest_entity(connected_entity) then
				new_network_logic.get_network(network_id):add_chest(connected_entity)
			end
			if connected_entity.name == TERMINAL_NAME then
				local terminal_data = storage.terminals[connected_entity.unit_number]
				new_network_logic.get_network(network_id):add_terminal(connected_entity)
				if terminal_data and terminal_data.network_id ~= network_id then
					if(not terminal_data.network_id) then
						terminal_data.network_id = network_id
						game.print("Assigned existing terminal " .. connected_entity.unit_number .. " to network " .. network_id)
					else
						merge_networks(network_id, terminal_data.network_id)
					end
				end
			end
		end
	end

	for _, neighbor in pairs(entity.heat_neighbours) do
		if neighbor and neighbor.valid then
			connect_neighbor(network_id, neighbor, visited)
		end
	end
end

local search_network_by_connectors = function(entity)
	local connectors = storage.connectors and storage.connectors[entity.unit_number]
	if connectors then
		for _, connector in pairs(connectors) do
			if connector and connector.valid then
				for _, neighbor in pairs(connector.heat_neighbours) do
					if neighbor and neighbor.valid then
						local cable_data = storage.cables and storage.cables[neighbor.unit_number]
						if cable_data and cable_data.network_id then
							return cable_data.network_id
						end
					end
				end
			end
		end
	end
	return nil
end

local function try_attach_to_network(entity)
	local network_id = search_network_by_connectors(entity)
	if network_id then
		if is_machine_entity(entity) then
			new_network_logic.get_network(network_id):add_machine(entity)
		end
		if is_chest_entity(entity) then
			new_network_logic.get_network(network_id):add_chest(entity)
		end
		if entity.name == FLUID_INPUT then
			new_network_logic.get_network(network_id):add_fluid_input(entity)
		end
		if entity.name == FLUID_OUTPUT then
			new_network_logic.get_network(network_id):add_fluid_output(entity)
		end
		if(entity.name == TERMINAL_NAME) then
			new_network_logic.get_network(network_id):add_terminal(entity)
			local terminal_data = storage.terminals[entity.unit_number]
			terminal_data.network_id = network_id
			game.print("Assigned new terminal " .. entity.unit_number .. " to network " .. network_id)
		end
	end
	return false
end

local function build_network(network_id, terminal, visited)
	visited = visited or {}
	storage.networks[network_id].machines = {}
	storage.networks[network_id].chests = {}
	storage.networks[network_id].terminals = {}
	local terminal_connection = storage.connectors and storage.connectors[terminal.unit_number]
	if not terminal_connection then
		game.print("No connector found for terminal " .. terminal.unit_number)
		return
	end

	for _, connector in pairs(terminal_connection) do
		if connector and connector.valid then
			connect_neighbor(network_id, connector)
		end
	end
end

local function rebuild_all_networks(surface_index)
	local network_terminals = {}
	for _, terminal in pairs(storage.terminals) do
		if terminal.network_id and terminal.entity and terminal.entity.valid and terminal.entity.surface.index == surface_index then
			network_terminals[terminal.network_id] = terminal
		end
	end

	for network_id, terminal in pairs(network_terminals) do
		if terminal.entity and terminal.entity.valid then
			if storage.networks[network_id] then
				build_network(network_id, terminal.entity)
			end
		end
	end
end

local function create_connector(entity, x, y)
	 return entity.surface.create_entity{
        name = CONNECTOR_NAME,
        -- name = CABLE_NAME,
        position = {x = x, y = y},
        force = entity.force
    }
end

local function create_connectors(entity)
	local h2 = entity.tile_height/2;
	local w2 = entity.tile_width/2;
	local connectors = {}

	if entity.tile_height == 1 and entity.tile_width == 1 then
		connectors = {
			create_connector(entity, entity.position.x, entity.position.y)
		}
	else
		local top_left = create_connector(entity, entity.position.x - w2, entity.position.y - h2)
		local bottom_right = create_connector(entity, entity.position.x + w2 - 0.5, entity.position.y + h2 - 0.5)
		connectors = {
			top_left,
			bottom_right
		}
	end

    storage.connectors = storage.connectors or {}
    storage.connector_entity = storage.connector_entity or {}
	storage.connectors[entity.unit_number] = connectors

	for _, connector in pairs(connectors) do
		if connector and connector.valid then
			storage.connector_entity[connector.unit_number] = entity
		end
	end
end

local function remove_connectors(entity)
	if storage.connectors and storage.connectors[entity.unit_number] then
		for _, connector in pairs(storage.connectors[entity.unit_number]) do
			storage.connector_entity[connector.unit_number] = nil
			if connector and connector.valid then
				connector.destroy()
			end
		end
		storage.connectors[entity.unit_number] = nil
	end
end

local clear_invalid_entities = function()
	for unit_number, terminal in pairs(storage.terminals) do
		if terminal and terminal.entity and not terminal.entity.valid then
			storage.terminals[unit_number] = nil
		end
	end
	for network_id, network in pairs(storage.networks) do
		for unit_number, machine in pairs(network.machines) do
			if not machine or not machine.valid then
				network.machines[unit_number] = nil
			end
		end
		for unit_number, chest in pairs(network.chests) do
			if not chest or not chest.valid then
				network.chests[unit_number] = nil
			end
		end
		for unit_number, terminal in pairs(network.terminals) do
			if not terminal or not terminal.valid then
				network.terminals[unit_number] = nil
			end
		end
	end

	for network_id, network in pairs(storage.networks) do
		local has_valid_terminal = false
		for unit_number, terminal in pairs(network.terminals) do
			if terminal and terminal.valid then
				has_valid_terminal = true
				break
			end
		end
		if not has_valid_terminal then
			storage.networks[network_id] = nil
			game.print("Removed network " .. network_id .. " due to no valid terminals.")
		end
	end
end

new_network_logic.get_network = function(network_id)
	return new_network_logic.networks[network_id]
end

new_network_logic.get_network_by_terminal = function(terminal_entity)
	for _, terminal in pairs(storage.terminals) do
		if terminal and terminal.entity and terminal.entity == terminal_entity then
			return new_network_logic.networks[terminal.network_id]
		end
	end
	return nil
end

new_network_logic.get_network_by_pipe = function(pipe_entity)
	for _, pipe in pairs(storage.pipes) do
		if pipe and pipe.entity and pipe.entity == pipe_entity then
			return new_network_logic.networks[pipe.network_id]
		end
	end
	return nil
end

new_network_logic.distribute_queue_machines = function(index)
	local queue = new_network_logic.distribute_queue[index] or {}
	for _, entry in pairs(queue) do
		if entry.machine and entry.machine.valid then
			local machine = entry.machine
			local network = entry.network
			local input_inventory = machine.get_inventory(defines.inventory.crafter_input)
			local output_inventory = machine.get_inventory(defines.inventory.crafter_output)
			local fuel_inventory = machine.get_inventory(defines.inventory.fuel)
			local fluidbox = machine.fluidbox
			local recipe, quality = machine.get_recipe()
			local quality = quality and quality.name or "normal"
			if entry.machine.active and recipe and recipe.valid and input_inventory and not input_inventory.is_full() then
				for _, ingredient in pairs(recipe.ingredients) do
					if ingredient.type == "item" then
						local item_name = ingredient.name
						local available_count = network:get_item_count(item_name, quality)
						if available_count > 0 then
							local count_to_move = ingredient.amount * 3
							if count_to_move > 0 then
								network:move_to_inventory({ name = item_name, quality = quality }, count_to_move, machine)
							end
						end
					end
				end
			end

			if entry.machine.active and recipe and recipe.valid and fluidbox then
				for _, ingredient in pairs(recipe.ingredients) do
					if ingredient.type == "fluid" then
						local fluid_name = ingredient.name
						local available_count = network.storage.fluids[fluid_name] and network.storage.fluids[fluid_name][ingredient.temperature] or 0
						if available_count > 0 then
							local count_to_move = ingredient.amount * 3
							if count_to_move > 0 then
								network:insert_fluid_to_inventory(fluid_name, ingredient.temperature, count_to_move, machine)
							end
						end
					end
				end
			end

			if entry.machine.active and recipe and recipe.valid and machine.burner and machine.burner.remaining_burning_fuel <= 100 and fuel_inventory and not fuel_inventory.is_full() then
				for fuel_name, use in pairs(network.storage.use_fuels) do
					if use then
						local available_count = network:get_item_count(fuel_name, "normal")
						if available_count > 0 then
							local count_to_move = 2
							if count_to_move > 0 then
								network:move_to_inventory({ name = fuel_name, quality = "normal" }, count_to_move, machine)
							end
						end
					end
				end
			end

			if fluidbox and recipe and recipe.valid then
				for _, product in pairs(recipe.products) do
					if product.type == "fluid" then
						for i = 1, #fluidbox do
							local fluid = fluidbox[i]
							if fluid and fluid.name == product.name then
								network:insert_fluid(fluid.name, fluid.temperature, fluid.amount)
								fluidbox[i] = nil
							end
						end
					end
				end
			end

			if output_inventory and not output_inventory.is_empty() then
				local contents = output_inventory.get_contents()
				network:insert_items(contents)
				output_inventory.clear()
			end
		end
	end
	new_network_logic.distribute_queue[index] = nil
end

new_network_logic.init_network = function(network_id, network_data)
	init_network_data(network_id, network_data)
	local network_wrapper = {
		storage = storage.networks[network_id],
		id = network_id,
		signals = {},
		add_fluid_input = function(self, fluid_input)
			self.storage.fluid_inputs[fluid_input.unit_number] = fluid_input
		end,
		add_fluid_output = function(self, fluid_output)
			storage.pipes[fluid_output.unit_number] = {
				entity = fluid_output,
				network_id = self.id,
				fluid_name = nil,
			}
			self.storage.fluid_outputs[fluid_output.unit_number] = fluid_output
		end,
		add_machine = function(self, machine)
			self.storage.machines[machine.unit_number] = machine
		end,
		add_chest = function(self, chest)
			self.storage.chests[chest.unit_number] = chest
		end,
		add_terminal = function(self, terminal)
			self.storage.terminals[terminal.unit_number] = terminal
		end,
		insert_item = function(self, item)
			self.storage.items[item.name] = self.storage.items[item.name] or {}
			self.storage.items[item.name][item.quality or "normal"] = (self.storage.items[item.name][item.quality or "normal"] or 0) + item.count
		end,
		remove_item = function (self, name, count, quality)
			if self.storage.items[name] and self.storage.items[name][quality or "normal"] then
				self.storage.items[name][quality or "normal"] = math.max((self.storage.items[name][quality or "normal"] or 0) - count, 0)
			end
		end,
		insert_items = function(self, items)
			for _, item in pairs(items) do
				self:insert_item(item)
			end
		end,
		insert_fluid = function(self, name, temperature, count)
			self.storage.fluids[name] = self.storage.fluids[name] or {}
			self.storage.fluids[name][temperature] = (self.storage.fluids[name][temperature] or 0) + count
		end,
		remove_fluid = function(self, name, temperature, count)
			if self.storage.fluids[name] and self.storage.fluids[name][temperature] then
				self.storage.fluids[name][temperature] = math.max((self.storage.fluids[name][temperature] or 0) - count, 0)
			end
		end,
		distribute_fluids = function(self)
			for unit_number, fluid_input in pairs(self.storage.fluid_inputs) do
				if fluid_input and fluid_input.valid then
					if fluid_input.fluidbox then
						for i = 1, #fluid_input.fluidbox do
							local fluid = fluid_input.fluidbox[i]
							if fluid then
								self:insert_fluid(fluid.name, fluid.temperature, fluid.amount)
								fluid_input.fluidbox[i] = nil
							end
						end
					end
				else
					self.storage.fluid_inputs[unit_number] = nil
				end
			end
			for unit_number, fluid_output in pairs(self.storage.fluid_outputs) do
				if fluid_output and fluid_output.valid then
					if fluid_output.fluidbox then
						local fluid_name = storage.pipes[unit_number] and storage.pipes[unit_number].fluid_name
						local temperature = storage.pipes[unit_number] and storage.pipes[unit_number].temperature
						local capacity = fluid_output.fluidbox.get_capacity(1);

						if fluid_output.fluidbox[1] and fluid_output.fluidbox[1].name ~= fluid_name then
							self:insert_fluid(fluid_output.fluidbox[1].name, fluid_output.fluidbox[1].temperature, fluid_output.fluidbox[1].amount);
							fluid_output.fluidbox[1] = nil
						end

						if fluid_name and self.storage.fluids[fluid_name] and self.storage.fluids[fluid_name][temperature] and self.storage.fluids[fluid_name][temperature] > 0 then
							local amount_to_move = math.min(self.storage.fluids[fluid_name][temperature], capacity - (fluid_output.fluidbox[1] and fluid_output.fluidbox[1].amount or 0))
							fluid_output.fluidbox[1] = { name = fluid_name, amount = (fluid_output.fluidbox[1] and fluid_output.fluidbox[1].amount or 0) + amount_to_move, temperature = temperature }
							self:remove_fluid(fluid_name, temperature, amount_to_move)
						end
					end
				else
					self.storage.fluid_outputs[unit_number] = nil
				end
			end
		end,
		update_signals = function(self)
			self.signals = {}
			for item_name, tiers in pairs(self.storage.items) do
				for tier, count in pairs(tiers) do
					table.insert(self.signals, {
						 value = {
							type = "item",
							name = item_name,
							quality = tier, 
						},
						min = count,
					})
				end
			end
			for fluid_name, temperatures in pairs(self.storage.fluids) do
				for temperature, count in pairs(temperatures) do
					table.insert(self.signals, {
						value = {
							type = "fluid",
							name = fluid_name,
							temperature = temperature,
						},
						min = count,
					})
				end
			end
		end,
		get_item_count = function(self, name, quality)
			return self.storage.items[name] and self.storage.items[name][quality or "normal"] or 0
		end,
		move_to_inventory = function(self, item, count, inventory)
			local item_count_in_network = self.storage.items[item.name] and self.storage.items[item.name][item.quality or "normal"] or 0
			if item_count_in_network < count then
				count = item_count_in_network
			end

			if count == 0 then
				return
			end

			local inserted = inventory.insert({ name = item.name, quality = item.quality, count = count })
			self:remove_item(item.name, inserted, item.quality or "normal")
		end,
		insert_fluid_to_inventory = function(self, name, temperature, count, inventory)
			local fluid_count_in_network = self.storage.fluids[name] and self.storage.fluids[name][temperature] or 0
			if fluid_count_in_network < count then
				count = fluid_count_in_network
			end

			if count == 0 then
				return
			end

			local inserted = inventory.insert_fluid({ name = name, amount = count, temperature = temperature })
			self:remove_fluid(name, temperature, inserted)
		end,
		apply_control_behavior = function(self)
			self:update_signals()
			for unit_number, terminal in pairs(self.storage.terminals) do
				if terminal and terminal.valid then
					local control = terminal.get_or_create_control_behavior()
					if control and control.valid then
						control.get_section(1).filters = self.signals
					end
				end
			end
		end,
		collect_chests = function (self)
			for unit_number, chest in pairs(self.storage.chests) do
				if chest and chest.valid then
					local inventory = chest.get_inventory(defines.inventory.chest)
					if not inventory.is_empty() and inventory.valid then
						local contents = inventory.get_contents()
						self:insert_items(contents)
						inventory.clear()
					end
				else
					self.storage.chests[unit_number] = nil
				end
			end
		end,
		fill_distribute_queue = function(self)
			local machines = self.storage.machines
			local index = 0
			for _, machine in pairs(machines) do 
				local tick = index % 60
				if machine and machine.valid then
					new_network_logic.distribute_queue[tick] = new_network_logic.distribute_queue[tick] or {}
					table.insert(new_network_logic.distribute_queue[tick], {
						machine = machine,
						network = self,
					})
				end

				index = index + 1
			end
		end,
		distribute_items = function(self)
			local machines = self.storage.machines
			for unit_number, machine in pairs(machines) do
				if machine and machine.valid then
					local input_inventory = machine.get_inventory(defines.inventory.crafter_input)
					local recipe, quality = machine.get_recipe()
					local quality = quality and quality.name or "normal"
					if recipe and recipe.valid and input_inventory and not input_inventory.is_full() then
						for _, ingredient in pairs(recipe.ingredients) do
							local item_name = ingredient.name
							local available_count = self:get_item_count(item_name, quality)
							if available_count > 0 then
								local count_to_move = 10
								if count_to_move > 0 then
									self:move_to_inventory({ name = item_name, quality = quality }, count_to_move, machine)
								end
							end
						end
					end
				else
					self.storage.machines[unit_number] = nil
				end
			end
		end,
	}
	new_network_logic.networks[network_id] = network_wrapper
end

new_network_logic.collect_chests = function()
	for network_id, network in pairs(new_network_logic.networks) do
		network:collect_chests()
	end
end

new_network_logic.distribute_items = function()
	for network_id, network in pairs(new_network_logic.networks) do
		network:distribute_items()
	end
end

new_network_logic.fill_distribute_queue = function()
	for network_id, network in pairs(new_network_logic.networks) do
		network:fill_distribute_queue()
	end
end

new_network_logic.distribute_fluids = function()
	for network_id, network in pairs(new_network_logic.networks) do
		network:distribute_fluids()
	end
end

new_network_logic.handle_tick = function()
	ensure_storage()

	if(not new_network_logic.initialized) then
		new_network_logic.init()
		new_network_logic.initialized = true
	end

	local current_tick = game.tick
	local has_changed = false
	for surface_index, changed in pairs(storage.network_changed) do
		if changed then
			has_changed = true
			storage.rebuild_delay = storage.rebuild_delay - 1
			if storage.rebuild_delay <= 0 then
				rebuild_all_networks(surface_index)
				storage.network_changed[surface_index] = false
				storage.rebuild_delay = 0
			end
		end
	end

	if not has_changed and current_tick % 60 == 0 then
		for index, terminal in pairs(storage.terminals) do
			if(not terminal.network_id) then
				local new_id = get_next_network_id()
				new_network_logic.init_network(new_id)
				terminal.network_id = new_id
				build_network(new_id, terminal.entity)
				game.print("Assigned new network ID " .. new_id .. " to terminal " .. index)
			end
		end
	end

	if current_tick % 60 == 0 then
		for _, network in pairs(new_network_logic.networks) do
			network:apply_control_behavior()
		end
	end

	new_network_logic.distribute_queue_machines(current_tick % 60)

	if(current_tick % 60 == 0) then
		new_network_logic.fill_distribute_queue()
	end

	if(current_tick % 120 == 0) then
		new_network_logic.collect_chests()
		new_network_logic.distribute_fluids()
	end
end

new_network_logic.is_terminal = function(entity)
	return entity and entity.valid and entity.name == TERMINAL_NAME
end

new_network_logic.init = function()
	ensure_storage()
	clear_invalid_entities()
	for network_id, network in pairs(storage.networks) do
		new_network_logic.init_network(network_id, network)
	end
	storage.connectors =  {}
    storage.connector_entity = {}
	for _, surface in pairs(game.surfaces) do
		for _, entity in pairs(surface.find_entities_filtered{ name = { CONNECTOR_NAME } }) do
			entity.destroy()
		end
		for _, entity in pairs(surface.find_entities_filtered{ name = { TERMINAL_NAME, BUFFER_CHEST_NAME, FLUID_INPUT, FLUID_OUTPUT } }) do
			create_connectors(entity)
		end
		for _, entity in pairs(surface.find_entities_filtered{ type = MACHINE_TYPES }) do
			create_connectors(entity)
		end
		for _, entity in pairs(surface.find_entities_filtered{ type = ABSORBABLE_CHEST_TYPES }) do
			create_connectors(entity)
		end
	end

	game.print("Network runtime initialized with " .. table_size(storage.networks) .. " networks.")
end

new_network_logic.handle_entity_build = function(event)
	ensure_storage()
	local entity = get_entity_from_event(event)

	if entity.name == FLUID_INPUT or entity.name == FLUID_OUTPUT then
		create_connectors(entity)
		if not try_attach_to_network(entity) then
			emit_changes(entity.surface.index)
		end
		return
	end

	if(entity.name == CABLE_NAME) then
		storage.cables[entity.unit_number] = {
			entity = entity,
			network_id = nil,
		}
		emit_changes(entity.surface.index)
	end

	if(is_topology_entity(entity)) then
		create_connectors(entity)
		if(entity.name == TERMINAL_NAME) then
			local data = {
				entity = entity,
				network_id = nil,
			}
			storage.terminals[entity.unit_number] = data
		end
		if not try_attach_to_network(entity) then
			emit_changes(entity.surface.index)
		end
	end

	if is_machine_entity(entity) then
		create_connectors(entity)
		if not try_attach_to_network(entity) then
			emit_changes(entity.surface.index)
		end
	end

	if is_chest_entity(entity) then
		create_connectors(entity)
		if not try_attach_to_network(entity) then
			emit_changes(entity.surface.index)
		end
	end
end

new_network_logic.handle_entity_mining = function(event)
	ensure_storage()
	local entity = get_entity_from_event(event)

	if entity.name == FLUID_INPUT or entity.name == FLUID_OUTPUT then
		emit_changes(entity.surface.index)
	end

	if(entity.name == CABLE_NAME) then
		storage.cables[entity.unit_number] = nil
		emit_changes(entity.surface.index)
	end

	if(is_topology_entity(entity)) then
		remove_connectors(entity)
		if(entity.name == TERMINAL_NAME) then
			storage.terminals[entity.unit_number] = nil
		end
		emit_changes(entity.surface.index)
	end

	if(is_machine_entity(entity)) then
		remove_connectors(entity)
		emit_changes(entity.surface.index)
	end

	if(is_chest_entity(entity)) then
		remove_connectors(entity)
		emit_changes(entity.surface.index)
	end
end

return new_network_logic;