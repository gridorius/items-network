local gui = {}

local FRAME_NAME = "items_network_fluid_output_frame"
local CONTENT_NAME = "items_network_fluid_output_content"
local SELECTOR_NAME = "items_network_fluid_output_selector"
local CLOSE_BUTTON_NAME = "items_network_fluid_output_close"
local CLEAR_BUTTON_NAME = "items_network_fluid_output_clear"

local network_logic = nil

local function ensure_storage()
	storage.player_fluid_output_gui = storage.player_fluid_output_gui or {}
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
	return storage.player_fluid_output_gui[player_index]
end

local function set_state(player_index, fluid_output_unit_number)
	ensure_storage()

	storage.player_fluid_output_gui[player_index] = {
		fluid_output_unit_number = fluid_output_unit_number,
		pending_open_bind = false,
	}
end

local function clear_state(player_index)
	if storage.player_fluid_output_gui then
		storage.player_fluid_output_gui[player_index] = nil
	end
end

local function destroy_frame(player)
	local frame = player.gui.screen[FRAME_NAME]

	if frame then
		if player.opened == frame then
			player.opened = nil
		end

		frame.destroy()
	end
end

local function get_frame(player)
	return player.gui.screen[FRAME_NAME]
end

local function build_frame(player)
	destroy_frame(player)

	local frame = player.gui.screen.add({
		type = "frame",
		name = FRAME_NAME,
		direction = "vertical",
	})

	frame.auto_center = true
	frame.style.minimal_width = 420

	local titlebar = frame.add({ type = "flow", direction = "horizontal" })
	titlebar.drag_target = frame
	titlebar.style.horizontally_stretchable = true

	local title = titlebar.add({ type = "label", caption = { "gui.items-network-fluid-output-title" } })
	title.style.single_line = true

	local spacer = titlebar.add({ type = "empty-widget" })
	spacer.style.horizontally_stretchable = true
	spacer.style.height = 24

	titlebar.add({ type = "button", name = CLEAR_BUTTON_NAME, caption = { "gui.items-network-fluid-output-clear" } })
	titlebar.add({ type = "button", name = CLOSE_BUTTON_NAME, caption = { "gui.items-network-close" } })

	frame.add({ type = "line", direction = "horizontal" })

	local content = frame.add({
		type = "flow",
		name = CONTENT_NAME,
		direction = "vertical",
	})

	content.style.padding = 8
	content.style.horizontally_stretchable = true

	frame.force_auto_center()
	frame.bring_to_front()

	return content
end

local function refresh_player_internal(player)
	if not network_logic then
		return
	end

	local state = get_state(player.index)

	if not state then
		destroy_frame(player)
		return
	end

	local snapshot = network_logic.get_fluid_output_snapshot(state.fluid_output_unit_number)

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

	content.add({ type = "label", caption = { "", { "gui.items-network-terminal-network" }, ": ", snapshot.network_id or "-" } })

	if not snapshot.connected then
		content.add({ type = "label", caption = { "gui.items-network-terminal-disconnected" } })
	end

	content.add({ type = "label", caption = { "gui.items-network-fluid-output-selected" } })

	local selector = content.add({
		type = "choose-elem-button",
		name = SELECTOR_NAME,
		elem_type = "fluid",
	})
	selector.elem_value = snapshot.selected_fluid_name

	if snapshot.selected_fluid_name then
		content.add({
			type = "label",
			caption = { "", { "gui.items-network-fluid-output-available" }, ": ", snapshot.available_amount },
		})
	else
		content.add({ type = "label", caption = { "gui.items-network-fluid-output-none" } })
	end
end

function gui.bind_network_logic(module)
	network_logic = module
end

function gui.init()
	ensure_storage()
end

function gui.open(player, fluid_output)
	if not (network_logic and network_logic.is_fluid_output(fluid_output)) then
		return
	end

	set_state(player.index, fluid_output.unit_number)
	refresh_player_internal(player)

	local state = get_state(player.index)

	if state then
		state.pending_open_bind = true
	end
end

function gui.close(player)
	destroy_frame(player)
	clear_state(player.index)
end

function gui.has_open_windows()
	ensure_storage()
	return next(storage.player_fluid_output_gui) ~= nil
end

function gui.refresh_all()
	ensure_storage()

	for player_index in pairs(storage.player_fluid_output_gui) do
		local player = get_player(player_index)

		if player then
			refresh_player_internal(player)
		else
			clear_state(player_index)
		end
	end
end

function gui.refresh_all_runtime()
	gui.refresh_all()
end

function gui.flush_pending_opened_frames()
	ensure_storage()

	for player_index, state in pairs(storage.player_fluid_output_gui) do
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

	if event.entity and network_logic.is_fluid_output(event.entity) then
		player.opened = nil
		gui.open(player, event.entity)
	else
		gui.close(player)
	end
end

function gui.on_gui_closed(event)
	local player = get_player(event.player_index)

	if not player then
		return
	end

	if event.element and event.element.valid and event.element.name == FRAME_NAME then
		gui.close(player)
		return
	end

	if event.entity and network_logic and network_logic.is_fluid_output(event.entity) then
		gui.close(player)
	end
end

function gui.on_gui_click(event)
	local player = get_player(event.player_index)

	if not player then
		return
	end

	local element = event.element

	if not (element and element.valid) then
		return
	end

	if element.name == CLOSE_BUTTON_NAME then
		gui.close(player)
	elseif element.name == CLEAR_BUTTON_NAME then
		local state = get_state(player.index)

		if state and network_logic then
			network_logic.set_fluid_output_filter(state.fluid_output_unit_number, nil)
			refresh_player_internal(player)
		end
	end
end

function gui.on_gui_elem_changed(event)
	local player = get_player(event.player_index)

	if not player then
		return
	end

	local element = event.element

	if not (element and element.valid and element.name == SELECTOR_NAME and network_logic) then
		return
	end

	local state = get_state(player.index)

	if not state then
		return
	end

	network_logic.set_fluid_output_filter(state.fluid_output_unit_number, element.elem_value)
	refresh_player_internal(player)
end

function gui.on_player_removed(event)
	clear_state(event.player_index)
end

return gui