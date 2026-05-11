local network_config = {}

-- These values define the only supported processing batches exposed in the GUI.
network_config.EXTRACT_MACHINE_BATCH_VALUES = { 5, 10, 15, 30 }
network_config.DEFAULT_EXTRACT_MACHINES_PER_TICK = 10
network_config.EXTRACT_MACHINE_BATCH_OPTIONS = {
	[5] = true,
	[10] = true,
	[15] = true,
	[30] = true,
}

function network_config.normalize_extract_machines_per_tick(value)
	-- Clamp arbitrary user input to one of the supported batch sizes.
	local number_value = math.floor(tonumber(value) or network_config.DEFAULT_EXTRACT_MACHINES_PER_TICK)

	if network_config.EXTRACT_MACHINE_BATCH_OPTIONS[number_value] then
		return number_value
	end

	return network_config.DEFAULT_EXTRACT_MACHINES_PER_TICK
end

return network_config
