local Constants = require("scripts.constants")
local Network = {}
Network.__index = Network
function Network:new(network_id)
    local self = setmetatable({}, Network)
    self.id = network_id
    self:InitStorage(network_id)
    self.storage = storage.networks[network_id]
    self.entities = self.storage.entities
    self.inventory = Gridorius.VirtualInventory:new(network_id)
    self.signals = {}
    self.combined_inventory = Gridorius.CombinedInventory:new()
    self.limits = {}
    self.storage.distribute_index = self.storage.distribute_index or 1
    self.storage.distribute_current = self.storage.distribute_current or settings.global.network_machines_per_tick.value
    self.storage.use_energy = settings.global.use_energy.value
    self.power_usage = 50
    self.working = true

    return self
end

function Network:Destroy()
    storage.networks[self.id] = nil
    self.inventory:Destroy()
end

function Network:InitStorage(network_id)
    if not storage.networks[network_id] then
        storage.networks[network_id] = {
            entities = {},
            typed_entities = {},
            use_fuels = {},
            use_ammo = {},
            item_limits = {},
            server = nil,
            inventories = {}
        }
    else
        storage.networks[network_id].typed_entities = storage.networks[network_id].typed_entities or {}
        storage.networks[network_id].server = storage.networks[network_id].server or nil
        storage.networks[network_id].entities = storage.networks[network_id].entities or {}
        storage.networks[network_id].use_fuels = storage.networks[network_id].use_fuels or {}
        storage.networks[network_id].use_ammo = storage.networks[network_id].use_ammo or {}
        storage.networks[network_id].item_limits = storage.networks[network_id].item_limits or {}
        storage.networks[network_id].inventories = storage.networks[network_id].inventories or {}
    end
end

function Network:UpdateSignals()
    self.signals = self.inventory:BuildSignals()
end

function Network:CreateItemLimit()
    local new_limit = {
        item = nil,
        quality = "normal",
        limit = 10
    }
    table.insert(self.storage.item_limits, new_limit)
    return new_limit, #self.storage.item_limits
end

function Network:BuilLimits()
    local limits = {}
    for _, limit in pairs(self.storage.item_limits) do
        if not limits[limit.item] then
            limits[limit.item] = {}
        end
        limits[limit.item][limit.quality] = limit.limit
    end
    self.limits = limits
end

function Network:SetTerminalsSignals()
    local terminals = self:GetTypeEntities(Constants.TYPE.TERMINAL)
    for _, terminal in pairs(terminals) do
        if terminal and terminal.valid then
            local control = terminal.get_or_create_control_behavior()
            if control and control.valid then
                control.get_section(1).filters = self.signals
            end
        end
    end
end

function Network:ContainsEntity(entity)
    if not entity or not entity.valid then
        return false
    end

    return self.entities[entity.unit_number] ~= nil
end

function Network:GetTypeEntities(type, distribute_index)
    local result = {}
    for unit_number, entity_data in pairs(self.storage.typed_entities[type] or {}) do
        if distribute_index == nil or entity_data.distribute_index == distribute_index then
            result[unit_number] = entity_data.entity
        end
    end
    return result
end

function Network:GetTypeEntitiesData(type, distribute_index)
    if not distribute_index then
        return self.storage.typed_entities[type] or {}
    end

    local result = {}
    for unit_number, entity_data in pairs(self.storage.typed_entities[type] or {}) do
        if distribute_index == nil or entity_data.distribute_index == distribute_index then
            result[unit_number] = entity_data
        end
    end
    return result
end

function Network:GetEntityData(entity)
    if not entity or not entity.valid then
        return nil
    end

    return self.entities[entity.unit_number]
end

function Network:ResetEntities()
    self.storage.entities = {}
    self.storage.typed_entities = {}
    self.storage.distribute_index = 1
    self.storage.distribute_current = settings.global.network_machines_per_tick.value
    self.storage.use_energy = settings.global.use_energy.value
    self.storage.inventories = {}
    self.entities = self.storage.entities
    self.combined_inventory:Reset()
    self.power_usage = 50
end

function Network:ResolveEntityType(entity)
    if not entity or not entity.valid then
        return nil
    end
    if Constants.ENTITY_TYPES_MAP[entity.name] then
        return Constants.ENTITY_TYPES_MAP[entity.name]
    end
    if Constants.MACHINE_TYPES[entity.type] then
        return Constants.TYPE.MACHINE
    end
    if Constants.TURRET_TYPES[entity.type] then
        return Constants.TYPE.TURRET
    end
    if Constants.ABSORBABLE_CHEST_TYPES[entity.type] then
        return Constants.TYPE.CHEST
    end
    return Constants.TYPE.UNKNOWN
end

function Network:GetDistributeIndex()
    local index = self.storage.distribute_index
    if self.storage.distribute_current <= 0 then
        self.storage.distribute_index = self.storage.distribute_index + 1
        self.storage.distribute_current = settings.global.network_machines_per_tick.value
    end

    self.storage.distribute_current = self.storage.distribute_current - 1

    return index
end

function Network:CalculateUsage(depth)
    if depth <= 40 then
        return 50
    elseif depth <= 80 then
        return 200
    elseif depth <= 120 then
        return depth * 10
    else
        return depth * 100
    end
end

function Network:AttachEntity(entity)
    if not entity or not entity.valid then
        return
    end

    if self.entities[entity.unit_number] then
        return
    end

    local type = self:ResolveEntityType(entity)

    if not type then
        return
    end

    if type == Constants.TYPE.SERVER then
        self.storage.server = entity
    end

    self.storage.typed_entities[type] = self.storage.typed_entities[type] or {}

    if storage.network_entities[entity.unit_number] then
        self.entities[entity.unit_number] = storage.network_entities[entity.unit_number]
    else
        self.entities[entity.unit_number] = {
            entity = entity,
            type = type
        }
        storage.network_entities[entity.unit_number] = self.entities[entity.unit_number]
    end

    self.storage.typed_entities[type][entity.unit_number] = self.entities[entity.unit_number]

    if Constants.CABLE_ENTITIES[entity.name] then
        local depth = Gridorius.GetMetadata(entity).depth or 0
        self.power_usage = self.power_usage + self:CalculateUsage(depth)
    end

    if Constants.ABSORBABLE_CHEST_TYPES[entity.type] then
        self.storage.inventories[entity.unit_number] = entity.get_inventory(defines.inventory.chest)
        self.combined_inventory:AddInventory(self.storage.inventories[entity.unit_number])
    end

    if Constants.DISTRIBUTABLE_TYPES[self.entities[entity.unit_number].type] then
        self.entities[entity.unit_number].distribute_index = self:GetDistributeIndex()
    end
end

function Network:ProcessPlayers(server)
    if not game.forces.player.technologies['network-player-supply'].researched then
        return
    end

    for i = 1, #game.players do
        local player = game.players[i]
        if player and player.valid and player.surface.index == server.surface.index then
            self.inventory:ProcessPlayer(player)
        end
    end
end

function Network:OnTick()
    if not self.storage.server or not self.storage.server.valid then
        return
    end
    local interface = storage.servers[self.storage.server.unit_number].energy_interface
    if interface.energy == 0 then
        self.working = false
        return
    end
    self.working = true

    if Gridorius.nth_tick(60) then
        self:UpdateSignals()
        self:SetTerminalsSignals()
        self:ProcessTurrets()
        self:ProcessProductionCombinators()
        if interface and interface.valid then
            if self.storage.use_energy then
                interface.electric_buffer_size = self.power_usage
                interface.power_usage = self.power_usage
            else
                interface.electric_buffer_size = 0
                interface.power_usage = 0
            end
        end
    end

    if Gridorius.nth_tick(10) then
        self:ProcessProductionCombinators()
    end

    local distribute_index = game.tick % (self.storage.distribute_index + 1)
    self:CollectChests(distribute_index)
    self:CollectFluidInputs(distribute_index)
    self:FillFluidOutputs(distribute_index)
    self:ProcessMachinesItems(distribute_index)
    self:ProcessMachinesFluids(distribute_index)
    self:ProcessBufferChests(distribute_index)
end

function Network:ProcessProductionCombinators()
    local combinators = self:GetTypeEntities(Constants.TYPE.PRODUCTION_COMBINATOR)
    for _, combinator in pairs(combinators) do
        if combinator and combinator.valid then
            local control = combinator.get_or_create_control_behavior()
            local signals = {}
            local production = Gridorius.GetMetadata(combinator, {
                production = {}
            }).production

            for _, prod in pairs(production) do
                if prod.item then
                    local quality = prod.quality or "normal"
                    local inventory_amount = self.inventory:GetItemCount(prod.item, quality)
                    if inventory_amount < prod.limit then
                        table.insert(signals, {
                            value = {
                                type = "item",
                                name = prod.item,
                                quality = quality
                            },
                            min = prod.limit - inventory_amount,
                        })
                    end
                end
            end
            control.get_section(1).filters = signals
        end
    end
end

function Network:ProcessTurrets()
    local turrets = self:GetTypeEntities(Constants.TYPE.TURRET)
    for _, turret in pairs(turrets) do
        if turret and turret.valid then
            local inventory = nil
            if turret.type == Constants.AMMO_TURRET_TYPE then
                inventory = turret.get_inventory(defines.inventory.turret_ammo)
            elseif turret.type == Constants.ARTILLERY_TURRET_TYPE then
                inventory = turret.get_inventory(defines.inventory.artillery_turret_ammo)
            end
            if inventory then
                -- self.combined_inventory:ProcessTurret(inventory, self.storage.use_ammo)
                self.inventory:ProcessTurret(inventory, self.storage.use_ammo)
            end
        end
    end
end

function Network:ProcessMachinesItems(distribute_index)
    local machines = self:GetTypeEntities(Constants.TYPE.MACHINE, distribute_index)

    for _, machine in pairs(machines) do
        -- self.combined_inventory:ProcessMachineItems(machine, self.storage.use_fuels)
        self.inventory:ProcessMachineItems(machine, self.storage.use_fuels)
    end
end

function Network:ProcessMachinesFluids(distribute_index)
    local machines = self:GetTypeEntities(Constants.TYPE.MACHINE, distribute_index)

    for _, machine in pairs(machines) do
        self.inventory:ProcessMachineFluids(machine)
    end
end

function Network:CollectChests(distribute_index)
    local chests = self:GetTypeEntities(Constants.TYPE.CHEST, distribute_index)
    for _, chest in pairs(chests) do
        if chest and chest.valid then
            self.inventory:CollectInventory(chest.get_inventory(defines.inventory.chest))
        end
    end
end

function Network:FillFluidOutputs(distribute_index)
    local output_pipes_data = self:GetTypeEntitiesData(Constants.TYPE.FLUID_OUTPUT, distribute_index)
    for _, pipe_data in pairs(output_pipes_data) do
        if pipe_data.entity and pipe_data.entity.valid and pipe_data.fluid and pipe_data.temperature then
            local pipe = pipe_data.entity
            local inventory_amount = self.inventory:GetFluidAmount(pipe_data.fluid, pipe_data.temperature)

            local need_collect = false
            for i = 1, #pipe.fluidbox do
                local fluid = pipe.fluidbox[i]
                local needed_temperature = pipe_data.temperature == "default" and
                    self.inventory.fluids[pipe_data.fluid].default_temperature or pipe_data.temperature
                if fluid and fluid.name and (fluid.name ~= pipe_data.fluid or fluid.temperature ~= needed_temperature) then
                    need_collect = true
                    break
                end
            end

            if need_collect then
                self.inventory:CollectFluidbox(pipe)
            end

            local temperature = pipe_data.temperature == "default" and
                self.inventory.fluids[pipe_data.fluid].default_temperature or pipe_data.temperature

            local inserted = Gridorius.insert_fluid(pipe.fluidbox,
                { name = pipe_data.fluid, amount = inventory_amount, temperature = temperature }, 1, inventory_amount)
            if inserted > 0 then
                self.inventory:RemoveFluid(pipe_data.fluid, inserted, pipe_data.temperature)
            end
        end
    end
end

function Network:CollectFluidInputs(distribute_index)
    local input_pipes = self:GetTypeEntities(Constants.TYPE.FLUID_INPUT, distribute_index)
    for _, pipe in pairs(input_pipes) do
        if pipe and pipe.valid then
            self.inventory:CollectFluidbox(pipe)
        end
    end
end

function Network:ProcessBufferChests(distribute_index)
    local buffer_chests = self:GetTypeEntities(Constants.TYPE.BUFFER_CHEST, distribute_index)
    for _, chest in pairs(buffer_chests) do
        if chest and chest.valid then
            self.inventory:ProcessBufferChest(chest)
        end
    end
end

return Network
