local Gui = Gridorius.Gui
local Constants = require("scripts.constants")
Gui:AddStylesheet({
	spacing_5 = {
		horizontal_spacing = 5,
		vertical_spacing = 5,
	},
	fluid_sprite_button = {
		font_color = { r = 255, g = 255, b = 255 },
		font = "default-bold",
		font_size = 14,
	},
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
				elem_tooltip = {
					name = fuel_name,
					type = 'item',
				},
				toggle_mode = true,
				toggled = use,
			}):AfterCreate(function(element)
				element.style.size = 40
			end):RenderElement(player, table)
		end
	end
end

function TerminalGui.render_ammo(player, ammo_table)
	ammo_table.clear()
	local current_network = Gridorius.state:get_player(player.index, "network")

	if not current_network then return end
	local used_categories = {}

	for name, prototype in pairs(prototypes.entity) do
		if Constants.SUPPORTED_TURRET_TYPES[prototype.type] then
			local ammo_categories = prototype.attack_parameters and prototype.attack_parameters.ammo_categories
			if ammo_categories then
				for _, ammo_category in pairs(ammo_categories) do
					used_categories[ammo_category] = true
				end
			end
		end
	end

	local ammo_items = {}

	for _, item in pairs(prototypes.item) do
		if item.ammo_category and used_categories[item.ammo_category.name] then
			ammo_items[item.name] = item
		end
	end

	for ammo_name, ammo_item in pairs(ammo_items) do
		local use = current_network.storage.use_ammo[ammo_name] or false
		Gui:CreateSpriteButton(ammo_name, "item/" .. ammo_name, {
			tags = {
				type = 'ammo',
				ammo_name = ammo_name,
			},
			toggle_mode = true,
			elem_tooltip = {
				name = ammo_name,
				type = 'item',
			},
			toggled = use,
		}):AfterCreate(function(element)
			element.style.size = 40
		end):RenderElement(player, ammo_table)
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
	if count <= 10 then
		for _ = 1, 10 - index % 10 do
			local button = table.add { type = 'button' }
			button.style.size = 30
			button.enabled = false
			button.style.margin = 5
		end
	end
end

function TerminalGui.render_quality_pack(network, player, current_group_items, quality, items_table, row_index)
	for _, subgroup_items in pairs(current_group_items) do
		local cell_index = 0
		for _, item in pairs(subgroup_items) do
			if network.inventory.items[item.name] and network.inventory.items[item.name][quality] ~= nil
				and network.inventory.items[item.name][quality] > 0
			then
				cell_index = cell_index + 1
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
					},
					style = "slot_button",
				}):AfterCreate(function(element)
					element.style.size = 40
				end):RenderElement(player, items_table)
			end
		end
		if cell_index > 0 then
			row_index = row_index + 1
			TerminalGui.add_empty_buttons(cell_index, items_table)
		end
	end
	return row_index
end

function TerminalGui.render_fluids(network, fluids, player, table)
	for fluid_name, fluid in pairs(fluids) do
		if network.inventory.fluids[fluid_name] then
			for temperature, amount in pairs(network.inventory.fluids[fluid_name]) do
				if amount > 0 and temperature ~= "default_temperature" then
					local caption = temperature == "default" and "" or "[color=white]" .. temperature .. "°C[/color]"
					local tooltip = temperature == "default" and { "fluid-name." .. fluid_name } or
						{ "", { "fluid-name." .. fluid_name }, " " .. temperature .. "°C" }
					Gui:CreateSpriteButton(fluid_name .. ":" .. temperature, "fluid/" .. fluid_name, {
						tags = {
							type = 'fluid',
							item_name = fluid_name,
							temperature = temperature,
						},
						number = amount,
						caption = caption,
						tooltip = tooltip,
						style = "slot_button",
					})
						:AfterCreate(function(element)
							element.style.size = 40
						end):RenderElement(player, table)
				end
			end
		end
	end
end

function TerminalGui.render_group_data(player, data_table)
	data_table.clear()
	local search_text = Gridorius.state:get_player(player.index, "search_text")
	local current_network = Gridorius.state:get_player(player.index, "network")
	if not current_network then return end
	local items = prototypes.item;
	local fluids = prototypes.fluid;
	local tiers = prototypes.quality;
	local current_group = Gridorius.state:get_player(player.index, "current_group")

	if (current_group == "fluids") then
		if search_text and search_text ~= "" then
			fluids = {}
			for name, fluid in pairs(prototypes.fluid) do
				local translation = Gridorius.GetTranslation(player, fluid.name)
				if translation:find(search_text) then
					fluids[name] = fluid
				end
			end
		end

		TerminalGui.render_fluids(current_network, fluids, player, data_table)
		return
	end

	local current_group_items = {}
	for name, item in pairs(items) do
		if item.group.name == current_group then
			if search_text and search_text ~= "" and not string.find(Gridorius.GetTranslation(player, item.name), search_text) then
				goto continue
			end
			if not current_group_items[item.subgroup.name] then
				current_group_items[item.subgroup.name] = {}
			end
			table.insert(current_group_items[item.subgroup.name], item)
			::continue::
		end
	end

	local row_index = 0
	if not tiers then
		row_index = TerminalGui.render_quality_pack(current_network, player, current_group_items, "normal", data_table,
			row_index)
		return
	end
	for quality, _ in pairs(tiers) do
		row_index = TerminalGui.render_quality_pack(current_network, player, current_group_items, quality, data_table,
			row_index)
	end

	if row_index < 10 then
		for _ = 1, 10 - row_index do
			TerminalGui.add_empty_buttons(0, data_table)
		end
	end
end

function TerminalGui.render_machines(player, table)
	table.clear()
	local current_network = Gridorius.state:get_player(player.index, "network")
	if not current_network then return end

	local entity_summary = {}
	for _, entity_data in pairs(current_network.entities) do
		local entity = entity_data.entity
		if entity.valid and prototypes.item[entity.name] then
			if not entity_summary[entity.name] then
				entity_summary[entity.name] = {
					sprite = "item/" .. entity.name,
					name = entity.name,
					number = 1,
				}
			else
				entity_summary[entity.name].number = entity_summary[entity.name].number + 1
			end
		end
	end

	for _, sum in pairs(entity_summary) do
		Gui:CreateSpriteButton(sum.name, sum.sprite, {
			number = sum.number,
			elem_tooltip = {
				name = sum.name,
				type = 'item',
			},
		}):RenderElement(player, table)
	end
end

function TerminalGui.render_fluid_selector(network, player, table)
	table.clear()
	local current_pipe = Gridorius.state:get_player(player.index, "current_pipe")
	if not current_pipe then return end
	local pipe_data = Gridorius.GetMetadata(current_pipe, {
		fluid_name = nil,
		temperature = nil,
	})
	if not pipe_data then return end

	for fluid_name, temperatures in pairs(network.inventory.fluids) do
		for temperature, amount in pairs(temperatures) do
			if temperature ~= "default_temperature" and amount > 0 then
				local name = fluid_name
				local is_default = temperature == "default"
				local tooltip = { "fluid-name." .. fluid_name }
				if not is_default then
					tooltip = { "", tooltip, " " .. temperature .. "°C" }
					name = name .. ":" .. temperature
				end
				Gui:CreateSpriteButton(name, "fluid/" .. fluid_name, {
					tags = {
						type = 'select_pipe_fluid',
						fluid = fluid_name,
						temperature = temperature,
					},
					tooltip = tooltip,
					toggle_mode = true,
				}):AfterCreate(function(element)
					if not is_default then
						element.number = temperature
					end
					element.style.size = 40
					if pipe_data.fluid_name == fluid_name and pipe_data.temperature == temperature then
						element.toggled = true
					end
				end):RenderElement(player, table)
			end
		end
	end
end

Gridorius.Events:OnClick(function(event)
	local element = event.element
	if element and element.valid then
		if element.name == 'add_production_item' then
			local production_scroll = element.parent.production_scroll
			local current_production_combinator = Gridorius.state:get_player(event.player_index,
				"current_production_combinator")
			if not current_production_combinator then return end
			local settings = Gridorius.GetMetadata(current_production_combinator, {
				production = {}
			})
			if not settings then return end
			table.insert(settings.production, {
				item = nil,
				quality = nil,
				limit = 10,
			})
			TerminalGui.RenderProductionScroll(game.get_player(event.player_index), production_scroll)
		end

		local network = Gridorius.state:get_player(event.player_index, "network")
		if not network then return end
	end
end)

Gridorius.Events:OnTaggedClick(function(tags, event)
	local player = game.get_player(event.player_index)
	local element = event.element

	if tags.type == 'delete_production_item' then
		local combinator = Gridorius.state:get_player(event.player_index, "current_production_combinator")
		local combinator_settings = Gridorius.GetMetadata(combinator, {
			production = {}
		})
		if not combinator or not combinator_settings then return end

		local index = tags.index
		local parent_flow = element.parent
		local scroll = parent_flow.parent
		local line = scroll.children[parent_flow.get_index_in_parent() + 1]
		parent_flow.destroy()
		line.destroy()
		combinator_settings.production[index] = nil
	end

	local current_network = Gridorius.state:get_player(event.player_index, "network")
	if not current_network or not player then return end

	if tags.type == "item_group" then
		Gridorius.state:set_player(player.index, "current_group", tags.group_name)
		local group_table = player.gui.screen.terminal_frame.content.center.group_table
		TerminalGui.render_groups(player, group_table)
		local items_table = player.gui.screen.terminal_frame.content.center.items_scroll.items_table
		TerminalGui.render_group_data(player, items_table)
	elseif tags.type == "fuel" then
		local use_fuels = current_network.storage.use_fuels
		use_fuels[tags.fuel_name] = not use_fuels[tags.fuel_name]
		local fuel_table = player.gui.screen.terminal_frame.content.right.fuel_scroll.fuel_table
		TerminalGui.render_fuels(player, fuel_table)
	elseif tags.type == 'ammo' then
		local use_ammo = current_network.storage.use_ammo
		use_ammo[tags.ammo_name] = not use_ammo[tags.ammo_name]
		local ammo_table = player.gui.screen.terminal_frame.content.right.ammo_scroll.ammo_table
		TerminalGui.render_ammo(player, ammo_table)
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
			TerminalGui.render_group_data(player,
				player.gui.screen.terminal_frame.content.center.items_scroll.items_table)
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

		Gridorius.SetMetadata(current_pipe, {
			fluid_name = fluid_name,
			temperature = temperature,
		})
		local pipe_table = player.gui.screen.fluid_output_frame.fluids_scroll.fluids_table
		TerminalGui.render_fluid_selector(current_network, player, pipe_table)
	elseif tags.type == 'delete_limit_item' then
		local index = tags.index
		local parent_flow = element.parent
		local scroll = parent_flow.parent
		local line = scroll.children[parent_flow.get_index_in_parent() + 1]
		parent_flow.destroy()
		line.destroy()
		current_network.storage.item_limits[index] = nil
	end
end)

function TerminalGui.CreateCell(chose_type, item_production, index)
	local elem_value = nil
	if item_production.item then
		if chose_type == "item-with-quality" then
			elem_value = {
				name = item_production.item,
				quality = item_production.quality
			}
		else
			elem_value = item_production.item
		end
	end

	return Gui:CreateFlow("flow_production_" .. index)
		:AppendChildrens(
			Gui:CreateChoseElemButton('select_production_' .. index, chose_type, {
				tags = {
					type = 'select_production_item',
					index = index,
				},
			})
			:AfterCreate(function(button)
				button.elem_value = elem_value
			end),
			Gui:CreateTextField('text_field_' .. index, 200, {
				numeric = true,
				allow_negative = false,
				allow_decimal = false,
				tags = {
					type = 'value_production_item',
					index = index,
				},
			})
			:AfterCreate(function(text_field)
				text_field.style.height = 40
				text_field.style.width = 150
				text_field.text = tostring(item_production.limit)
			end),
			Gui:CreateSpriteButton('delete_production_' .. index, 'utility/trash', {
				style = "red_button",
				tags = {
					type = 'delete_production_item',
					index = index,
				},
			})
			:AfterCreate(function(button)
				button.style.size = 40
			end)
		)
end

function TerminalGui.CreateProductionRow(item_production, index)
	local chose_type = "item";
	if prototypes.quality then
		chose_type = "item-with-quality"
	end
	return
		TerminalGui.CreateCell(chose_type, item_production, index),
		Gui:CreateLine()
end

function TerminalGui.RenderItemLimitsScroll(player, scroll, search)
	scroll.clear()
	local network = Gridorius.state:get_player(player.index, "network")
	if not network then return end

	if not search or search == "" then
		for i, item_limit in pairs(network.storage.item_limits) do
			local flow, line = TerminalGui.CreateLimitRow(item_limit, i)
			Gui:RenderElements(player, scroll, flow, line)
		end
	else
		for i, item_limit in pairs(network.storage.item_limits) do
			if item_limit.item and prototypes.item[item_limit.item] then
				local translation = Gridorius.GetTranslation(player, item_limit.item)
				if translation:find(search) then
					local flow, line = TerminalGui.CreateLimitRow(item_limit, i)
					Gui:RenderElements(player, scroll, flow, line)
				end
			end
		end
	end
end

function TerminalGui.RenderProductionScroll(player, scroll, search)
	scroll.clear()
	local combinator = Gridorius.state:get_player(player.index, "current_production_combinator")
	local combinator_settings = Gridorius.GetMetadata(combinator, {
		production = {}
	})
	if not combinator or not combinator_settings then return end

	if not search or search == "" then
		for i, item_production in pairs(combinator_settings.production) do
			local flow, line = TerminalGui.CreateProductionRow(item_production, i)
			Gui:RenderElements(player, scroll, flow, line)
		end
	else
		for i, item_production in pairs(combinator_settings.production) do
			if item_production.item and prototypes.item[item_production.item] then
				local translation = Gridorius.GetTranslation(player, item_production.item)
				if translation:find(search) then
					local flow, line = TerminalGui.CreateProductionRow(item_production, i)
					Gui:RenderElements(player, scroll, flow, line)
				end
			end
		end
	end
end

function TerminalGui.BindInterfaces()
	local network_system = Gridorius.state:get("network_system")
	local right_flow = Gui:CreateFlow("right", "vertical")
		:AfterCreateChilds(function(flow, player)
			if settings.global.fill_turret_ammo.value then
				Gui:RenderElements(
					player, flow,
					Gui:CreateLabel({ "gui.items-network-use-ammo" }),
					Gui:CreateScroll("ammo_scroll")
					:AfterCreate(function(scroll, player)
						scroll.style.maximal_height = 300
						scroll.style.width = 450
					end)
					:AppendChild(
						Gui:CreateTable("ammo_table", 10)
						:SetClasses("spacing_5")
						:AfterCreate(function(table, player)
							TerminalGui.render_ammo(player, table)
						end)
					)
				)
			end
		end)
		:AppendChildrens(
			Gui:CreateLabel(function(player)
				local network = Gridorius.state:get_player(player.index, "network")
				return { "gui.items-network-terminal-network-value", network.id }
			end),
			Gui:CreateLabel(function(player)
				local network = Gridorius.state:get_player(player.index, "network")
				return {
					"",
					{ "gui.items-network-terminal-status" },
					" ",
					network.working and "[color=green]" or "[color=red]",
					network.working and { "gui.items-network-terminal-status-working" } or
					{ "gui.items-network-terminal-status-no-power" },
					"[/color]",
				}
			end),
			Gui:CreateLabel(function(player)
				local network = Gridorius.state:get_player(player.index, "network")
				return { "gui.items-network-full-processing-ticks", network.storage.distribute_index }
			end),
			Gui:CreateLabel({ "gui.items-network-network-entities" }),
			Gui:CreateTable("machines_table", 10)
			:SetClasses("spacing_5")
			:AfterCreate(function(table, player)
				TerminalGui.render_machines(player, table)
			end),
			Gui:CreateLabel({ "gui.items-network-use-fuel" }),
			Gui:CreateScroll("fuel_scroll")
			:AfterCreate(function(scroll, player)
				scroll.style.maximal_height = 300
				scroll.style.width = 450
			end)
			:AppendChild(
				Gui:CreateTable("fuel_table", 10)
				:SetClasses("spacing_5")
				:AfterCreate(function(table, player)
					TerminalGui.render_fuels(player, table)
				end)
			)
		)


	local production_combinator_interface = Gui:CreateDefaultFrame("production_combinator_frame",
			{ "gui.items-network-production-window-title" })
		:AppendChild(
			Gui:CreateFlow("production_combinator_content", 'vertical')
			:AppendChildrens(
				Gui:CreateLabel({ "gui.items-network-production-settings" }),
				Gui:CreateButton("add_production_item", { "gui.items-network-add" }),
				Gui:CreateTextField("search_production_item", "", {
					placeholder = { "gui.items-network-search-by-name" },
				}):AfterCreate(function(text_field)
					text_field.style.width = 250
				end),
				Gui:CreateScroll("production_scroll")
				:AfterCreate(function(scroll, player)
					scroll.style.height = 550
					scroll.style.width = 300
					TerminalGui.RenderProductionScroll(player, scroll)
				end)

			)
		)

	local terminal_interface = Gui:CreateDefaultFrame("terminal_frame", { "gui.items-network-terminal-title" })
		:AppendChild(
			Gui:CreateFlow("content")
			:AppendChildrens(
			-- Gui:CreateFlow("left", "vertical")
			-- :AppendChildrens(
			-- 	Gui:CreateTabPane("action_tabs", {
			-- 		{
			-- 			name = "limits",
			-- 			title = "Ограничения сети",
			-- 			render = function(content, player)
			-- 				Gui:CreateButton("add_item_limit_button", "Добавить")
			-- 					:RenderElement(player, content)
			-- 				Gui:CreateTextField("search_limit", "", {
			-- 					placeholder = "Поиск по названию",
			-- 				}):AfterCreate(function(text_field)
			-- 					text_field.style.width = 250
			-- 				end):RenderElement(player, content)
			-- 				local scroll = Gui:CreateScroll("limits_scroll")
			-- 					:AfterCreate(function(scroll)
			-- 						scroll.style.height = 550
			-- 						scroll.style.width = 300
			-- 						TerminalGui.RenderItemLimitsScroll(player, scroll)
			-- 					end)

			-- 				scroll:RenderRoot(player, content)
			-- 			end
			-- 		}
			-- 	})
			-- ),
				Gui:CreateFrame("center", {
					style = "entity_frame",
				})
				:AppendChildrens(
					Gui:CreateTextField("search_item", "", {
						placeholder = { "gui.items-network-search-by-name" },
					}):AfterCreate(function(text_field)
						text_field.style.width = 250
					end),
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
				right_flow
			)
		)

	local pipe_interface =
		Gui:CreateDefaultFrame("fluid_output_frame", { "gui.items-network-fluid-output-window-title" })
		:AppendChildrens(
			Gui:CreateScroll("fluids_scroll")
			:AfterCreate(function(scroll)
				scroll.style.maximal_height = 400
			end)
			:AppendChild(
				Gui:CreateTable("fluids_table", 10)
				:SetClasses("spacing_5")
				:AfterCreate(function(table, player)
					local network = Gridorius.state:get_player(player.index, "network")
					if network then
						TerminalGui.render_fluid_selector(network, player, table)
					end
				end)
			)
		)

	terminal_interface:OnClose(function(player)
		Gridorius.state:set_player(player.index, "search_text", nil)
	end)
	Gui:BindEntityInterface("network-terminal", terminal_interface, function(player, entity)
		local network = network_system:GetNetworkByEntity(entity)
		if network then
			Gridorius.state:set_player(player.index, "network", network)
			return player.gui.screen
		end
		return nil
	end, true)

	Gui:BindEntityInterface("network-production-combinator", production_combinator_interface, function(player, entity)
		Gridorius.state:set_player(player.index, "current_production_combinator", entity)
		return player.gui.screen
	end, true)

	Gui:BindEntityInterface("network-fluid-output", pipe_interface, function(player, entity)
		local network = network_system:GetNetworkByEntity(entity)
		if network then
			Gridorius.state:set_player(player.index, "network", network)
			Gridorius.state:set_player(player.index, "current_pipe", entity)
			return player.gui.screen
		end
		return nil
	end, true)

	Gridorius.Events:On(defines.events.on_gui_elem_changed, function(event)
		local element = event.element
		local tags = element.tags

		if tags then
			if tags.type == 'select_production_item' then
				local combinator = Gridorius.state:get_player(event.player_index, "current_production_combinator")
				local combinator_settings = Gridorius.GetMetadata(combinator, {
					production = {}
				})
				if not combinator or not combinator_settings then return end
				local value = element.elem_value
				if type(value) == "table" then
					combinator_settings.production[tags.index].item = value.name
					combinator_settings.production[tags.index].quality = value.quality
				else
					combinator_settings.production[tags.index].item = value
				end
			end

			local network = Gridorius.state:get_player(event.player_index, "network")
			if not network then return end

			if tags.type == "select_limit_item" then
				local value = element.elem_value
				if type(value) == "table" then
					network.storage.item_limits[tags.index].item = value.name
					network.storage.item_limits[tags.index].quality = value.quality
				else
					network.storage.item_limits[tags.index].item = value
				end
			end
		end
	end)

	Gridorius.Events:On(defines.events.on_gui_text_changed, function(event)
		local element = event.element
		local tags = element.tags

		if element.name == "search_limit" then
			local scroll = element.parent.limits_scroll
			TerminalGui.RenderItemLimitsScroll(game.get_player(event.player_index), scroll, element.text)
		elseif element.name == "search_item" then
			local items_table = element.parent.items_scroll.items_table
			Gridorius.state:set_player(event.player_index, "search_text", element.text)
			TerminalGui.render_group_data(game.get_player(event.player_index), items_table)
		elseif element.name == "search_production_item" then
			local scroll = element.parent.production_scroll
			TerminalGui.RenderProductionScroll(game.get_player(event.player_index), scroll, element.text)
		end

		if tags then
			if tags.type == "value_production_item" then
				local combinator = Gridorius.state:get_player(event.player_index, "current_production_combinator")
				local combinator_settings = Gridorius.GetMetadata(combinator, {
					production = {}
				})
				if not combinator or not combinator_settings then return end
				local value = element.text
				combinator_settings.production[tags.index].limit = tonumber(value) or 0
			end

			local network = Gridorius.state:get_player(event.player_index, "network")
			if not network then return end

			if tags.type == "value_limit_item" then
				local value = element.text
				network.storage.item_limits[tags.index].limit = tonumber(value) or 0
			end
		end
	end)

	Gridorius.Events:OnNthTick(60, function()
		for _, player in pairs(game.connected_players) do
			local network = Gridorius.state:get_player(player.index, "network")
			if network and player.gui.screen.terminal_frame then
				local data_table = player.gui.screen.terminal_frame.content.center.items_scroll.items_table
				local machines_table = player.gui.screen.terminal_frame.content.right.machines_table
				if data_table and data_table.valid then
					TerminalGui.render_group_data(player, data_table)
				end
				if machines_table and machines_table.valid then
					TerminalGui.render_machines(player, machines_table)
				end
			end
		end
	end)
end

return TerminalGui
