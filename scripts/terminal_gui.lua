local Gui = Gridorius.Gui
Gui:AddStylesheet({
	spacing_5 = {
		horizontal_spacing = 5,
		vertical_spacing = 5,
	}
})

local TerminalGui = {}

function TerminalGui.render_fuels(player, table)
	table.clear()
	local current_network = Gridorius.state:get_player(player.index, "network")

	if not current_network then return end
	local fuel_items = {}
	for name, item in pairs(prototypes.item) do
		if item.fuel_value and item.fuel_value > 0 then
			fuel_items[name] = item
		end
	end

	for fuel_name, _ in pairs(fuel_items) do
		local fuel_item = prototypes.item[fuel_name]
		if fuel_item and fuel_item.fuel_value and fuel_item.fuel_value > 0 then
			local use = current_network.storage.use_fuels[fuel_name] or false
			Gui:CreateSpriteButton(fuel_name, "item/" .. fuel_name, {
				tags = {
					type = 'fuel',
					fuel_name = fuel_name,
				},
				toggle_mode = true,
				toggled = use,
			}):AfterCreate(function(element)
				element.style.size = 40
			end):RenderElement(player, table)
		end
	end
end

function TerminalGui.render_groups(player, table)
	table.clear()
	local selected_group = Gridorius.state:get_player(player.index, "current_group")
	for name, group in pairs(prototypes.item_group) do
		if not selected_group then
			selected_group = name
			Gridorius.state:set_player(player.index, "current_group", name)
		end
		Gui:CreateSpriteButton(name, "item-group/" .. name, {
			tags = {
				type = 'item_group',
				group_name = name,
			},
			toggle_mode = true,
			toggled = selected_group == name,
			tooltip = group.localised_name,
			style = 'filter_group_button_tab_slightly_larger'
		}):AfterCreate(function(element)
			element.enabled = true
		end):RenderElement(player, table)
	end
end

function TerminalGui.add_empty_buttons(index, table)
	local count = 10 - index % 10
	if count < 10 then
		for _ = 1, 10 - index % 10 do
			local bt = table.add { type = 'sprite-button' }
			bt.enabled = false
			bt.style = 'slot_button'
		end
	end
end

function TerminalGui.render_quality_pack(network, player, current_group_items, quality, items_table)
	for _, subgroup_items in pairs(current_group_items) do
		local index = 0
		for _, item in pairs(subgroup_items) do
			if network.inventory.items[item.name] and network.inventory.items[item.name][quality] ~= nil then
				index = index + 1
				Gui:CreateSpriteButton(item.name .. ":" .. quality, "item/" .. item.name, {
					tags = {
						type = 'item',
						item_name = item.name,
						quality = quality,
					},
					quality = quality,
					number = network.inventory.items[item.name][quality],
					elem_tooltip = {
						type = quality == "normal" and 'item' or 'item-with-quality',
						name = item.name,
						quality = quality,
					}
				}):AfterCreate(function(element)
					element.style.size = 40
				end):RenderElement(player, items_table)
			end
		end
		if index > 0 then
			TerminalGui.add_empty_buttons(index, items_table)
		end
	end
end

function TerminalGui.render_fluids(network, fluids, player, table)
	for fluid_name, fluid in pairs(fluids) do
		if network.inventory.fluids[fluid_name] then
			for temperature, amount in pairs(network.inventory.fluids[fluid_name]) do
				Gui:CreateSpriteButton(fluid_name .. ":" .. temperature, "fluid/" .. fluid_name, {
					tags = {
						type = 'fluid',
						item_name = fluid_name,
						temperature = temperature,
					},
					number = amount,
					tooltip = { "", { "fluid-name." .. fluid_name }, temperature .. "°C" }
				}):AfterCreate(function(element)
					element.style.size = 40
				end):RenderElement(player, table)
			end
		end
	end
end

function TerminalGui.render_group_data(player, data_table)
	data_table.clear()
	local current_network = Gridorius.state:get_player(player.index, "network")
	if not current_network then return end
	local items = prototypes.item;
	local fluids = prototypes.fluid;
	local tiers = prototypes.quality;
	local current_group = Gridorius.state:get_player(player.index, "current_group")

	if (current_group == "fluids") then
		TerminalGui.render_fluids(current_network, fluids, player, data_table)
		return
	end

	local current_group_items = {}
	for name, item in pairs(items) do
		if item.group.name == current_group then
			if not current_group_items[item.subgroup.name] then
				current_group_items[item.subgroup.name] = {}
			end
			table.insert(current_group_items[item.subgroup.name], item)
		end
	end

	if not tiers then
		TerminalGui.render_quality_pack(current_network, player, current_group_items, "normal", data_table)
		return
	end
	for quality, _ in pairs(tiers) do
		TerminalGui.render_quality_pack(current_network, player, current_group_items, quality, data_table)
	end
end

function TerminalGui.render_machines(player, table)
	local current_network = Gridorius.state:get_player(player.index, "network")
	if not current_network then return end

	local entity_summary = {}
	for _, entity_data in pairs(current_network.entities) do
		local entity = entity_data.entity
		if entity.valid then
			if not entity_summary[entity.name] then
				entity_summary[entity.name] = {
					sprite = "item/" .. entity.name,
					name = entity.name,
					number = 1
				}
			else
				entity_summary[entity.name].number = entity_summary[entity.name].number + 1
			end
		end
	end

	for _, sum in pairs(entity_summary) do
		Gui:CreateSpriteButton(sum.name, sum.sprite, {
			number = sum.number
		}):RenderElement(player, table)
	end
end

function TerminalGui.render_fluid_selector(network, player, table)
	table.clear()
	local current_pipe = Gridorius.state:get_player(player.index, "current_pipe")
	if not current_pipe then return end
	local pipe_data = network:GetEntityData(current_pipe)
	if not pipe_data then return end

	for fluid_name, temperatures in pairs(network.inventory.fluids) do
		for temperature, _ in pairs(temperatures) do
			Gui:CreateSpriteButton(fluid_name .. ":" .. temperature, "fluid/" .. fluid_name, {
				tags = {
					type = 'select_pipe_fluid',
					fluid = fluid_name,
					temperature = temperature,
				},
				number = temperature,
				tooltip = { "", { "fluid-name." .. fluid_name }, temperature .. "°C" },
				toggle_mode = true,
			}):AfterCreate(function(element)
				element.style.size = 40
				if pipe_data.fluid_name == fluid_name and pipe_data.temperature == temperature then
					element.toggled = true
				end
			end):RenderElement(player, table)
		end
	end
end

Gui:on_tagged_click(function(tags, event)
	local player = game.get_player(event.player_index)
	local current_network = Gridorius.state:get_player(event.player_index, "network")
	local element = event.element
	if not current_network or not player then return end

	if tags.type == "item_group" then
		Gridorius.state:set_player(player.index, "current_group", tags.group_name)
		local group_table = player.gui.screen.terminal_frame.content.left.group_table
		TerminalGui.render_groups(player, group_table)
		local items_table = player.gui.screen.terminal_frame.content.left.items_scroll.items_table
		TerminalGui.render_group_data(player, items_table)
	elseif tags.type == "fuel" then
		local use_fuels = current_network.storage.use_fuels
		use_fuels[tags.fuel_name] = not use_fuels[tags.fuel_name]
		local fuel_table = player.gui.screen.terminal_frame.content.right.fuel_table
		TerminalGui.render_fuels(player, fuel_table)
	elseif tags.type == "item" then
		local item_name = element.tags.item_name
		local quality = element.tags.quality
		local item_stack_size = prototypes.item[item_name].stack_size

		local count = math.floor(item_stack_size / 2)
		if (event.shift) then
			count = item_stack_size
		end

		if current_network.inventory:GetItemCount(item_name, quality) > 0 then
			current_network.inventory:MoveToInventory({ name = item_name, quality = quality }, count, player)
			TerminalGui.render_group_data(player, player.gui.screen.terminal_frame.content.left.items_scroll.items_table)
		end
	elseif tags.type == "select_pipe_fluid" then
		local current_pipe = Gridorius.state:get_player(player.index, "current_pipe")
		local fluid_name = element.tags.fluid
		local temperature = element.tags.temperature

		local pipe_data = current_network.entities[current_pipe.unit_number]
		if pipe_data then
			pipe_data.fluid = fluid_name
			pipe_data.temperature = temperature
		end

		storage.network_entities[current_pipe.unit_number].fluid_name = fluid_name
		storage.network_entities[current_pipe.unit_number].temperature = temperature
		local pipe_table = player.gui.screen.fluid_output_frame.fluids_table
		TerminalGui.render_fluid_selector(current_network, player, pipe_table)
	end
end)

function TerminalGui.BindInterfaces()
	local network_system = Gridorius.state:get("network_system")
	local terminal_interface = Gui:CreateDefaultFrame("terminal_frame", "Терминал сети")
		:AppendChild(
			Gui:CreateFlow("content")
			:AppendChildrens(
				Gui:CreateFlow("left", "vertical")
				:AppendChildrens(
					Gui:CreateTable("group_table", 6, {
						style = "editor_mode_selection_table"
					})
					:AfterCreate(function(table, player)
						TerminalGui.render_groups(player, table)
					end),
					Gui:CreateScroll("items_scroll")
					:AfterCreate(function(scroll)
						scroll.style.height = 500
					end)
					:AppendChild(
						Gui:CreateTable("items_table", 10)
						:SetClasses("spacing_5")
						:AfterCreate(function(table, player)
							TerminalGui.render_group_data(player, table)
						end)
					)
				),
				Gui:CreateSpace(10, "vertical"),
				Gui:CreateFlow("right", "vertical")
				:AppendChildrens(
					Gui:CreateLabel(function(player)
						local network = Gridorius.state:get_player(player.index, "network")
						return "Сеть: " .. network.id
					end),
					Gui:CreateLabel(function(player)
						local network = Gridorius.state:get_player(player.index, "network")
						return "Тиков на полную обработку: " .. network.storage.distribute_index
					end),
					Gui:CreateLabel("Сущности в сети"),
					Gui:CreateTable("machines_table", 5)
					:SetClasses("spacing_5")
					:AfterCreate(function(table, player)
						TerminalGui.render_machines(player, table)
					end),
					Gui:CreateLabel("Использовать  топливо"),
					Gui:CreateTable("fuel_table", 5)
					:SetClasses("spacing_5")
					:AfterCreate(function(table, player)
						TerminalGui.render_fuels(player, table)
					end)
				)
			)
		)

	local pipe_interface =
		Gui:CreateDefaultFrame("fluid_output_frame", "Вывод жидкости")
		:AppendChildrens(
			Gui:CreateTable("fluids_table", 10)
			:SetClasses("spacing_5")
			:AfterCreate(function(table, player)
				local network = Gridorius.state:get_player(player.index, "network")
				if network then
					TerminalGui.render_fluid_selector(network, player, table)
				end
			end)
		)


	Gui:BindInterface("network-terminal", terminal_interface, function(player, entity)
		local network = network_system:GetNetworkByEntity(entity)
		if network then
			Gridorius.state:set_player(player.index, "network", network)
			return player.gui.screen
		end
		return nil
	end, true)


	Gui:BindInterface("network-fluid-output", pipe_interface, function(player, entity)
		local network = network_system:GetNetworkByEntity(entity)
		if network then
			Gridorius.state:set_player(player.index, "network", network)
			Gridorius.state:set_player(player.index, "current_pipe", entity)
			return player.gui.screen
		end
		return nil
	end, true)
end

return TerminalGui
