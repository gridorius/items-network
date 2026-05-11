local gui = {}

local FRAME_NAME = "items_network_terminal_frame"
local CONTENT_NAME = "items_network_terminal_content"
local REFRESH_BUTTON_NAME = "items_network_terminal_refresh"
local CLOSE_BUTTON_NAME = "items_network_terminal_close"
local SUMMARY_SECTION_NAME = "items_network_terminal_summary_section"
local BODY_SECTION_NAME = "items_network_terminal_body_section"
local MACHINE_SECTION_NAME = "items_network_terminal_machine_section"
local ITEM_SECTION_NAME = "items_network_terminal_item_section"
local ITEM_BUTTON_NAME_PREFIX = "items_network_terminal_item_"
local ITEM_BUTTON_ACTION = "take-network-item"
local ITEM_GROUP_TABBED_PANE_NAME = "items_network_terminal_item_groups"
local ITEM_GROUP_TAB_NAME_PREFIX = "items_network_terminal_item_group_tab_"
local ITEM_GROUP_TAB_CONTENT_NAME = "items_network_terminal_item_group_content"
local ITEM_GROUP_TAB_ACTION = "select-item-group"
local ITEM_SINGLE_GROUP_CONTENT_NAME = "items_network_terminal_item_single_group"
local ITEM_GRID_SCROLL_NAME = "items_network_terminal_item_grid_scroll"
local ITEM_GRID_CONTENT_NAME = "items_network_terminal_item_grid_content"
local ITEM_EMPTY_LABEL_NAME = "items_network_terminal_item_grid_empty"
local ITEM_GRID_COLUMN_COUNT = 8
local ITEM_GRID_CONTENT_COLUMN_COUNT = 1
local ITEM_GROUP_TAB_COLUMN_COUNT = 6
local FLUID_GROUP_NAME = "__fluids__"

local network_logic = nil

local function ensure_storage()
	-- Player-specific GUI state is persisted in storage so open windows survive reloads.
	storage.player_terminal_gui = storage.player_terminal_gui or {}
end

local function get_player(player_index)
	local player = game.get_player(player_index)

	if player and player.valid then
		return player
	end

	return nil
end

local function get_state(player_index)
	ensure_storage()
	return storage.player_terminal_gui[player_index]
end

local function set_state(player_index, terminal_unit_number)
	ensure_storage()

	storage.player_terminal_gui[player_index] = {
		terminal_unit_number = terminal_unit_number,
		selected_item_group = nil,
		pending_open_bind = false,
	}
end

local function clear_state(player_index)
	if storage.player_terminal_gui then
		storage.player_terminal_gui[player_index] = nil
	end
end

local function destroy_frame(player)
	local screen_frame = player.gui.screen[FRAME_NAME]
	local left_frame = player.gui.left[FRAME_NAME]

	if screen_frame then
		if player.opened == screen_frame then
			player.opened = nil
		end

		screen_frame.destroy()
	end

	if left_frame then
		left_frame.destroy()
	end
end

local function get_frame(player)
	return player.gui.screen[FRAME_NAME]
end

local function add_heading(parent, caption)
	local label = parent.add({ type = "label", caption = caption })
	label.style = "heading_2_label"
	return label
end

local function get_entity_caption(entity_name)
	-- Use prototype-localized names when available so the GUI stays translated.
	local prototype = prototypes.entity[entity_name]

	if prototype then
		return prototype.localised_name
	end

	return entity_name
end

local function get_item_caption(item_name)
	-- Item names follow the same rule as entities: prefer the prototype label, then fallback.
	local prototype = prototypes.item[item_name]

	if prototype then
		return prototype.localised_name
	end

	return item_name
end

local function get_fluid_caption(fluid_name)
	local prototype = prototypes.fluid[fluid_name]

	if prototype then
		return prototype.localised_name
	end

	return fluid_name
end

local function get_resource_caption(resource_type, resource_name)
	if resource_type == "fluid" then
		return get_fluid_caption(resource_name)
	end

	return get_item_caption(resource_name)
end

local function get_resource_group_data(item)
	if item.type == "fluid" then
		local prototype = prototypes.fluid[item.name]
		local subgroup = prototype and prototype.subgroup or nil
		local group = subgroup and subgroup.group or nil

		if group then
			return {
				name = group.name,
				caption = group.localised_name,
				order = group.order or "",
				sprite = "item-group/" .. group.name,
			}
		end

		return {
			name = FLUID_GROUP_NAME,
			caption = { "gui.items-network-fluid-group" },
			order = "zz[fluids]",
			sprite = "fluid/" .. item.name,
		}
	end

	local prototype = prototypes.item[item.name]
	local group = prototype and prototype.group or nil

	if not group then
		return nil
	end

	return {
		name = group.name,
		caption = group.localised_name,
		order = group.order or "",
		sprite = "item-group/" .. group.name,
	}
end

local function get_resource_subgroup_data(item)
	if item.type == "fluid" then
		local prototype = prototypes.fluid[item.name]
		local subgroup = prototype and prototype.subgroup or nil

		if not subgroup then
			return {
				name = FLUID_GROUP_NAME,
				caption = { "gui.items-network-fluid-group" },
				order = "",
			}
		end

		return {
			name = subgroup.name,
			caption = subgroup.localised_name,
			order = subgroup.order or "",
		}
	end

	local prototype = prototypes.item[item.name]
	local subgroup = prototype and prototype.subgroup or nil

	if not subgroup then
		return nil
	end

	return {
		name = subgroup.name,
		caption = subgroup.localised_name,
		order = subgroup.order or "",
	}
end

local function get_quality_caption(quality_name)
	if not quality_name then
		return nil
	end

	local prototype = prototypes.quality[quality_name]

	if prototype then
		return prototype.localised_name
	end

	return quality_name
end

local function get_display_quality_caption(quality_name)
	return get_quality_caption(quality_name or "normal")
end

local function get_quality_id(quality)
	if not quality then
		return nil
	end

	if type(quality) == "string" then
		return quality
	end

	return quality.name
end

local function get_quality_level(quality_name)
	local normalized_quality = get_quality_id(quality_name) or "normal"
	local prototype = prototypes.quality[normalized_quality]

	if prototype then
		return prototype.level, prototype.order or "", prototype.name
	end

	return 0, "", normalized_quality
end

local function build_item_tooltip_from_values(resource_type, resource_name, quality, count)
	local tooltip = { "", get_resource_caption(resource_type, resource_name) }

	if resource_type == "item" then
		tooltip[#tooltip + 1] = "\n"
		tooltip[#tooltip + 1] = get_display_quality_caption(quality)
	end

	if count then
		tooltip[#tooltip + 1] = "\n"
		tooltip[#tooltip + 1] = count
		tooltip[#tooltip + 1] = " x"
	end

	return tooltip
end

local function build_item_tooltip(item)
	-- Tooltips show quality and count so each button explains exactly what it returns.
	return build_item_tooltip_from_values(item.type or "item", item.name, item.quality, item.count)
end

local function get_click_take_count(item_name, event)
	local item_prototype = prototypes.item[item_name]
	local stack_size = item_prototype and item_prototype.stack_size or 1

	if event.control and event.button == defines.mouse_button_type.left then
		return stack_size * 10
	end

	if event.control and event.button == defines.mouse_button_type.right then
		return stack_size * 50
	end

	if event.button == defines.mouse_button_type.right then
		return stack_size
	end

	if event.button == defines.mouse_button_type.left then
		return math.max(1, math.floor(stack_size / 5))
	end

	return 0
end

local function build_item_group_list(items)
	local group_map = {}
	local groups = {}

	for _, item in ipairs(items or {}) do
		local group_data = get_resource_group_data(item)

		if group_data and not group_map[group_data.name] then
			group_map[group_data.name] = true
			groups[#groups + 1] = group_data
		end
	end

	table.sort(groups, function(left, right)
		if left.order == right.order then
			return left.name < right.name
		end

		return left.order < right.order
	end)

	return groups
end

local function ensure_selected_item_group(state, items)
	if not state then
		return nil
	end

	local groups = build_item_group_list(items)

	if #groups == 0 then
		state.selected_item_group = nil
		return nil
	end

	for _, group in ipairs(groups) do
		if group.name == state.selected_item_group then
			return state.selected_item_group
		end
	end

	state.selected_item_group = groups[1].name
	return state.selected_item_group
end

local function filter_items_by_group_name(group_name, items)
	if not group_name then
		return items
	end

	local filtered_items = {}

	for _, item in ipairs(items or {}) do
		local group_data = get_resource_group_data(item)

		if group_data and group_data.name == group_name then
			filtered_items[#filtered_items + 1] = item
		end
	end

	return filtered_items
end

local function filter_items_by_selected_group(state, items)
	local selected_group = ensure_selected_item_group(state, items)

	return filter_items_by_group_name(selected_group, items)
end

local function sort_items_for_recipe_rows(items)
	table.sort(items, function(left, right)
		local left_prototype = left.type == "fluid" and prototypes.fluid[left.name] or prototypes.item[left.name]
		local right_prototype = right.type == "fluid" and prototypes.fluid[right.name] or prototypes.item[right.name]
		local left_order = left_prototype and left_prototype.order or ""
		local right_order = right_prototype and right_prototype.order or ""

		if (left.type or "item") ~= (right.type or "item") then
			return (left.type or "item") < (right.type or "item")
		end

		if left_order ~= right_order then
			return left_order < right_order
		end

		if left.name ~= right.name then
			return left.name < right.name
		end

		local left_level, left_quality_order, left_quality_name = get_quality_level(left.quality)
		local right_level, right_quality_order, right_quality_name = get_quality_level(right.quality)

		if left_level ~= right_level then
			return left_level < right_level
		end

		if left_quality_order ~= right_quality_order then
			return left_quality_order < right_quality_order
		end

		return left_quality_name < right_quality_name
	end)
end

local function build_item_recipe_rows(items)
	local subgroup_map = {}
	local subgroups = {}

	for _, item in ipairs(items or {}) do
		local subgroup_data = get_resource_subgroup_data(item) or {
			name = "__ungrouped__",
			caption = nil,
			order = "",
		}
		local subgroup = subgroup_map[subgroup_data.name]

		if not subgroup then
			subgroup = {
				name = subgroup_data.name,
				caption = subgroup_data.caption,
				order = subgroup_data.order,
				quality_rows = {},
				quality_row_map = {},
			}
			subgroup_map[subgroup_data.name] = subgroup
			subgroups[#subgroups + 1] = subgroup
		end

		local quality_name = get_quality_id(item.quality) or "normal"
		local quality_row = subgroup.quality_row_map[quality_name]

		if not quality_row then
			local quality_level, quality_order, normalized_quality_name = get_quality_level(quality_name)

			quality_row = {
				quality = normalized_quality_name,
				level = quality_level,
				order = quality_order,
				items = {},
			}
			subgroup.quality_row_map[quality_name] = quality_row
			subgroup.quality_rows[#subgroup.quality_rows + 1] = quality_row
		end

		quality_row.items[#quality_row.items + 1] = item
	end

	table.sort(subgroups, function(left, right)
		if left.order == right.order then
			return left.name < right.name
		end

		return left.order < right.order
	end)

	for _, subgroup in ipairs(subgroups) do
		table.sort(subgroup.quality_rows, function(left, right)
			if left.level ~= right.level then
				return left.level < right.level
			end

			if left.order ~= right.order then
				return left.order < right.order
			end

			return left.quality < right.quality
		end)

		for _, quality_row in ipairs(subgroup.quality_rows) do
			sort_items_for_recipe_rows(quality_row.items)
		end
	end

	return subgroups
end

local function add_item_button(parent, item)
	local tags = {
		action = ITEM_BUTTON_ACTION,
		resource_type = item.type or "item",
		item_name = item.name,
	}

	if (item.type or "item") == "item" and item.quality then
		tags.quality = item.quality
	end

	local item_button_name = ITEM_BUTTON_NAME_PREFIX .. (item.type or "item") .. "_" .. item.name

	if (item.type or "item") == "item" and item.quality then
		item_button_name = item_button_name .. "_" .. item.quality
	end

	local sprite = ((item.type or "item") == "fluid") and ("fluid/" .. item.name) or ("item/" .. item.name)

	parent.add({
		type = "sprite-button",
		name = item_button_name,
		style = "slot_button",
		sprite = sprite,
		quality = ((item.type or "item") == "item") and get_quality_id(item.quality) or nil,
		number = item.count,
		show_percent_for_small_numbers = false,
		tooltip = build_item_tooltip(item),
		tags = tags,
	})
end

local function render_item_grid(content, items)
	local empty_label = content[ITEM_EMPTY_LABEL_NAME]
	local list = content[ITEM_GRID_SCROLL_NAME]

	if #items == 0 then
		if list then
			list.destroy()
		end

		if not empty_label then
			content.add({
				type = "label",
				name = ITEM_EMPTY_LABEL_NAME,
				caption = { "gui.items-network-storage-empty" },
			})
		end

		return
	end

	if empty_label then
		empty_label.destroy()
	end

	if not list then
		list = content.add({ type = "scroll-pane", name = ITEM_GRID_SCROLL_NAME })
		list.style.maximal_height = 420
		list.style.minimal_width = 360
		list.vertical_scroll_policy = "auto"
		list.horizontal_scroll_policy = "never"
	end

	local grid_content = list[ITEM_GRID_CONTENT_NAME]

	if not grid_content then
		grid_content = list.add({
			type = "table",
			name = ITEM_GRID_CONTENT_NAME,
			column_count = ITEM_GRID_CONTENT_COLUMN_COUNT,
		})
		grid_content.style.horizontally_stretchable = true
		grid_content.style.vertical_spacing = 4
	else
		grid_content.clear()
	end

	for _, subgroup in ipairs(build_item_recipe_rows(items)) do
		for _, quality_row in ipairs(subgroup.quality_rows) do
			local grid = grid_content.add({ type = "table", column_count = ITEM_GRID_COLUMN_COUNT })
			grid.style.horizontal_spacing = 8
			grid.style.vertical_spacing = 8

			for _, item in ipairs(quality_row.items) do
				add_item_button(grid, item)
			end
		end
	end
end

local function update_item_group_buttons(button_row, selected_group)
	for _, button in ipairs(button_row.children) do
		if button.valid and button.tags and button.tags.item_group then
			button.toggled = button.tags.item_group == selected_group
		end
	end
end

local function build_item_group_tabbed_pane(content, state, items)
	local groups = build_item_group_list(items)
	local selected_group = ensure_selected_item_group(state, items)

	local button_row = content.add({
		type = "table",
		name = ITEM_GROUP_TABBED_PANE_NAME,
		style = "editor_mode_selection_table",
		column_count = ITEM_GROUP_TAB_COLUMN_COUNT,
	})
	button_row.style.horizontally_stretchable = true
	button_row.style.bottom_padding = 8
	button_row.style.horizontal_spacing = 6
	button_row.style.vertical_spacing = 6

	for _, group in ipairs(groups) do
		local button = button_row.add({
			type = "sprite-button",
			name = ITEM_GROUP_TAB_NAME_PREFIX .. group.name,
			style = "filter_group_button_tab_slightly_larger",
			sprite = group.sprite,
			tooltip = group.caption,
			auto_toggle = false,
			toggled = group.name == selected_group,
			tags = {
				action = ITEM_GROUP_TAB_ACTION,
				item_group = group.name,
			},
		})
	end

	local tab_content = content.add({
		type = "flow",
		name = ITEM_GROUP_TAB_CONTENT_NAME,
		direction = "vertical",
	})
	tab_content.style.horizontally_stretchable = true
	render_item_grid(tab_content, filter_items_by_group_name(selected_group, items))
end

local function render_item_group_tabs(content, state, items)
	local groups = build_item_group_list(items)

	if #groups <= 1 then
		local single_group_content = content.add({
			type = "flow",
			name = ITEM_SINGLE_GROUP_CONTENT_NAME,
			direction = "vertical",
		})
		single_group_content.style.horizontally_stretchable = true
		render_item_grid(single_group_content, filter_items_by_selected_group(state, items))
		return
	end

	build_item_group_tabbed_pane(content, state, items)
end

local function refresh_item_group_tabs_runtime(content, state, items)
	local button_row = content[ITEM_GROUP_TABBED_PANE_NAME]
	local tab_content = content[ITEM_GROUP_TAB_CONTENT_NAME]

	if button_row and tab_content then
		local selected_group = ensure_selected_item_group(state, items)
		update_item_group_buttons(button_row, selected_group)
		render_item_grid(tab_content, filter_items_by_group_name(selected_group, items))

		return
	end

	local single_group_content = content[ITEM_SINGLE_GROUP_CONTENT_NAME]

	if single_group_content then
		render_item_grid(single_group_content, filter_items_by_selected_group(state, items))
		return
	end

	render_item_group_tabs(content, state, items)
end

local function render_disconnected(content)
	-- When the terminal is not attached to a cable network, show a clear status message.
	content.add({ type = "label", caption = { "gui.items-network-terminal-disconnected" } })
end

local function render_summary(content, snapshot)
	-- The summary is the compact overview: id and terminal count.
	content.add({ type = "label", caption = { "", { "gui.items-network-terminal-network" }, ": ", snapshot.network_id or "-" } })
	content.add({ type = "label", caption = { "", { "gui.items-network-terminals" }, ": ", snapshot.terminal_count } })
end

local function render_item_list(content, state, snapshot)
	-- Item buttons act as a quick withdrawal UI for the terminal's shared storage.
	add_heading(content, { "gui.items-network-storage" })
	render_item_group_tabs(content, state, snapshot.items)
end

local function refresh_item_list_runtime(content, state, snapshot)
	refresh_item_group_tabs_runtime(content, state, snapshot.items)
end

local function render_machine_list(content, snapshot)
	-- Show connected machines separately so the player can see what the network is servicing.
	add_heading(content, { "gui.items-network-terminal-producers" })

	if #snapshot.machines == 0 then
		content.add({ type = "label", caption = { "gui.items-network-terminal-producers-none" } })
		return
	end

	local list = content.add({ type = "scroll-pane" })
	list.style.maximal_height = 180
	list.style.minimal_width = 360

	local grid = list.add({ type = "table", column_count = 6 })
	grid.style.horizontal_spacing = 8
	grid.style.vertical_spacing = 8

	for _, machine in ipairs(snapshot.machines) do
		grid.add({
			type = "sprite-button",
			style = "slot_button",
			sprite = "entity/" .. machine.name,
			number = machine.count,
			show_percent_for_small_numbers = false,
			tooltip = { "", get_entity_caption(machine.name), "\n", machine.count, " x" },
		})
	end
end

local function build_frame(player)
	-- Rebuild the whole window when the terminal first opens or the layout changes.
	destroy_frame(player)

	local frame = player.gui.screen.add({
		type = "frame",
		name = FRAME_NAME,
		direction = "vertical",
	})

	frame.auto_center = true
	frame.style.minimal_width = 980
	frame.style.maximal_height = 920

	local titlebar = frame.add({ type = "flow", direction = "horizontal" })
	titlebar.drag_target = frame
	titlebar.style.horizontally_stretchable = true
	titlebar.style.top_padding = 4
	titlebar.style.bottom_padding = 4

	local title = titlebar.add({ type = "label", caption = { "gui.items-network-terminal-title" } })
	title.style.single_line = true

	local spacer = titlebar.add({ type = "empty-widget" })
	spacer.style.horizontally_stretchable = true
	spacer.style.height = 24

	titlebar.add({ type = "button", name = REFRESH_BUTTON_NAME, caption = { "gui.items-network-refresh" } })
	titlebar.add({ type = "button", name = CLOSE_BUTTON_NAME, caption = { "gui.items-network-close" } })

	frame.add({ type = "line", direction = "horizontal" })

	local content = frame.add({
		type = "flow",
		name = CONTENT_NAME,
		direction = "vertical",
	})

	content.style.vertically_stretchable = true
	content.style.horizontally_stretchable = true
	content.style.padding = 8

	frame.force_auto_center()
	frame.bring_to_front()

	return content
end

local function render_summary_section(section, snapshot)
	section.clear()
	render_summary(section, snapshot)
end

local function render_machine_section(section, snapshot)
	section.clear()

	if snapshot.connected then
		render_machine_list(section, snapshot)
	else
		render_disconnected(section)
	end
	end

local function render_item_section(section, state, snapshot)
	section.clear()
	render_item_list(section, state, snapshot)
	end

local function render_body_section(section, state, snapshot)
	section.clear()

	local machine_section = section.add({ type = "flow", name = MACHINE_SECTION_NAME, direction = "vertical" })
	machine_section.style.horizontally_stretchable = true
	render_machine_section(machine_section, snapshot)

	local item_section = section.add({ type = "flow", name = ITEM_SECTION_NAME, direction = "vertical" })
	item_section.style.horizontally_stretchable = true
	render_item_section(item_section, state, snapshot)
end

local function refresh_player_internal(player)
	-- Full refresh: rebuild the frame when controls or layout may have changed.
	if not network_logic then
		return
	end

	local state = get_state(player.index)

	if not state then
		destroy_frame(player)
		return
	end

	local snapshot = network_logic.get_terminal_snapshot(state.terminal_unit_number)

	if not snapshot then
		gui.close(player)
		return
	end

	local frame = get_frame(player)

	if frame and not frame.valid then
		frame = nil
	end

	local content = frame and frame[CONTENT_NAME] or build_frame(player)

	content.clear()

	local summary_section = content.add({ type = "flow", name = SUMMARY_SECTION_NAME, direction = "vertical" })
	render_summary_section(summary_section, snapshot)

	local body_section = content.add({ type = "flow", name = BODY_SECTION_NAME, direction = "vertical" })
	render_body_section(body_section, state, snapshot)
end

local function refresh_player_runtime_internal(player)
	-- Runtime refresh: only redraw the dynamic content to avoid unnecessary GUI churn.
	if not network_logic then
		return
	end

	local state = get_state(player.index)

	if not state then
		return
	end

	local frame = get_frame(player)

	if not frame then
		return
	end

	local content = frame[CONTENT_NAME]

	if not content then
		return
	end

	local snapshot = network_logic.get_terminal_snapshot(state.terminal_unit_number)

	if not snapshot then
		gui.close(player)
		return
	end

	local summary_section = content[SUMMARY_SECTION_NAME]
	local body_section = content[BODY_SECTION_NAME]

	if not summary_section or not body_section then
		refresh_player_internal(player)
		return
	end

	render_summary_section(summary_section, snapshot)

	local machine_section = body_section[MACHINE_SECTION_NAME]
	local item_section = body_section[ITEM_SECTION_NAME]

	if not machine_section or not item_section then
		refresh_player_internal(player)
		return
	end

	render_machine_section(machine_section, snapshot)
	refresh_item_list_runtime(item_section, state, snapshot)
end

function gui.bind_network_logic(module)
	network_logic = module
end

function gui.init()
	ensure_storage()
end

function gui.open_terminal(player, terminal)
	-- Opening a terminal binds that player to the terminal unit_number until the window closes.
	if not (network_logic and network_logic.is_terminal(terminal)) then
		return
	end

	set_state(player.index, terminal.unit_number)
	refresh_player_internal(player)

	local state = get_state(player.index)

	if state then
		state.pending_open_bind = true
	end
end

function gui.close(player)
	-- Closing a terminal window also clears the stored per-player GUI state.
	destroy_frame(player)
	clear_state(player.index)
end

function gui.refresh_player(player)
	refresh_player_internal(player)
end

function gui.has_open_terminals()
	ensure_storage()
	return next(storage.player_terminal_gui) ~= nil
end

function gui.refresh_all()
	-- Full refresh is used after topology changes, when captions and controls may need rebuilding.
	ensure_storage()

	for player_index in pairs(storage.player_terminal_gui) do
		local player = get_player(player_index)

		if player then
			refresh_player_internal(player)
		else
			clear_state(player_index)
		end
	end
end

function gui.refresh_all_runtime()
	-- Runtime refresh is lighter and only updates the live numbers and lists.
	ensure_storage()

	for player_index in pairs(storage.player_terminal_gui) do
		local player = get_player(player_index)

		if player then
			refresh_player_runtime_internal(player)
		else
			clear_state(player_index)
		end
	end
end

function gui.flush_pending_opened_frames()
	ensure_storage()

	for player_index, state in pairs(storage.player_terminal_gui) do
		if state.pending_open_bind then
			local player = get_player(player_index)

			if not player then
				clear_state(player_index)
			else
				local frame = get_frame(player)

				if frame and frame.valid then
					player.opened = frame
					state.pending_open_bind = false
				else
					clear_state(player_index)
				end
			end
		end
	end
end

function gui.on_gui_opened(event)
	-- Hook the window only when the player actually opened a network terminal.
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

	if event.entity and network_logic.is_terminal(event.entity) then
		player.opened = nil
		gui.open_terminal(player, event.entity)
	else
		gui.close(player)
	end
end

function gui.on_gui_closed(event)
	-- Any closed GUI should clear its terminal state so stale windows do not linger in storage.
	local player = get_player(event.player_index)

	if not player then
		return
	end

	if event.element and event.element.valid and event.element.name == FRAME_NAME then
		gui.close(player)
		return
	end

	if event.entity and network_logic and network_logic.is_terminal(event.entity) then
		gui.close(player)
	end
end

function gui.on_gui_click(event)
	-- The GUI has three click paths: refresh, close, or take an item from storage.
	local player = get_player(event.player_index)

	if not player then
		return
	end

	local element = event.element

	if not (element and element.valid) then
		return
	end

	if element.name == REFRESH_BUTTON_NAME then
		refresh_player_internal(player)
	elseif element.name == CLOSE_BUTTON_NAME then
		gui.close(player)
	elseif element.tags and element.tags.action == ITEM_GROUP_TAB_ACTION then
		local state = get_state(player.index)

		if not state then
			return
		end

		state.selected_item_group = element.tags.item_group
		refresh_player_runtime_internal(player)
	elseif element.tags and element.tags.action == ITEM_BUTTON_ACTION then
		local state = get_state(player.index)

		if not (state and network_logic) then
			return
		end

		local tags = element.tags
		local resource_type = tags.resource_type or "item"
		local item_name = tags.item_name

		if not item_name then
			return
		end

		if event.alt and event.button == defines.mouse_button_type.left then
			local item_prototype = resource_type == "fluid" and prototypes.fluid[item_name] or prototypes.item[item_name]

			if item_prototype then
				player.open_factoriopedia_gui(item_prototype)
			end

			return
		end

		if resource_type ~= "item" then
			return
		end

		local take_count = get_click_take_count(item_name, event)

		if take_count <= 0 then
			return
		end

		network_logic.take_terminal_item(state.terminal_unit_number, player, item_name, tags.quality, take_count)
		gui.refresh_all_runtime()
	end
end

function gui.on_gui_selected_tab_changed(event)
	local player = get_player(event.player_index)

	if not player then
		return
	end

	local element = event.element

	if not (element and element.valid and element.name == ITEM_GROUP_TABBED_PANE_NAME) then
		return
	end

	local state = get_state(player.index)

	if not state then
		return
	end

	local selected_index = element.selected_tab_index
	local tab_and_content = selected_index and element.tabs[selected_index] or nil
	local tab = tab_and_content and tab_and_content.tab or nil

	if not (tab and tab.valid and tab.tags) then
		return
	end

	state.selected_item_group = tab.tags.item_group
end

function gui.on_player_removed(event)
	-- Dropped players must be removed from storage so stale GUI state is not reused.
	clear_state(event.player_index)
end

return gui
