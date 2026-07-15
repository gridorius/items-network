local Events = require("scripts.lib.events")
Gridorius = {
    MergeProperties = function(base, additional)
        if additional and type(additional) == "table" then
            for key, value in pairs(additional) do
                base[key] = value
            end
        end

        return base
    end,
    Dictionary = require("scripts.lib.dictionary"),
    Inventory = require("scripts.lib.inventory"),
    Events = Events:new(),
    translation = {},
    nth_tick = function(tick_num)
        return game.tick % tick_num == 0
    end
}

function Gridorius.GetTranslation(player_index, prototype_name)
    local player_translation = Gridorius.translation[player_index]
    return player_translation or prototype_name
end

Gridorius.insert_fluid = function(entity, fluid, index, max_insert)
    if max_insert <= 0 or index > entity.fluids_count then
        return 0
    end

    local current_fluid = entity.get_fluid(index)
    if current_fluid and
        (current_fluid.name ~= fluid.name or
            (fluid.temperature and current_fluid.temperature ~= fluid.temperature)) then
        return 0
    end

    return entity.add_fluid(index, {
        name = fluid.name,
        amount = max_insert,
        temperature = fluid.temperature
    })
end

Gridorius.insert_fluid_segments = function(entity, fluid, index, max_insert)
    if max_insert <= 0 or index > entity.fluids_count then
        return 0
    end

    if not entity.has_fluid_segment(index) then
        return Gridorius.insert_fluid(entity, fluid, index, max_insert)
    end

    local current_fluid = entity.get_fluid_segment_fluid(index)
    if current_fluid and
        (current_fluid.name ~= fluid.name or
            (fluid.temperature and current_fluid.temperature ~= fluid.temperature)) then
        return 0
    end

    return entity.add_fluid_segment_fluid(index, {
        name = fluid.name,
        amount = max_insert,
        temperature = fluid.temperature
    })
end

function Gridorius.init()
    storage.metadata = storage.metadata or {}
    Gridorius.metadata = storage.metadata
    -- Gridorius.FixMetadata()
end

function Gridorius.SetMetadata(entity, metadata)
    Gridorius.metadata = Gridorius.metadata or {}
    Gridorius.metadata[entity.unit_number] = metadata
end

function Gridorius.SetMetadataValue(entity, key, value)
    if not Gridorius.metadata[entity.unit_number] then
        Gridorius.metadata[entity.unit_number] = {}
    end
    Gridorius.metadata[entity.unit_number][key] = value
end

function Gridorius.RemoveMetadataValue(entity, key)
    if Gridorius.metadata[entity.unit_number] then
        Gridorius.metadata[entity.unit_number][key] = nil
    end
end

function Gridorius.AddMetadata(entity, metadata)
    if not Gridorius.metadata[entity.unit_number] then
        Gridorius.metadata[entity.unit_number] = {}
    end
    for key, value in pairs(metadata) do
        Gridorius.metadata[entity.unit_number][key] = value
    end
end

function Gridorius.GetMetadata(entity, default)
    if not Gridorius.metadata[entity.unit_number] and default then
        Gridorius.metadata[entity.unit_number] = default
    end
    return Gridorius.metadata[entity.unit_number]
end

function Gridorius.RemoveMetadata(entity)
    Gridorius.metadata[entity.unit_number] = nil
end

function Gridorius.FixMetadata()
    if Gridorius.metadata then
        local valid_metadata = {}
        for unit_number, metadata in pairs(Gridorius.metadata) do
            local entity = game.get_entity_by_unit_number(unit_number)
            if entity and entity.valid then
                valid_metadata[unit_number] = metadata
            end
        end
        Gridorius.metadata = valid_metadata
    end
end

local IngameState = require("scripts.lib.ingame_state")
Gridorius.state = IngameState:new()

local VirtualInventory = require("scripts.lib.virtual_inventory")
Gridorius.VirtualInventory = VirtualInventory

local InterfaceBuilder = require("scripts.lib.interface_builder")
Gridorius.InterfaceBuilder = InterfaceBuilder

local CombinedInventory = require("scripts.lib.combined_inventory")
Gridorius.CombinedInventory = CombinedInventory

local Gui = require("scripts.lib.gui")
function Gridorius:InitGui()
    self.Gui = Gui:new()
end

function Gridorius.GetSortedKeys(values)
    local keys = {}
    for key, value in pairs(values or {}) do
        if value ~= nil then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    return keys
end

function Gridorius.GetSortedValues(values)
    local result = {}
    local keys = Gridorius.GetSortedKeys(values)
    for i = 1, #keys do
        result[i] = values[keys[i]]
    end
    return result
end
