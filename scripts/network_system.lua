local Network = require("scripts.network")
local Constants = require("scripts.constants")
local function get_entity_from_event(event)
    return event.entity or event.created_entity or event.destination
end

local NetworkSystem = {}
NetworkSystem.__index = NetworkSystem

function NetworkSystem:new()
    local self = setmetatable({}, NetworkSystem)
    storage.servers = storage.servers or {}
    storage.networks = storage.networks or {}
    storage.connectors = storage.connectors or {}
    storage.connector_entity = storage.connector_entity or {}
    storage.power_poles = storage.power_poles or {}
    storage.next_network_id = storage.next_network_id or 1
    storage.network_entities = storage.network_entities or {}

    self.networks = {}
    self.networks_changed = {}
    self.rebuild_delay = 0

    self:InitNetworks()
    self:RebuildConnectors()
    self:RebuildPowerPoles()
    for _, surface in pairs(game.surfaces) do
        self:RebuildAllNetworks(surface.index)
    end
    Gridorius.Events:On(Constants.BUILD_EVENTS, function(event) self:HandleBuildEntity(event) end)
    Gridorius.Events:On(Constants.MINING_EVENTS, function(event) self:HandleMineEntity(event) end)
    Gridorius.Events:On(defines.events.on_research_finished, function(event)
        self:HandleResearchFinished(event)
    end)
    Gridorius.Events:OnNthTick(1, function(event) self:HandleTick(event) end)
    Gridorius.Events:On(defines.events.on_runtime_mod_setting_changed, function(event)
        if event.setting == "network_machines_per_tick" then
            for _, surface in pairs(game.surfaces) do
                self:RebuildAllNetworks(surface.index)
            end
        end
    end)
    return self
end

function NetworkSystem:GetNextNetworkId()
    local next_id = storage.next_network_id
    storage.next_network_id = storage.next_network_id + 1
    return next_id
end

function NetworkSystem:InitNetworks()
    for network_id, network_data in pairs(storage.networks) do
        self.networks[network_id] = Network:new(network_id)
    end
end

function NetworkSystem:ClearInvalidEntities()
    for unit_number, entity_data in pairs(storage.network_entities) do
        if not entity_data.entity or not entity_data.entity.valid then
            storage.network_entities[unit_number] = nil
        end
    end
end

function NetworkSystem:MarkAsChanged(surface_id)
    self.networks_changed[surface_id] = true
    self.rebuild_delay = Constants.REBUILD_DELAY
end

function NetworkSystem:CreateConnector(entity, x, y)
    return entity.surface.create_entity {
        name = Constants.CONNECTOR_NAME,
        position = { x = x, y = y },
        force = entity.force
    }
end

function NetworkSystem:GetConnectorPositions(entity)
    local h2 = entity.tile_height / 2
    local w2 = entity.tile_width / 2

    if entity.tile_height == 1 and entity.tile_width == 1 then
        return {
            { x = entity.position.x, y = entity.position.y }
        }
    end

    return {
        { x = entity.position.x - w2,       y = entity.position.y - h2 },
        { x = entity.position.x + w2 - 0.5, y = entity.position.y + h2 - 0.5 }
    }
end

function NetworkSystem:CreatePowerPole(entity)
    local pole = entity.surface.create_entity {
        name = Constants.HIDDEN_POWER_POLE_NAME,
        position = { x = entity.position.x, y = entity.position.y },
        force = entity.force
    }
    storage.power_poles[entity.unit_number] = pole
end

function NetworkSystem:IsPowerConductivityUnlocked(force)
    if not force or not force.valid then
        return false
    end

    local technology = force.technologies[Constants.POWER_TECH_NAME]
    return technology and technology.researched or false
end

function NetworkSystem:GetNetworkByEntity(entity)
    if not entity or not entity.valid then
        return nil
    end

    for _, network in pairs(self.networks) do
        if network:ContainsEntity(entity) then
            return network
        end
    end

    return nil
end

function NetworkSystem:CreateConnectors(entity)
    local connectors = {}

    for _, position in pairs(self:GetConnectorPositions(entity)) do
        local connector = self:CreateConnector(entity, position.x, position.y)
        if connector and connector.valid then
            table.insert(connectors, connector)

            if self:IsPowerConductivityUnlocked(entity.force) then
                self:CreatePowerPole(connector)
            end
        end
    end

    storage.connectors[entity.unit_number] = connectors

    for _, connector in pairs(connectors) do
        if connector and connector.valid then
            storage.connector_entity[connector.unit_number] = entity
        end
    end
end

function NetworkSystem:RemovePowerPole(entity)
    if storage.power_poles and storage.power_poles[entity.unit_number] then
        local pole = storage.power_poles[entity.unit_number]
        if pole and pole.valid then
            pole.destroy()
        end
        storage.power_poles[entity.unit_number] = nil
    end
end

function NetworkSystem:RemoveConnectors(entity)
    if storage.connectors and storage.connectors[entity.unit_number] then
        for _, connector in pairs(storage.connectors[entity.unit_number]) do
            if connector and connector.valid then
                self:RemovePowerPole(connector)
                storage.connector_entity[connector.unit_number] = nil
                if connector and connector.valid then
                    connector.destroy()
                end
            end
        end
        storage.connectors[entity.unit_number] = nil
    end
end

function NetworkSystem:SearchNetworkByConnectors(entity)
    local connectors = storage.connectors and storage.connectors[entity.unit_number]
    if connectors then
        for _, connector in pairs(connectors) do
            if connector and connector.valid then
                for _, neighbor in pairs(connector.heat_neighbours) do
                    if neighbor and neighbor.valid then
                        local network = self:GetNetworkByEntity(neighbor)
                        if network then
                            return network
                        end
                    end
                end
            end
        end
    end
    return nil
end

function NetworkSystem:TryAttachToNetwork(entity)
    local network = self:SearchNetworkByConnectors(entity)
    if network then
        network:AttachEntity(entity)
    end
    return false
end

function NetworkSystem:IsSupportedEntity(entity)
    if not entity or not entity.valid then
        return false
    end

    return Constants.MACHINE_TYPES[entity.type] or Constants.ABSORBABLE_CHEST_TYPES[entity.type] or
        Constants.SUPPORTED_ENTITIES[entity.name] or false
end

function NetworkSystem:IsEntityWithConnector(entity)
    if not entity or not entity.valid then
        return false
    end

    return Constants.MACHINE_TYPES[entity.type] or Constants.ABSORBABLE_CHEST_TYPES[entity.type] or
        Constants.ENTITIES_WITH_CONNECTORS[entity.name] or false
end

function NetworkSystem:IsEntityWithPowerPole(entity)
    if not entity or not entity.valid then
        return false
    end

    return Constants.ENTITIES_WITH_POWER_POLES[entity.name] or false
end

function NetworkSystem:RebuildConnectors()
    storage.connectors = {}
    storage.connector_entity = {}
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered { name = { Constants.CONNECTOR_NAME } }) do
            entity.destroy()
        end
        for _, entity in pairs(surface.find_entities_filtered { name = { Constants.TERMINAL_NAME, Constants.BUFFER_CHEST_NAME, Constants.FLUID_INPUT, Constants.FLUID_OUTPUT } }) do
            self:CreateConnectors(entity)
        end
        for _, entity in pairs(surface.find_entities_filtered { type = Gridorius.Dictionary:new(Constants.MACHINE_TYPES):Keys() }) do
            self:CreateConnectors(entity)
        end
        for _, entity in pairs(surface.find_entities_filtered { type = Gridorius.Dictionary:new(Constants.ABSORBABLE_CHEST_TYPES):Keys() }) do
            self:CreateConnectors(entity)
        end
    end
end

function NetworkSystem:RebuildPowerPoles()
    storage.power_poles = {}

    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered { name = { Constants.HIDDEN_POWER_POLE_NAME } }) do
            entity.destroy()
        end

        for _, entity in pairs(surface.find_entities_filtered {
            name = Gridorius.Dictionary:new(Constants.ENTITIES_WITH_POWER_POLES):Keys()
        }) do
            if self:IsPowerConductivityUnlocked(entity.force) then
                self:CreatePowerPole(entity)
            end
        end
    end
end

function NetworkSystem:RebuildAllNetworks(surface_index)
    local surface_servers = {}
    for _, server in pairs(storage.servers) do
        if server.entity and server.entity.valid and (not surface_index or server.entity.surface.index == surface_index) then
            table.insert(surface_servers, server)
        end
    end

    for _, server in pairs(surface_servers) do
        if server.entity and server.entity.valid then
            self:BuildNetwork(server.entity)
        end
    end
end

function NetworkSystem:ConnectNeighbor(network, entity, visited)
    visited = visited or {}
    if visited[entity.unit_number] then
        return
    end
    visited[entity.unit_number] = true
    if entity.name == Constants.CABLE_NAME then
        network:AttachEntity(entity)
        -- self:ConnectNeighbor(network, entity, visited)
    end
    if entity.name == Constants.CONNECTOR_NAME then
        local connected_entity = storage.connector_entity and storage.connector_entity[entity.unit_number]
        if connected_entity and connected_entity.valid then
            network:AttachEntity(connected_entity)
        end
    end

    for _, neighbor in pairs(entity.heat_neighbours) do
        if neighbor and neighbor.valid then
            self:ConnectNeighbor(network, neighbor, visited)
        end
    end
end

function NetworkSystem:DestroyInvalidConnections(network)
    local servers = Gridorius.Dictionary:new(network:GetTypeEntities(Constants.TYPE.SERVER))
    if servers:Count() > 1 then
        servers:ForEach(function(server)
            local server_connectors = storage.connectors and storage.connectors[server.unit_number]
            if not server_connectors then
                return
            end
            for _, connector in pairs(server_connectors) do
                if connector and connector.valid then
                    for _, neighbor in pairs(connector.heat_neighbours) do
                        if neighbor and neighbor.valid and neighbor.name == Constants.CABLE_NAME then
                            neighbor.surface.spill_item_stack {
                                position = neighbor.position,
                                stack = { name = neighbor.name, count = 1 }
                            }
                            neighbor.destroy()
                            game.print({
                                "message.items-network-invalid-connection-destroyed",
                                math.floor(neighbor.position.x),
                                math.floor(neighbor.position.y)
                            })
                        end
                    end
                end
            end
        end)

        servers:ForEach(function(server)
            self:BuildNetwork(server)
        end)
    end
end

function NetworkSystem:BuildNetwork(server)
    local network_id = storage.servers[server.unit_number] and storage.servers[server.unit_number].network_id
    local network = network_id and self.networks[network_id]

    if not network then
        network_id = self:GetNextNetworkId()
        network = Network:new(network_id)
        self.networks[network_id] = network
        storage.servers[server.unit_number].network_id = network_id
    end

    if network then
        network:ResetEntities()
        local connectors = storage.connectors and storage.connectors[server.unit_number]
        local visited = {}
        for _, connector in pairs(connectors) do
            if connector and connector.valid then
                self:ConnectNeighbor(network, connector, visited)
            end
        end

        self:DestroyInvalidConnections(network)
        return network_id
    end
    return nil
end

--#region Event Handlers

function NetworkSystem:HandleBuildEntity(event)
    local entity = get_entity_from_event(event)
    if not self:IsSupportedEntity(entity) then
        return
    end

    if self:IsEntityWithPowerPole(entity) and self:IsPowerConductivityUnlocked(entity.force) then
        self:CreatePowerPole(entity)
    end

    if self:IsEntityWithConnector(entity) then
        self:CreateConnectors(entity)
    end

    if entity.name == Constants.SERVER_NAME then
        local network = self:SearchNetworkByConnectors(entity)
        if network then
            local inserted = 0
            local player = event.player_index and game.get_player(event.player_index)
            if player and player.valid then
                inserted = player.insert { name = entity.name, count = 1 }
            end

            if inserted == 0 then
                entity.surface.spill_item_stack {
                    position = entity.position,
                    stack = { name = entity.name, count = 1 }
                }
            end

            self:RemoveConnectors(entity)
            self:RemovePowerPole(entity)
            entity.destroy()
            game.print({ "message.items-network-server-already-connected" })
            return
        end

        storage.servers[entity.unit_number] = {
            entity = entity,
            network_id = nil
        }

        local new_network_id = self:BuildNetwork(entity)
        game.print({ "message.items-network-built-network", new_network_id })
        return
    end

    if not self:TryAttachToNetwork(entity) then
        self:MarkAsChanged(entity.surface.index)
    end
end

function NetworkSystem:HandleMineEntity(event)
    local entity = get_entity_from_event(event)
    if not self:IsSupportedEntity(entity) then
        return
    end

    if self:IsEntityWithConnector(entity) then
        self:RemoveConnectors(entity)
    end

    if self:IsEntityWithPowerPole(entity) then
        self:RemovePowerPole(entity)
    end

    if entity.name == Constants.SERVER_NAME then
        storage.servers[entity.unit_number] = nil
    end

    self:MarkAsChanged(entity.surface.index)
end

function NetworkSystem:HandleTick(event)
    if Gridorius.nth_tick(120) then
        self:ClearInvalidEntities()
    end

    for surface_index, changed in pairs(self.networks_changed) do
        if changed then
            if self.rebuild_delay > 0 then
                self.rebuild_delay = self.rebuild_delay - 1
            else
                self:RebuildAllNetworks(surface_index)
                self.networks_changed[surface_index] = false
            end
        end
    end

    for _, network in pairs(self.networks) do
        network:OnTick()
    end
end

function NetworkSystem:HandleResearchFinished(event)
    if not event.research or event.research.name ~= Constants.POWER_TECH_NAME then
        return
    end

    self:RebuildPowerPoles()
end

--#endregion

return NetworkSystem
