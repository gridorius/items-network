Gridorius = {
    MergeProperties = function(base, additional)
        if additional and type(additional) == "table" then
            for key, value in pairs(additional) do
                base[key] = value
            end
        end

        return base
    end
}

local IngameState = require("scripts.lib.ingame_state")
Gridorius.state = IngameState:new()

local Fluidbox = require("scripts.lib.fluidbox")
Gridorius.Fluidbox = Fluidbox

local VirtualInventory = require("scripts.lib.virtual_inventory")
Gridorius.VirtualInventory = VirtualInventory

local InterfaceBuilder = require("scripts.lib.interface_builder")
Gridorius.InterfaceBuilder = InterfaceBuilder

local Gui = require("scripts.lib.gui")
Gridorius.Gui = Gui:new()