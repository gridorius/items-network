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

    self.servers = storage.servers
    self.renders = {}
    self.server_render = nil


    self.selected_handler_id = Gridorius.Events:On(defines.events.on_selected_entity_changed, function(event)
        if not self.storage.use_energy then
            return
        end
        local player = game.get_player(event.player_index)
        local selected = player and player.selected
        if selected and self.storage.server and selected.unit_number == self.storage.server.unit_number then
            self:RenderRadius(80, { 0.07165, 0.16, 0.03665, 0.1 })
            self:RenderRadius(150, { 0.15, 0.12165, 0.02165, 0.1 })
            self:RenderRadius(200, { 0.13, 0.04835, 0.00665, 0.1 })
            self:RenderRadius(250, { 0.145, 0, 0, 0.1 })
        elseif #self.renders > 0 then
            for _, render in pairs(self.renders) do
                render.destroy()
            end
            self.renders = {}
        end
    end)

    return self
end

function Network:RenderRadius(radius, color)
    local radius_game = rendering.draw_circle {
        color = color,
        radius = radius,
        target = self.storage.server,
        surface = self.storage.server.surface,
        filled = true,
        draw_on_ground = true,
    }

    local radius_chart = rendering.draw_circle {
        color = color,
        radius = radius,
        target = self.storage.server,
        surface = self.storage.server.surface,
        filled = true,
        render_mode = "chart"
    }

    table.insert(self.renders, radius_game)
    table.insert(self.renders, radius_chart)
end

function Network:Destroy()
    for _, render in pairs(self.renders) do
        render.destroy()
    end
    Gridorius.Events:Remove(self.selected_handler_id)
    storage.networks[self.id] = nil
    self.inventory:Destroy()
    game.print("Network " .. self.id .. " destroyed")
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
    local filters = self.inventory:GetSignalFilters()
    for _, terminal in ipairs(terminals) do
        if terminal and terminal.valid then
            local control = terminal.get_or_create_control_behavior()
            if control and control.valid then
                control.get_section(1).filters = filters
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

    local entity_data_by_unit = self.storage.typed_entities[type] or {}
    local unit_numbers = Gridorius.GetSortedKeys(entity_data_by_unit)
    for i = 1, #unit_numbers do
        local entity_data = entity_data_by_unit[unit_numbers[i]]
        if entity_data and (not distribute_index or entity_data.distribute_index == distribute_index) then
            result[#result + 1] = entity_data.entity
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

function Network:OnChangeSettings()
    self.storage.distribute_index = 1
    self.storage.distribute_current = settings.global.network_machines_per_tick.value
    self.storage.use_energy = settings.global.use_energy.value

    local entities = Gridorius.GetSortedValues(self.entities)
    for i = 1, #entities do
        local entity_data = entities[i]
        if entity_data and entity_data.entity and entity_data.entity.valid then
            if Constants.DISTRIBUTABLE_TYPES[entity_data.type] then
                entity_data.distribute_index = self:GetDistributeIndex()
            end
        end
    end
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

function Network:VatToJoules(v)
    return math.floor(v / 60)
end

function Network:CalculateUsage(entity)
    local server = self.storage.server
    local depth = math.sqrt((entity.position.x - server.position.x) ^ 2 + (entity.position.y - server.position.y) ^ 2)
    if depth <= 80 then
        return Network:VatToJoules(2000)
    elseif depth <= 150 then
        return Network:VatToJoules(4000)
    elseif depth <= 200 then
        return Network:VatToJoules(16000)
    elseif depth <= 250 then
        return depth * 8
    else
        return depth * 100
    end
end

function Network:UpdateServerRender(server, active)
    if active and self.server_render then
        self.server_render.destroy()
        self.server_render = nil
    end

    if not active and not self.server_render then
        self.server_render = rendering.draw_text {
            color = { 1, 0, 0 },
            target = { server.position.x - 1, server.position.y },
            surface = server.surface,
            text = "NO POWER"
        }
    end
end

function Network:AttachEntities(server, entities)
    self:ResetEntities()
    self.storage.server = server
    local ordered_entities = Gridorius.GetSortedValues(entities)
    for i = 1, #ordered_entities do
        self:AttachEntity(ordered_entities[i])
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

    self.storage.typed_entities[type] = self.storage.typed_entities[type] or {}
    self.entities[entity.unit_number] = {
        entity = entity,
        type = type
    }

    self.storage.typed_entities[type][entity.unit_number] = self.entities[entity.unit_number]

    if Constants.CABLE_ENTITIES[entity.name] then
        self.power_usage = self.power_usage + self:CalculateUsage(entity)
    end

    -- if Constants.ABSORBABLE_CHEST_TYPES[entity.type] then
    -- self.storage.inventories[entity.unit_number] = entity.get_inventory(defines.inventory.chest)
    -- self.combined_inventory:AddInventory(self.storage.inventories[entity.unit_number])
    -- end

    if Constants.DISTRIBUTABLE_TYPES[self.entities[entity.unit_number].type] then
        self.entities[entity.unit_number].distribute_index = self:GetDistributeIndex()
    end
end

function Network:ProcessPlayers()
    if not game.forces.player.technologies['network-player-supply'].researched then
        return
    end

    for i = 1, #game.players do
        local player = game.players[i]
        if player and player.valid and player.surface.index == self.storage.server.surface.index then
            self.inventory:ProcessPlayer(player)
        end
    end
end

function Network:OnTick()
    if not self.storage.server or not self.storage.server.valid then
        return
    end
    local interface = self.servers[self.storage.server.unit_number].energy_interface
    if Gridorius.nth_tick(60) then
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

    if self.storage.use_energy and interface.energy == 0 then
        self.working = false
        self:UpdateServerRender(self.storage.server, false)
        return
    end
    self.working = true
    self:UpdateServerRender(self.storage.server, true)

    if Gridorius.nth_tick(60) then
        self:SetTerminalsSignals()
        self:ProcessTurrets()
        self:ProcessProductionCombinators()
        self:ProcessPlayers()
    end

    local distribute_max = self.storage.distribute_index + 1

    if distribute_max < 30 then
        distribute_max = 30
    end

    local distribute_index = game.tick % distribute_max
    self:CollectChests(distribute_index)
    self:CollectFluidInputs(distribute_index)
    self:FillFluidOutputs(distribute_index)
    self:ProcessMachinesItems(distribute_index)
    self:ProcessMachinesFluids(distribute_index)
    self:ProcessInserters(distribute_index)
    self:ProcessBufferChests(distribute_index)
    self:ProcessUnloadTrainStops(distribute_index)
end

function Network:ProcessUnloadTrainStops(distribute_index)
    local train_stops = self:GetTypeEntities(Constants.TYPE.UNLOADING_TRAIN_STOP, distribute_index)
    for _, train_stop in ipairs(train_stops) do
        if train_stop and train_stop.valid then
            self.inventory:ProcessUnloadingTrainStop(train_stop, self.storage.use_fuels)
        end
    end
end

function Network:GetInserterFilters(inserter)
    local filters = {}
    if not (inserter and inserter.valid and inserter.filter_slot_count and inserter.filter_slot_count > 0) then
        return filters
    end

    for slot = 1, inserter.filter_slot_count do
        local filter = inserter.get_filter(slot)
        if filter then
            local filter_data = nil
            if type(filter) == "table" then
                if filter.name then
                    filter_data = {
                        name = filter.name,
                        quality = filter.quality or "normal",
                    }
                elseif filter.value and filter.value.name then
                    filter_data = {
                        name = filter.value.name,
                        quality = filter.value.quality or "normal",
                    }
                end
            else
                filter_data = {
                    name = filter,
                    quality = "normal",
                }
            end

            if filter_data then
                filters[#filters + 1] = filter_data
            end
        end
    end

    return filters
end

function Network:ProcessInserter(inserter)
    if not (inserter and inserter.valid) then
        return
    end

    local filters = self:GetInserterFilters(inserter)
    if #filters == 0 then
        return
    end

    local filter = filters[1]
    if prototypes.item[filter.name] then
        if prototypes.item[filter.name] then
            local inserter_stack = inserter.held_stack
            local stack_size = inserter.inserter_target_pickup_count;
            if inserter_stack.valid_for_read then
                local stack_quality = "normal"
                if inserter_stack.quality then
                    stack_quality = inserter_stack.quality.name
                end
                if inserter_stack.name == filter.name and stack_quality == filter.quality then
                    local to_move = stack_size - inserter_stack.count
                    if to_move > 0 then
                        local removed = self.inventory:RemoveItem(filter.name, to_move, filter.quality)
                        if removed > 0 then
                            inserter_stack.count = inserter_stack.count + removed
                        end
                    end
                else
                    self.inventory:InsertItem(inserter_stack.name, inserter_stack.count, stack_quality)
                    local removed = self.inventory:RemoveItem(filter.name, stack_size, filter.quality)
                    if removed > 0 then
                        inserter_stack.set_stack({ name = filter.name, count = removed, quality = filter.quality })
                    end
                end
            else
                local removed = self.inventory:RemoveItem(filter.name, stack_size, filter.quality)
                if removed > 0 then
                    inserter_stack.set_stack({ name = filter.name, count = removed, quality = filter.quality })
                end
            end
        end
    end
end

function Network:ProcessInserters(distribute_index)
    local inserters = self:GetTypeEntities(Constants.TYPE.INSERTER, distribute_index)
    for _, inserter in ipairs(inserters) do
        self:ProcessInserter(inserter)
    end
end

function Network:ProcessProductionCombinators()
    local combinators = self:GetTypeEntities(Constants.TYPE.PRODUCTION_COMBINATOR)
    for _, combinator in ipairs(combinators) do
        if combinator and combinator.valid then
            local control = combinator.get_or_create_control_behavior()
            local signals = {}
            local production = Gridorius.GetMetadata(combinator, {
                production = {}
            }).production

            local production_indexes = Gridorius.GetSortedKeys(production)
            for i = 1, #production_indexes do
                local prod = production[production_indexes[i]]
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
    for _, turret in ipairs(turrets) do
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

    for _, machine in ipairs(machines) do
        -- self.combined_inventory:ProcessMachineItems(machine, self.storage.use_fuels)
        self.inventory:ProcessMachineItems(machine, self.storage.use_fuels)
    end
end

function Network:ProcessMachinesFluids(distribute_index)
    local machines = self:GetTypeEntities(Constants.TYPE.MACHINE, distribute_index)

    for _, machine in ipairs(machines) do
        self.inventory:ProcessMachineFluids(machine)
    end
end

function Network:CollectChests(distribute_index)
    local chests = self:GetTypeEntities(Constants.TYPE.CHEST, distribute_index)
    for _, chest in ipairs(chests) do
        if chest and chest.valid then
            self.inventory:CollectInventory(chest.get_inventory(defines.inventory.chest))
        end
    end
end

function Network:FillFluidOutputs(distribute_index)
    local output_pipes = self:GetTypeEntities(Constants.TYPE.FLUID_OUTPUT, distribute_index)
    for _, pipe in ipairs(output_pipes) do
        if pipe and pipe.valid then
            local pipe_data = Gridorius.GetMetadata(pipe)
            if pipe_data and pipe_data.fluid_name and pipe_data.temperature then
                local inventory_amount = self.inventory:GetFluidAmount(pipe_data.fluid_name, pipe_data.temperature)

                local need_collect = false
                for i = 1, pipe.fluids_count do
                    local fluid = pipe.get_fluid(i)
                    local needed_temperature = pipe_data.temperature == "default" and
                        self.inventory.fluids[pipe_data.fluid_name].default_temperature or pipe_data.temperature
                    if fluid and fluid.name and (fluid.name ~= pipe_data.fluid_name or fluid.temperature ~= needed_temperature) then
                        need_collect = true
                        break
                    end
                end

                if need_collect then
                    self.inventory:CollectFluidbox(pipe)
                end

                local temperature = pipe_data.temperature == "default" and
                    self.inventory.fluids[pipe_data.fluid_name].default_temperature or pipe_data.temperature

                local inserted = Gridorius.insert_fluid_segments(pipe,
                    { name = pipe_data.fluid_name, temperature = temperature }, 1,
                    inventory_amount)
                if inserted > 0 then
                    self.inventory:RemoveFluid(pipe_data.fluid_name, inserted, pipe_data.temperature)
                end
            end
        end
    end
end

function Network:CollectFluidInputs(distribute_index)
    local input_pipes = self:GetTypeEntities(Constants.TYPE.FLUID_INPUT, distribute_index)
    for _, pipe in ipairs(input_pipes) do
        if pipe and pipe.valid then
            self.inventory:CollectFluidbox(pipe)
        end
    end
end

function Network:ProcessBufferChests(distribute_index)
    local buffer_chests = self:GetTypeEntities(Constants.TYPE.BUFFER_CHEST, distribute_index)
    for _, chest in ipairs(buffer_chests) do
        if chest and chest.valid then
            self.inventory:ProcessBufferChest(chest)
        end
    end
end

return Network
