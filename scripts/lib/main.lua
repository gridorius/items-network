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
    nth_tick = function(tick_num)
        return game.tick % tick_num == 0
    end
}

Gridorius.insert_fluid = function(fluidbox, fluid, index, max_insert)
    local current_fluid = fluidbox[index]
    local capacity = fluidbox.get_capacity(index)
    local to_insert = 0
    local new_amount = 0
    if current_fluid then
        to_insert = math.min(max_insert, capacity - (current_fluid.amount or 0))
        new_amount = current_fluid.amount + to_insert
    else
        to_insert = math.min(max_insert, capacity)
        new_amount = to_insert
    end

    if to_insert > 0 then
        fluidbox[index] = {
            name = fluid.name,
            amount = new_amount,
            temperature = fluid.temperature
        }
        return to_insert
    end
    return 0
end

function Gridorius.init()
    storage.metadata = storage.metadata or {}
    Gridorius.metadata = storage.metadata
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
        Gridorius.metadata[entity.unit_number] = default or {}
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

function Gridorius.split(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end
