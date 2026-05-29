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

    storage.cables = storage.cables or {}
    storage.cable_systems = storage.cable_systems or {}
    self.cables = storage.cables
    self.cable_systems = storage.cable_systems

    self.networks = {}

    rendering.clear("items-network")
    -- todo: old compatible
    self:ForceSetServersMinable()
    self:ReconnectConnectors()
    self:BuilCableSystems()
    self:InitNetworks()
    self:RebuildEnergyInterfaces()
    self:RebuildPowerPoles()
    self:RebuildAllSystems()
    Gridorius.Events:On(Constants.BUILD_EVENTS, function(event) self:HandleBuildEntity(event) end)
    Gridorius.Events:On(Constants.MINING_EVENTS, function(event) self:HandleMineEntity(event) end)
    Gridorius.Events:On(defines.events.on_research_finished, function(event)
        self:HandleResearchFinished(event)
    end)
    Gridorius.Events:OnNthTick(1, function(event) self:HandleTick(event) end)
    Gridorius.Events:On(defines.events.on_runtime_mod_setting_changed, function(event)
        if event.setting == "network_machines_per_tick" then
            for _, network in pairs(self.networks) do
                network:OnChangeSettings()
            end
        elseif event.setting == "use_energy" then
            for _, network in pairs(self.networks) do
                network:OnChangeSettings()
            end
        end
    end)

    return self
end

function NetworkSystem:RenderDebugCableSystem(cable, system_id)
    rendering.draw_text {
        text = system_id,
        surface = cable.surface,
        target = cable,
        color = { r = 1, g = 1, b = 1 },
        scale = 0.5,
        font = "default-game",
        time_to_live = 1000
    }
end

-- Обновить метаданные подключений коннекторов
function NetworkSystem:ReconnectConnectors()
    for _, surface in pairs(game.surfaces) do
        local connectors = surface.find_entities_filtered {
            name = Constants.CONNECTOR_NAME
        }
        for _, connector in pairs(connectors) do
            local connected = self:FindSupportedEntities(connector)
            local metadata = Gridorius.GetMetadata(connector, {})
            metadata.render = self:RenderConnectorIndicator(connector, { 0, 0, 1 })
            if #connected > 0 then
                metadata.connected = connected[1]
            else
                metadata.connected = nil
            end
        end
    end
end

-- Строит системы кабелей, если они еще не построены
function NetworkSystem:BuilCableSystems()
    local cable_entities = Gridorius.Dictionary:new(Constants.CABLE_ENTITIES):Keys()
    for _, surface in pairs(game.surfaces) do
        local cables = surface.find_entities_filtered {
            name = cable_entities
        }
        for _, cable in pairs(cables) do
            if not self.cables[cable.unit_number] then
                self:HandleNewCable(cable)
                -- self:RenderDebugCableSystem(cable, self.cables[cable.unit_number].system_id)
                -- else
                -- self:RenderDebugCableSystem(cable, self.cables[cable.unit_number].system_id)
            end
        end
    end
end

function NetworkSystem:RebuildAllSystems()
    for system_id, _ in pairs(storage.cable_systems) do
        self:RebuildSystemNetworks(system_id)
    end
end

-- Сливает несколько систем кабелей в одну, обновляя их идентификаторы и возвращая новый идентификатор системы
function NetworkSystem:MergeCableSystems(new_id, systems)
    local entities = {}
    for id, _ in pairs(systems) do
        if self.cable_systems[id] then
            for unit_number, cable in pairs(self.cable_systems[id]) do
                entities[unit_number] = cable
                self.cables[unit_number].system_id = new_id
            end
            self.cable_systems[id] = nil
        end
    end
    self.cable_systems[new_id] = entities
    return new_id
end

-- Добавляет кабель в систему, и ищет соседей и принадлежность к другим системам
function NetworkSystem:InitNewCable(cable, system_id, systems)
    self.cables[cable.unit_number] = {
        neighbours = {},
        system_id = system_id
    }
    local current_system_id = system_id
    local cable_data = self.cables[cable.unit_number]
    for _, neighbour in pairs(cable.heat_neighbours) do
        if neighbour.unit_number ~= cable.unit_number and Constants.CABLE_ENTITIES[neighbour.name] then
            cable_data.neighbours[neighbour.unit_number] = neighbour
            if self.cables[neighbour.unit_number] then
                local neighbour_data = self.cables[neighbour.unit_number]
                neighbour_data.neighbours[cable.unit_number] = cable
                if neighbour_data.system_id ~= current_system_id then
                    current_system_id = neighbour_data.system_id
                    systems[current_system_id] = true
                end
            end
        end
    end
end

-- Устанавливает систему для кабеля и добавляет его в систему
function NetworkSystem:SetCableSystem(cable, system_id)
    self.cables[cable.unit_number].system_id = system_id
    self.cable_systems[system_id][cable.unit_number] = cable
end

-- Обрабатывает добавление нового кабеля, определяя его систему и при необходимости сливая системы
function NetworkSystem:HandleNewCable(cable)
    local system_count = 0
    local system_id = cable.unit_number
    local systems = {}
    local first_system = nil

    self:InitNewCable(cable, system_id, systems)
    for id, _ in pairs(systems) do
        system_count = system_count + 1
        first_system = id
    end

    if system_count == 1 then
        self:SetCableSystem(cable, first_system)
        return first_system
    elseif system_count > 1 then
        self:SetCableSystem(cable, first_system)
        system_id = cable.unit_number;
        self:MergeCableSystems(system_id, systems)
        self:RebuildSystemNetworks(system_id)
        return system_id
    else
        self.cable_systems[system_id] = {
            [cable.unit_number] = cable
        }
        return system_id
    end
end

-- Обрабатывает удаление кабеля, удаляя его из системы и соседей
function NetworkSystem:HandleRemoveCable(cable)
    if self.cables[cable.unit_number] then
        for neighbour_unit_number, neighbour in pairs(self.cables[cable.unit_number].neighbours) do
            if self.cables[neighbour_unit_number] then
                self.cables[neighbour_unit_number].neighbours[cable.unit_number] = nil
            end
        end
        local system_id = self.cables[cable.unit_number].system_id;
        if self.cable_systems[system_id] then
            self.cable_systems[system_id][cable.unit_number] = nil
        end
        self.cables[cable.unit_number] = nil
    end
end

-- Пересчитывает систему кабелей после удаления кабеля, разделяя систему на несколько при необходимости
function NetworkSystem:RecalculateCableSystem(id)
    local system = self.cable_systems[id]
    if not system then
        return
    end
    local visited = {}
    local systems = {}
    for unit_number, cable in pairs(system) do
        if not visited[unit_number] then
            local new_system_id = cable.unit_number
            local system = {}
            self:ConnectCableSystem(cable, new_system_id, visited, system)
            systems[new_system_id] = system
        end
    end
    self.cable_systems[id] = nil
    for new_id, system in pairs(systems) do
        self.cable_systems[new_id] = system
        self:RebuildSystemNetworks(new_id)
    end
end

-- Рекурсивно подключает кабели к системе, обновляя их идентификаторы и добавляя в систему
function NetworkSystem:ConnectCableSystem(cable, system_id, visited, system)
    if not system then
        system = {}
    end
    -- self:RenderDebugCableSystem(cable, system_id)
    visited[cable.unit_number] = true
    system[cable.unit_number] = cable
    self.cables[cable.unit_number].system_id = system_id
    for neighbour_unit_number, neighbour in pairs(self.cables[cable.unit_number].neighbours) do
        if not visited[neighbour_unit_number] then
            self:ConnectCableSystem(neighbour, system_id, visited, system)
        end
    end
end

-- Принудительно устанавливает всем серверам возможность быть добытыми, чтобы игроки могли их перемещать после обновления
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

function NetworkSystem:CreatePowerPole(entity)
    if not self:IsPowerConductivityUnlocked(entity.force) then
        return
    end
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
            if cable and cable.valid and self:IsPowerConductivityUnlocked(cable.force) then
                self:CreatePowerPole(cable)
            end
        end
    end
end

-- Реконструирует сети, подключенные к системе кабелей, при изменении системы
function NetworkSystem:RebuildSystemNetworks(system_id)
    local system = storage.cable_systems[system_id]
    if not system then
        return
    end

    local connected = {}
    local server_connectors = {}
    local connectors = {}
    local servers = {}

    local has_invalids = false

    for unit_number, cable in pairs(system) do
        if cable.valid then
            connected[cable.unit_number] = cable
            if cable and cable.valid and cable.name == Constants.CONNECTOR_NAME then
                connectors[#connectors + 1] = cable
                local metadata = Gridorius.GetMetadata(cable)
                if metadata then
                    metadata.render.color = { 0, 0, 1 }
                    if metadata.connected and metadata.connected.valid then
                        if metadata.connected.name == Constants.SERVER_NAME then
                            servers[metadata.connected.unit_number] = metadata.connected
                            server_connectors[metadata.connected.unit_number] = cable
                        end
                        connected[metadata.connected.unit_number] = metadata.connected
                    end
                end
            end
        else
            has_invalids = true
            system[unit_number] = nil
            for un, value in pairs(self.cables[unit_number].neighbours) do
                self.cables[un].neighbours[unit_number] = nil
            end
        end
    end

    if has_invalids then
        self:RecalculateCableSystem(system_id)
        return
    end

    if next(servers) == nil then
        return
    end

    local main_network = nil
    local main_server = nil
    local server_unit_numbers = Gridorius.GetSortedKeys(servers)
    for i = 1, #server_unit_numbers do
        local server = servers[server_unit_numbers[i]]
        local network_id = storage.servers[server.unit_number].network_id
        local network = self.networks[network_id]
        if not main_network then
            main_network = network
            main_server = server
        else
            main_network.inventory:Merge(network.inventory)
            network:Destroy()
            self.networks[network_id] = nil
            storage.servers[server.unit_number] = nil
            server.destroy()
        end
    end

    if not main_network then
        return
    end


    for _, cable in pairs(connectors) do
        local metadata = Gridorius.GetMetadata(cable)
        if cable and cable.valid and cable.name == Constants.CONNECTOR_NAME and metadata.connected then
            metadata.render.color = { 0, 1, 0 }
        end
    end
    main_network:AttachEntities(main_server, connected)
end

function NetworkSystem:GetConnectors(entity)
    return entity.surface.find_entities_filtered {
        area = entity.bounding_box,
        name = { Constants.CONNECTOR_NAME }
    }
end

function NetworkSystem:FindSupportedEntities(cable)
    local found_by_name = cable.surface.find_entities_filtered {
        area = cable.bounding_box,
        name = Constants.SUPPORTED_ENTITY_NAMES,
    }

    if #found_by_name > 0 then
        return found_by_name
    end

    local found_by_type = cable.surface.find_entities_filtered {
        area = cable.bounding_box,
        type = Constants.SUPPORTED_ENTITY_TYPES,
    }

    return found_by_type
end

function NetworkSystem:CreateNetwork(server)
    local network_id = self:GetNextNetworkId()
    local network = Network:new(network_id)
    self.networks[network_id] = network
    storage.servers[server.unit_number].network_id = network_id
    return network_id
end

function NetworkSystem:BuildNetwork(server)
    local network_id = storage.servers[server.unit_number] and storage.servers[server.unit_number].network_id
    local network = network_id and self.networks[network_id]

    if not network then
        network_id = self:CreateNetwork(server)
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
    return rendering.draw_rectangle {
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
        if not network then
            storage.servers[entity.unit_number] = nil
            return
        end

        local chest = entity.surface.create_entity {
            name = Constants.NETWORK_STORAGE_CHEST_NAME,
            position = { x = entity.position.x, y = entity.position.y },
            force = entity.force
        }

        local inventory = chest.get_inventory(defines.inventory.chest)
        if inventory and inventory.valid then
            local item_names = {}
            for name, tiers in pairs(network.inventory.items) do
                if tiers then
                    item_names[#item_names + 1] = name
                end
            end
            table.sort(item_names)
            for i = 1, #item_names do
                local name = item_names[i]
                local tiers = network.inventory.items[name]
                local tier_names = {}
                for tier, count in pairs(tiers) do
                    if count and count > 0 then
                        tier_names[#tier_names + 1] = tier
                    end
                end
                table.sort(tier_names)
                for j = 1, #tier_names do
                    local tier = tier_names[j]
                    local count = tiers[tier]
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

    if entity.name == Constants.SERVER_NAME then
        storage.servers[entity.unit_number] = {
            entity = entity,
            network_id = nil,
            energy_interface = self:CreateEnergyInterface(entity),
        }

        local new_network_id = self:CreateNetwork(entity)
        game.print({ "message.items-network-built-network", new_network_id })
    end

    local connected_entity = nil
    if entity.name == Constants.CONNECTOR_NAME then
        local connected = self:FindSupportedEntities(entity)
        local metadata = {
            render = self:RenderConnectorIndicator(entity),
        }
        if #connected > 0 then
            connected_entity = connected[1]
            metadata.connected = connected_entity
        end
        Gridorius.AddMetadata(entity, metadata)
    else
        local connectors = self:GetConnectors(entity)
        if #connectors > 0 then
            local systems = {}
            for _, connector in pairs(connectors) do
                if connector and connector.valid then
                    Gridorius.SetMetadataValue(connector, "connected", entity)
                    local system_id = storage.cables[connector.unit_number] and
                        storage.cables[connector.unit_number].system_id
                    systems[system_id] = true
                end
            end

            for system_id, _ in pairs(systems) do
                if system_id then
                    self:RebuildSystemNetworks(system_id)
                end
            end
        end
    end

    if Constants.CABLE_ENTITIES[entity.name] then
        local system_id = self:HandleNewCable(entity)
        if connected_entity then
            self:RebuildSystemNetworks(system_id)
        end
    end
end

function NetworkSystem:HandleMineEntity(event)
    local entity = get_entity_from_event(event)
    if not self:IsSupportedEntity(entity) then
        return
    end

    Gridorius.RemoveMetadata(entity)

    if Constants.CABLE_ENTITIES[entity.name] then
        local system_id = storage.cables[entity.unit_number].system_id
        self:HandleRemoveCable(entity)
        self:RecalculateCableSystem(system_id)
    else
        local connectors = self:GetConnectors(entity)
        local systems = {}
        for _, connector in pairs(connectors) do
            systems[storage.cables[connector.unit_number].system_id] = true
            Gridorius.RemoveMetadataValue(connector, "connected")
        end
        for system_id, _ in pairs(systems) do
            self:RebuildSystemNetworks(system_id)
        end
    end

    if (self:IsEntityWithPowerPole(entity)) then
        self:RemovePowerPole(entity)
    end

    if entity.name == Constants.SERVER_NAME then
        self:DestroyServer(entity)
    end
end

function NetworkSystem:HandleTick(event)
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
