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

    self.storage.distribute_index = self.storage.distribute_index or 1
    self.storage.distribute_current = self.storage.distribute_current or settings.global.network_machines_per_tick.value

    return self
end

function Network:InitStorage(network_id)
    if not storage.networks[network_id] then
        storage.networks[network_id] = {
            entities = {},
            use_fuels = {},
            server = nil,
        }
    else
        storage.networks[network_id].server = storage.networks[network_id].server or nil
        storage.networks[network_id].entities = storage.networks[network_id].entities or {}
        storage.networks[network_id].use_fuels = storage.networks[network_id].use_fuels or {}
    end
end

function Network:UpdateSignals()
    self.signals = self.inventory:BuildSignals()
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
    for unit_number, entity_data in pairs(self.entities) do
        if entity_data.type == type then
            if distribute_index == nil or entity_data.distribute_index == distribute_index then
                result[unit_number] = entity_data.entity
            end
        end
    end
    return result
end

function Network:GetTypeEntitiesData(type, distribute_index)
    local result = {}
    for unit_number, entity_data in pairs(self.entities) do
        if entity_data.type == type then
            if distribute_index == nil or entity_data.distribute_index == distribute_index then
                result[unit_number] = entity_data
            end
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
    self.storage.distribute_index = 1
    self.storage.distribute_current = settings.global.network_machines_per_tick.value
    self.entities = self.storage.entities
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

function Network:AttachEntity(entity)
    if not entity or not entity.valid then
        return
    end

    if self.entities[entity.unit_number] then
        return
    end

    if storage.network_entities[entity.unit_number] then
        self.entities[entity.unit_number] = storage.network_entities[entity.unit_number]
    else
        self.entities[entity.unit_number] = {
            entity = entity,
            type = self:ResolveEntityType(entity)
        }
        storage.network_entities[entity.unit_number] = self.entities[entity.unit_number]
    end

    if self.entities[entity.unit_number].type == Constants.TYPE.MACHINE then
        self.entities[entity.unit_number].distribute_index = self:GetDistributeIndex()
    end
end

function Network:OnTick()
    if Gridorius.nth_tick(60) then
        self:CollectChests()
        self:UpdateSignals()
        self:SetTerminalsSignals()
        self:FillFluidOutputs()
        self:CollectFluidInputs()
        self:ProcessBufferChests()

        local servers = self:GetTypeEntities(Constants.TYPE.SERVER)
        if servers and next(servers) then
            for _, server in pairs(servers) do
                server.minable = self.inventory:IsEmpty()
            end
        end
    end

    local distribute_index = game.tick % (self.storage.distribute_index + 1)
    self:DistributeInventory(distribute_index)
end

function Network:DistributeInventory(distribute_index)
    local machines = self:GetTypeEntities(Constants.TYPE.MACHINE, distribute_index)

    for _, machine in pairs(machines) do
        self.inventory:ProcessMachine(machine, self.storage.use_fuels)
    end
end

function Network:CollectChests()
    local chests = self:GetTypeEntities(Constants.TYPE.CHEST)
    for _, chest in pairs(chests) do
        if chest and chest.valid then
            self.inventory:CollectInventory(chest.get_inventory(defines.inventory.chest))
        end
    end
end

function Network:FillFluidOutputs()
    local output_pipes_data = self:GetTypeEntitiesData(Constants.TYPE.FLUID_OUTPUT)
    for _, pipe_data in pairs(output_pipes_data) do
        local pipe = pipe_data.entity
        if pipe_data.fluid and pipe_data.temperature then
            local inventory_amount = self.inventory:GetFluidAmount(pipe_data.fluid, pipe_data.temperature)
            local fluidbox_wrapper = Gridorius.Fluidbox:new(pipe)

            local need_collect = false
            for name, temperatures in pairs(fluidbox_wrapper:GetFluids()) do
                for temp, amount in pairs(temperatures) do
                    if name ~= pipe_data.fluid or temp ~= pipe_data.temperature then
                        need_collect = true
                        break
                    end
                end
            end

            if need_collect then
                self.inventory:CollectFluidbox(pipe)
            end

            local filled_amount = fluidbox_wrapper:Insert(pipe_data.fluid, pipe_data.temperature, inventory_amount)
            self.inventory:RemoveFluid(pipe_data.fluid, filled_amount, pipe_data.temperature)
        end
    end
end

function Network:CollectFluidInputs()
    local input_pipes = self:GetTypeEntities(Constants.TYPE.FLUID_INPUT)
    for _, pipe in pairs(input_pipes) do
        if pipe and pipe.valid then
            self.inventory:CollectFluidbox(pipe)
        end
    end
end

function Network:ProcessBufferChests()
    local buffer_chests = self:GetTypeEntities(Constants.TYPE.BUFFER_CHEST)
    for _, chest in pairs(buffer_chests) do
        if chest and chest.valid then
            self.inventory:ProcessBufferChest(chest)
        end
    end
end

return Network
