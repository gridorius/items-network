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
    storage.power_poles = storage.power_poles or {}
    storage.next_network_id = storage.next_network_id or 1

    self.networks = {}
    self.networks_changed = {}
    self.rebuild_delay = 0

    rendering.clear("items-network")
    -- todo: old compatible
    self:ForceSetServersMinable()

    self:InitNetworks()
    self:RebuildEnergyInterfaces()
    self:RebuildPowerPoles()
    for _, surface in pairs(game.surfaces) do
        self:RebuildSurfaceNetworks(surface.index)
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
                self:RebuildSurfaceNetworks(surface.index)
            end
        elseif event.setting == "fill_turret_ammo" then
            for _, surface in pairs(game.surfaces) do
                self:RebuildSurfaceNetworks(surface.index)
            end
        elseif event.setting == "use_energy" then
            for _, surface in pairs(game.surfaces) do
                self:RebuildSurfaceNetworks(surface.index)
            end
        end
    end)
    return self
end

function NetworkSystem:ForceSetServersMinable()
    for _, surface in pairs(game.surfaces) do
        for _, server in pairs(surface.find_entities_filtered { name = Constants.SERVER_NAME }) do
            if server and server.valid then
                server.minable = true
            end
        end
    end
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

function NetworkSystem:MarkAsChanged(surface_id)
    self.networks_changed[surface_id] = true
    self.rebuild_delay = Constants.REBUILD_DELAY
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

    if Constants.TURRET_TYPES[entity.type] then
        if settings.global.fill_turret_ammo.value then
            return true
        else
            return false
        end
    end

    return Constants.MACHINE_TYPES[entity.type] or Constants.ABSORBABLE_CHEST_TYPES[entity.type] or
        Constants.SUPPORTED_ENTITIES[entity.name] or false
end

function NetworkSystem:IsEntityWithPowerPole(entity)
    if not entity or not entity.valid then
        return false
    end

    return Constants.CABLE_ENTITIES[entity.name] or false
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

function NetworkSystem:RebuildEnergyInterfaces()
    for _, surface in pairs(game.surfaces) do
        for _, interface in pairs(surface.find_entities_filtered { name = Constants.ENERGY_INTERFACE_NAME }) do
            if interface and interface.valid then
                interface.destroy()
            end
        end
    end
    for _, server_data in pairs(storage.servers) do
        if server_data and server_data.entity and server_data.entity.valid then
            server_data.energy_interface = self:CreateEnergyInterface(server_data.entity)
        end
    end
end

function NetworkSystem:RebuildPowerPoles()
    storage.power_poles = {}
    local cable_entities = Gridorius.Dictionary:new(Constants.CABLE_ENTITIES):Keys()
    for _, surface in pairs(game.surfaces) do
        local poles = surface.find_entities_filtered {
            name = Constants.HIDDEN_POWER_POLE_NAME
        }
        for _, pole in pairs(poles) do
            if pole and pole.valid then
                pole.destroy()
            end
        end
        for _, cable in pairs(surface.find_entities_filtered { name = cable_entities }) do
            if cable and cable.valid then
                self:CreatePowerPole(cable)
            end
        end
    end
end

function NetworkSystem:RebuildSurfaceNetworks(surface_index)
    local surface_servers = {}

    local connectors = game.surfaces[surface_index].find_entities_filtered {
        name = Constants.CONNECTOR_NAME
    }
    for _, connector in pairs(connectors) do
        if connector and connector.valid then
            local metadata = Gridorius.GetMetadata(connector)
            if metadata and metadata.render then
                metadata.render.color = { 0, 0, 1 }
            end
        end
    end

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

function NetworkSystem:GetNextUndergroundConnector(entity, visited)
    if not entity or not entity.valid or entity.name ~= Constants.UNDERGROUND_CABLE_NAME then
        return nil
    end

    for _, neighbors in pairs(entity.neighbours) do
        for _, neighbor in pairs(neighbors) do
            if neighbor and neighbor.valid and neighbor.name == Constants.UNDERGROUND_CABLE_NAME and neighbor.unit_number ~= entity.unit_number then
                local connector = storage.connectors and storage.connectors[neighbor.unit_number] and
                    storage.connectors[neighbor.unit_number][1]
                if connector and connector.valid and not visited[connector.unit_number] then
                    return connector
                end
            end
        end
    end

    return nil
end

function NetworkSystem:ConnectUndergroundPoles(connector1, connector2)
    local pole1 = storage.power_poles and storage.power_poles[connector1.unit_number]
    local pole2 = storage.power_poles and storage.power_poles[connector2.unit_number]

    if pole1 and pole1.valid and pole2 and pole2.valid then
        local wire_connector1 = pole1.get_wire_connector(defines.wire_connector_id.pole_copper)
        local wire_connector2 = pole2.get_wire_connector(defines.wire_connector_id.pole_copper)
        if wire_connector1 and wire_connector2 then
            wire_connector1.connect_to(wire_connector2, false)
        end
    end
end

function NetworkSystem:ConnectNeighbor(network, cables, visited, depth)
    depth = depth or 0
    visited = visited or {}
    local next = {}
    for _, cable in pairs(cables) do
        if Constants.CABLE_ENTITIES[cable.name] then
            if not visited[cable.unit_number] then
                visited[cable.unit_number] = true
                Gridorius.SetMetadataValue(cable, "depth", depth)
                network:AttachEntity(cable)
                self:Attach(network, cable)
                for _, neighbor in pairs(cable.heat_neighbours) do
                    if neighbor and neighbor.valid and Constants.CABLE_ENTITIES[neighbor.name] then
                        if not visited[neighbor.unit_number] then
                            table.insert(next, neighbor)
                        end
                    end
                end
            end
        end
    end

    if #next == 0 then
        return
    end
    self:ConnectNeighbor(network, next, visited, depth + 1)
end

function NetworkSystem:Attach(network, cable)
    if cable.name == Constants.CONNECTOR_NAME then
        local metadata = Gridorius.GetMetadata(cable)
        if metadata and metadata.connected then
            if metadata.connected.valid then
                network:AttachEntity(metadata.connected)
                local current_box = metadata.render
                if current_box then
                    current_box.color = { 0, 1, 0 }
                else
                    Gridorius.AddMetadata(cable, {
                        render = self:RenderConnectorIndicator(cable, { 0, 1, 0 }),
                    })
                end
            else
                Gridorius.AddMetadata(cable, {
                    connected = nil,
                    render = self:RenderConnectorIndicator(cable),
                })
            end
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

function NetworkSystem:GetConnectors(entity)
    return entity.surface.find_entities_filtered {
        area = entity.bounding_box,
        name = { Constants.CONNECTOR_NAME }
    }
end

function NetworkSystem:FindSupportedEntities(cable)
    local found_by_type = cable.surface.find_entities_filtered {
        area = cable.bounding_box,
        type = Constants.SUPPORTED_ENTITY_TYPES,
    }

    if #found_by_type > 0 then
        return found_by_type
    end

    local found_by_name = cable.surface.find_entities_filtered {
        area = cable.bounding_box,
        name = Constants.SUPPORTED_ENTITY_NAMES,
    }
    return found_by_name
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
        local connectors = self:GetConnectors(server)
        local visited = {}
        self:ConnectNeighbor(network, connectors, visited)

        return network_id
    end
    return nil
end

function NetworkSystem:RenderConnectorIndicator(entity, color)
    rendering.draw_rectangle {
        color = color or { 0, 0, 1 },
        left_top = { entity = entity, offset = { 0.3, 0.3 } },
        right_bottom = entity.selection_box.right_bottom,
        surface = entity.surface,
        position = entity.position,
        only_in_alt_mode = true,
        filled = true,
    }
end

function NetworkSystem:CreateEnergyInterface(server)
    if server and server.valid then
        return server.surface.create_entity {
            name = Constants.ENERGY_INTERFACE_NAME,
            position = { x = server.position.x, y = server.position.y },
            force = server.force
        }
    end
end

function NetworkSystem:DestroyServer(entity)
    local server = storage.servers[entity.unit_number]
    if server and server.energy_interface and server.energy_interface.valid then
        server.energy_interface.destroy()
    end
    if server and server.network_id then
        local network = self.networks[server.network_id]


        local chest = entity.surface.create_entity {
            name = Constants.NETWORK_STORAGE_CHEST_NAME,
            position = { x = entity.position.x, y = entity.position.y },
            force = entity.force
        }

        local inventory = chest.get_inventory(defines.inventory.chest)
        if inventory and inventory.valid then
            for name, tiers in pairs(network.inventory.items) do
                for tier, count in pairs(tiers) do
                    if count > 0 then
                        inventory.insert { name = name, quality = tier, count = count }
                    end
                end
            end
        end

        if network then
            network:Destroy()
            self.networks[server.network_id] = nil
        end
    end
    storage.servers[entity.unit_number] = nil
end

--#region Event Handlers

function NetworkSystem:HandleBuildEntity(event)
    local entity = get_entity_from_event(event)

    if not self:IsSupportedEntity(entity) then
        return
    end

    if (self:IsEntityWithPowerPole(entity)) then
        self:CreatePowerPole(entity)
    end

    if entity.name == Constants.CONNECTOR_NAME then
        local connected = self:FindSupportedEntities(entity)
        local metadata = {
            render = self:RenderConnectorIndicator(entity),
        }
        if #connected > 0 then
            metadata.connected = connected[1]
            self:MarkAsChanged(entity.surface.index)
        end
        Gridorius.AddMetadata(entity, metadata)
    else
        local connectors = self:GetConnectors(entity)
        if #connectors > 0 then
            for _, connector in pairs(connectors) do
                if connector and connector.valid then
                    Gridorius.SetMetadataValue(connector, "connected", entity)
                end
            end
            self:MarkAsChanged(entity.surface.index)
        end
    end

    if entity.name == Constants.CABLE_NAME then
        self:MarkAsChanged(entity.surface.index)
    end

    if entity.name == Constants.SERVER_NAME then
        storage.servers[entity.unit_number] = {
            entity = entity,
            network_id = nil,
            energy_interface = self:CreateEnergyInterface(entity),
        }

        local new_network_id = self:BuildNetwork(entity)
        game.print({ "message.items-network-built-network", new_network_id })
    end
end

function NetworkSystem:HandleMineEntity(event)
    local entity = get_entity_from_event(event)
    if not self:IsSupportedEntity(entity) then
        return
    end

    Gridorius.RemoveMetadata(entity)

    if (self:IsEntityWithPowerPole(entity)) then
        self:RemovePowerPole(entity)
    end

    if entity.name == Constants.SERVER_NAME then
        self:DestroyServer(entity)
    end

    self:MarkAsChanged(entity.surface.index)
end

function NetworkSystem:HandleTick(event)
    for surface_index, changed in pairs(self.networks_changed) do
        if changed then
            if self.rebuild_delay > 0 then
                self.rebuild_delay = self.rebuild_delay - 1
            else
                self:RebuildSurfaceNetworks(surface_index)
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
end

--#endregion

return NetworkSystem
