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

local IngameState = require("scripts.lib.ingame_state")
Gridorius.state = IngameState:new()

local VirtualInventory = require("scripts.lib.virtual_inventory")
Gridorius.VirtualInventory = VirtualInventory

local InterfaceBuilder = require("scripts.lib.interface_builder")
Gridorius.InterfaceBuilder = InterfaceBuilder

local Gui = require("scripts.lib.gui")
Gridorius.Gui = Gui:new()
