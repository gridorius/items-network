Gui = require("scripts.gui_lib")

local gui = {
	current_group = nil,
	current_pipe = nil
}

local FRAME_NAME = "items_network_terminal_frame"
local CONTENT_NAME = "items_network_terminal_content"
local GROUP_TABLE = "items_network_terminal_group_table"
local MACHINE_TABLE = "items_network_terminal_machine_table"
local ITEMS_TABLE = "items_network_terminal_items_table"
local PIPE_FRAME_NAME = "items_network_pipe_frame"
local network_logic = nil

local function get_player(player_index)
	local player = game.get_player(player_index)

	if player and player.valid then
		return player
	end

	return nil
end

local function destroy_frame(player)
	local screen_frame = player.gui.screen[FRAME_NAME]
	local left_frame = player.gui.left[FRAME_NAME]
	local pipe_frame = player.gui.screen[PIPE_FRAME_NAME]

	if screen_frame then
		if player.opened == screen_frame then
			player.opened = nil
		end

		screen_frame.destroy()
	end

	if left_frame then
		left_frame.destroy()
	end

	if pipe_frame then
		pipe_frame.destroy()
	end
end

local function add_empty_buttons(item_index, this_table)
    local count = 10 - item_index % 10
    if count < 10 then
        for _ = 1, 10 - item_index % 10 do
            local bt = this_table.add { type = 'sprite-button' }
            bt.enabled = false
            bt.style = 'slot_button'
        end
    end
end

gui.bind_network_logic = function(logic)
	network_logic = logic
end

gui.render_interface = function(player, entity)
	if not network_logic then
		return
	end

	gui.current_network = network_logic.get_network_by_terminal(entity)

	local frame = player.gui.screen.add({
		type = "frame",
		name = FRAME_NAME,
		direction = "vertical",
		draggable = true,
	})

	player.opened = frame
	frame.auto_center = true
	frame.style.minimal_width = 500
	frame.style.minimal_height = 500
	frame.style.maximal_height = 920
	local titlebar = frame.add({ type = "flow", direction = "horizontal" })
	titlebar.drag_target = frame
	titlebar.style.horizontally_stretchable = true
	titlebar.style.top_padding = 4
	titlebar.style.bottom_padding = 4

	local title = titlebar.add({ type = "label", style = "frame_title", caption = { "gui.items-network-terminal-title" } })
	title.style.single_line = true
	local drag_widget = titlebar.add{type = "empty-widget", style = "draggable_space", ignored_by_interaction = true}
	drag_widget.style.horizontally_stretchable = true
	drag_widget.drag_target = frame
	drag_widget.style.height = 30
	drag_widget.style.width = 500

	titlebar.add{
			type = "sprite-button",
			name = "close_button",
			sprite = "utility/close",
			hovered_sprite = "utility/close_black",
			style = "frame_action_button",
			mouse_button_filter = {"left"}
	}


	local spacer = titlebar.add({ type = "empty-widget" })
	spacer.style.horizontally_stretchable = true
	spacer.style.height = 24

	frame.add({ type = "line", direction = "horizontal" })
	frame.force_auto_center()
	frame.bring_to_front()

	local content = frame.add({
		type = "flow",
		name = CONTENT_NAME,
		direction = "horizontal",
	})

	local left_section = content.add{type="flow", name="left_section", direction="vertical"}
	-- left_section.style.width = 500

	local right_section = content.add{type="flow", name="right_section", direction="vertical"}
	-- right_section.style.width = 300

	content.style.vertically_stretchable = true
	content.style.horizontally_stretchable = true
	content.style.padding = 8

	left_section.add({ type = "label", caption = "ID сети " .. gui.current_network.id })
	left_section.add({ type = "label", caption = "Машины в сети" })

	right_section.add({ type = "label", caption = "Использовать топливо" })
	local fuel_table = right_section.add{type="table", name = "fuel_table", column_count = 5}
	fuel_table.style.horizontal_spacing = 5
	fuel_table.style.vertical_spacing = 5
	gui.render_fuel_section(player)

	local machine_table = left_section.add{
		type = "table",
		name = MACHINE_TABLE,
		column_count = 10,
	}

	-- render machines

	local machine_summary = {}

	if not gui.current_network then
		return
	end

	for _, machine_entity in pairs(gui.current_network.storage.machines) do
		if  machine_entity.valid then
			if not machine_summary[machine_entity.name] then
				machine_summary[machine_entity.name] = {
					type="sprite-button", 
					sprite="item/"..machine_entity.name, 
					name=machine_entity.name,
					number = 1
				}
			else
				machine_summary[machine_entity.name].number = machine_summary[machine_entity.name].number + 1
			end
		end
	end

	for _, sum in pairs(machine_summary) do
		machine_table.add(sum)
	end

	local group_table = left_section.add { name = GROUP_TABLE, type = "table", style = 'editor_mode_selection_table', column_count = 6 }

	for name, group in pairs(prototypes.item_group) do
		if not gui.current_group then
			gui.current_group = name
		end
		 local bt = group_table.add {
            type = 'sprite-button',
            sprite = 'item-group/' .. name,
            name = name,
			tags = {
				type = 'item_group',
			},
            tooltip = group.localised_name
        }
        bt.enabled = true
        bt.style = 'filter_group_button_tab_slightly_larger'
	end

	local scroll = left_section.add{type="scroll-pane", name = "items_scroll"}
	scroll.style.maximal_height = 800
	local items_table = scroll.add{type="table", name = ITEMS_TABLE, column_count=10}
	items_table.style.horizontal_spacing = 5
	items_table.style.vertical_spacing = 5

	gui.render_items(player)

	return content
end

function gui.render_fuel_section(player)
	local fuel_table = player.gui.screen[FRAME_NAME][CONTENT_NAME].right_section.fuel_table
	fuel_table.clear()
	local fuel_items = {}

	for name, item in pairs(prototypes.item) do
		if item.fuel_value and item.fuel_value > 0 then
			fuel_items[name] = item
		end
	end

	for fuel_name, _ in pairs(fuel_items) do
		local fuel_item = prototypes.item[fuel_name]
		if fuel_item and fuel_item.fuel_value and fuel_item.fuel_value > 0 then
			local use = gui.current_network.storage.use_fuels[fuel_name] or false
			local button = fuel_table.add{
				type="sprite-button", 
				sprite="item/"..fuel_name, 
				name=fuel_name,
				tags = {
					type = 'fuel',
					fuel_name = fuel_name,
				},
				toggle_mode = true,
				toggled = use,
			}
			button.style.size = 40
		end
	end
end

function gui.render_quality_pack(current_group_items, quality, items_table)
	for subgroup_name, subgroup_items in pairs(current_group_items) do
		local index = 0
		for _, item in pairs(subgroup_items) do
			if(gui.current_network.storage.items[item.name] and gui.current_network.storage.items[item.name][quality] ~= nil) then
				index = index + 1
				items_table.add{
					type="sprite-button", 
					sprite="item/"..item.name, 
					name=item.name .. ":" .. quality,
					tags = {
						type = 'item',
						item_name = item.name,
						quality = quality,
					},
					quality = quality,
					number = gui.current_network.storage.items[item.name][quality],
					elem_tooltip = {
						type = quality == "normal" and 'item' or 'item-with-quality',
						name = item.name,
						quality = quality,
					}
				}
			end
		end
		if index > 0 then
			add_empty_buttons(index, items_table)
		end
	end
end

function gui.render_fluids(fluids, items_table)
	for fluid_name, fluid in pairs(fluids) do
		if(gui.current_network.storage.fluids[fluid_name] ~= nil) then
			for temperature, amount in pairs(gui.current_network.storage.fluids[fluid_name]) do
				items_table.add{
						type="sprite-button", 
						sprite="fluid/"..fluid_name, 
						name = fluid_name .. ":" .. temperature,
						tags = {
							type = 'fluid',
							item_name = fluid_name,
							temperature = temperature,
						},
						number = gui.current_network.storage.fluids[fluid_name][temperature],
						tooltip = {"", {"fluid-name." .. fluid_name}, temperature .. "°C"}
					}
			end
		end
	end
end

function gui.render_items(player)
	local items_table = player.gui.screen[FRAME_NAME][CONTENT_NAME].left_section.items_scroll[ITEMS_TABLE]
	local items = prototypes.item;
	local fluids = prototypes.fluid;
	local tiers = prototypes.quality;
	items_table.clear()


	if(gui.current_group == "fluids") then
		gui.render_fluids(fluids, items_table)
		return
	end

	local current_group_items = {}
	for name, item in pairs(items) do
		if item.group.name == gui.current_group then
			if not current_group_items[item.subgroup.name] then
				current_group_items[item.subgroup.name] = {}
			end
			table.insert(current_group_items[item.subgroup.name], item)
		end
	end

	if not tiers then
		gui.render_quality_pack(current_group_items, "normal", items_table)
		return
	end
	for quality, _ in pairs(tiers) do
		gui.render_quality_pack(current_group_items, quality, items_table)
	end
end

function gui.on_gui_click(event)
	-- The GUI has three click paths: refresh, close, or take an item from storage.
	local player = get_player(event.player_index)

	if not player then
		return
	end

	local element = event.element

	if element and element.valid and element.name == "close_button" then
		gui.close(player)
		return
	end

	if element.tags then

		if element.tags.type == 'select_pipe_fluid' then
			-- Clicked a fluid in the pipe interface, so set that fluid as the pipe's filter.
			local selected_fluid = element.tags.fluid
			local selected_temperature = element.tags.temperature
			local fluid_selection_table = player.gui.screen[PIPE_FRAME_NAME].pipe_content.fluid_selection_table
			if gui.current_pipe and gui.current_pipe.valid then
				storage.pipes[gui.current_pipe.unit_number].fluid_name = selected_fluid
				storage.pipes[gui.current_pipe.unit_number].temperature = selected_temperature

				for _, child in pairs(fluid_selection_table.children) do
					child.toggled = false
				end
				element.toggled = true
			end
			return
		end

		if element.tags.type == 'item_group' then
			-- Clicked an item group, so filter the table by that group.
			local content = player.gui.screen[FRAME_NAME][CONTENT_NAME].left_section
			gui.current_group = element.name
			gui.render_items(player)
			if content and content.valid then
				local group_table = content[GROUP_TABLE]

				if group_table and group_table.valid then
					for _, child in pairs(group_table.children) do
						child.toggled = false
					end

					element.toggled = true
				end
			end

			return
		end

		if element.tags.type == 'item' then
			-- Clicked an item, so attempt to take it from storage and put it in the player's inventory.
			local item_name = element.tags.item_name
			local quality = element.tags.quality
			local item_stack_size = prototypes.item[item_name].stack_size

			local count = math.floor(item_stack_size / 2)
			if(event.shift) then
				count = item_stack_size
			end

			if gui.current_network:get_item_count(item_name, quality) > 0 then
				gui.current_network:move_to_inventory({name = item_name, quality = quality}, count, player)
				gui.render_items(player)
			end

			return
		end

		if element.tags.type == 'fuel' then
			-- Clicked a fuel, so toggle its use in the network.
			local fuel_name = element.tags.fuel_name
			local use = not (gui.current_network.storage.use_fuels[fuel_name] or false)
			gui.current_network.storage.use_fuels[fuel_name] = use
			element.toggled = use
			return
		end
	end

	if not (element and element.valid) then
		return
	end
end

function gui.close(player)
	-- Closing a terminal window also clears the stored per-player GUI state.
	destroy_frame(player)
end

function gui.on_gui_closed(event)
	-- Any closed GUI should clear its terminal state so stale windows do not linger in storage.
	local player = get_player(event.player_index)

	if not player then
		return
	end

	gui.close(player)
end

gui.on_gui_open = function(event)
	if not network_logic then
		return
	end

	local player = get_player(event.player_index)

	if not player then
		return
	end

	if event.element and event.element.valid and event.element.name == FRAME_NAME then
		return
	end

	if event.entity and event.entity.name == "network-fluid-output" then
		player.opened = nil
		gui.current_pipe = event.entity
		gui.current_network = network_logic.get_network_by_pipe(event.entity)
		local frame = player.gui.screen.add({
			type = "frame",
			name = PIPE_FRAME_NAME,
			direction = "vertical",
			draggable = true,
		})
		frame.auto_center = true
		frame.style.minimal_width = 200
		frame.style.maximal_height = 100
		local titlebar = frame.add({ type = "flow", direction = "horizontal" })
		titlebar.drag_target = frame
		titlebar.style.horizontally_stretchable = true
		titlebar.style.top_padding = 4
		titlebar.style.bottom_padding = 4

		local title = titlebar.add({ type = "label", style = "frame_title", caption = "Выберите жидкость" })
		title.style.single_line = true
		titlebar.add{
			type = "sprite-button",
			name = "close_button",
			sprite = "utility/close",
			hovered_sprite = "utility/close_black", -- Common practice for visual feedback
			style = "frame_action_button",
			mouse_button_filter = {"left"}
		}

		local content = frame.add({
			type = "flow",
			name = "pipe_content",
			direction = "horizontal",
		})

		local fluid_table = content.add{type="table", name = "fluid_selection_table", column_count= 10}
		fluid_table.style.horizontal_spacing = 5
		fluid_table.style.vertical_spacing = 5
		
		for fluid_name, temperatures in pairs(gui.current_network.storage.fluids) do
			for temperature, _ in pairs(temperatures) do
				local fluid_element = fluid_table.add{
					type="sprite-button", 
					sprite="fluid/"..fluid_name, 
					name = fluid_name .. ":" .. temperature,
					tags = {
						type = 'select_pipe_fluid',
						fluid = fluid_name,
						temperature = temperature,
					},
					number = temperature,
					tooltip = {"", {"fluid-name." .. fluid_name}, temperature .. "°C"}
				}

				if storage.pipes[gui.current_pipe.unit_number] and storage.pipes[gui.current_pipe.unit_number].fluid_name == fluid_name and storage.pipes[gui.current_pipe.unit_number].temperature == temperature then
					fluid_element.toggled = true
				end
			end
		end
		return
	end

	if event.entity and network_logic.is_terminal(event.entity) then
		player.opened = nil
		gui.render_interface(player, event.entity)
	else
		gui.close(player)
	end
end

return gui