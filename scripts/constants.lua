local Constants = {
    SERVER_NAME = "network-server",
    CABLE_NAME = "network-cable",
    CONNECTOR_NAME = "network-connector",
    PRODUCTION_COMBINATOR_NAME = "network-production-combinator",
    UNLOADING_TRAIN_STOP_NAME = "network-unloading-train-stop",
    NETWORK_STORAGE_CHEST_NAME = "network-storage-chest",
    HIDDEN_POWER_POLE_NAME = "network-hidden-power-pole",
    POWER_TECH_NAME = "network-power-conductivity",
    TERMINAL_NAME = "network-terminal",
    INSERTER_NAME = "network-inserter",
    BULK_INSERTER_NAME = "network-bulk-inserter",
    BUFFER_CHEST_NAME = "network-buffer-chest",
    FLUID_INPUT = "network-fluid-input",
    FLUID_OUTPUT = "network-fluid-output",
    AMMO_TURRET_TYPE = "ammo-turret",
    ARTILLERY_TURRET_TYPE = "artillery-turret",
    ENERGY_INTERFACE_NAME = "network-hidden-energy-interface",
    REBUILD_DELAY = 40,
    MACHINE_TYPES = {
        ["assembling-machine"] = true,
        ["furnace"] = true,
        ["lab"] = true,
        ["rocket-silo"] = true,
    },
    TURRET_TYPES = {
        ["ammo-turret"] = true,
        ["artillery-turret"] = true,
    },
    ABSORBABLE_CHEST_TYPES = {
        ["container"] = true,
        ["infinity-container"] = true,
        ['asteroid-collector'] = true,
    },
    TYPE = {
        SERVER = "server",
        TERMINAL = "terminal",
        INSERTER = "inserter",
        BUFFER_CHEST = "buffer_chest",
        FLUID_INPUT = "fluid_input",
        FLUID_OUTPUT = "fluid_output",
        MACHINE = "machine",
        CHEST = "chest",
        UNKNOWN = "unknown",
        CABLE = "cable",
        CONNECTOR = "connector",
        TURRET = "turret",
        PRODUCTION_COMBINATOR = "production_combinator",
        UNLOADING_TRAIN_STOP = "unloading_train_stop",
    },
    DISTRIBUTE_PACK_SIZE = 2,
    -- DISTRIBUTE_PACK_SIZE = 20,
    BUILD_EVENTS = {
        defines.events.on_built_entity,
        defines.events.on_robot_built_entity,
        defines.events.script_raised_built,
        defines.events.script_raised_revive,
    },
    MINING_EVENTS = {
        defines.events.on_player_mined_entity,
        defines.events.on_robot_mined_entity,
        defines.events.on_entity_died,
        defines.events.script_raised_destroy,
    }
}

Constants.DISTRIBUTABLE_TYPES = {
    [Constants.TYPE.MACHINE] = true,
    [Constants.TYPE.CHEST] = true,
    [Constants.TYPE.FLUID_INPUT] = true,
    [Constants.TYPE.FLUID_OUTPUT] = true,
    [Constants.TYPE.BUFFER_CHEST] = true,
    [Constants.TYPE.INSERTER] = true,
    [Constants.TYPE.UNLOADING_TRAIN_STOP] = true,
}

Constants.ENTITY_TYPES_MAP = {
    [Constants.SERVER_NAME] = Constants.TYPE.SERVER,
    [Constants.TERMINAL_NAME] = Constants.TYPE.TERMINAL,
    [Constants.INSERTER_NAME] = Constants.TYPE.INSERTER,
    [Constants.BULK_INSERTER_NAME] = Constants.TYPE.INSERTER,
    [Constants.BUFFER_CHEST_NAME] = Constants.TYPE.BUFFER_CHEST,
    [Constants.FLUID_INPUT] = Constants.TYPE.FLUID_INPUT,
    [Constants.FLUID_OUTPUT] = Constants.TYPE.FLUID_OUTPUT,
    [Constants.CABLE_NAME] = Constants.TYPE.CABLE,
    [Constants.CONNECTOR_NAME] = Constants.TYPE.CONNECTOR,
    [Constants.PRODUCTION_COMBINATOR_NAME] = Constants.TYPE.PRODUCTION_COMBINATOR,
    [Constants.UNLOADING_TRAIN_STOP_NAME] = Constants.TYPE.UNLOADING_TRAIN_STOP,
}

Constants.SUPPORTED_TURRET_TYPES = {
    [Constants.AMMO_TURRET_TYPE] = true,
    [Constants.ARTILLERY_TURRET_TYPE] = true,
}

Constants.SUPPORTED_ENTITIES = {
    [Constants.SERVER_NAME] = true,
    [Constants.CABLE_NAME] = true,
    [Constants.CONNECTOR_NAME] = true,
    [Constants.SERVER_NAME] = true,
    [Constants.TERMINAL_NAME] = true,
    [Constants.INSERTER_NAME] = true,
    [Constants.BULK_INSERTER_NAME] = true,
    [Constants.BUFFER_CHEST_NAME] = true,
    [Constants.FLUID_INPUT] = true,
    [Constants.FLUID_OUTPUT] = true,
    [Constants.PRODUCTION_COMBINATOR_NAME] = true,
    [Constants.UNLOADING_TRAIN_STOP_NAME] = true,
}

Constants.BLUEPRINT_TAG_ENTITIES = {
    [Constants.FLUID_OUTPUT] = true,
    [Constants.PRODUCTION_COMBINATOR_NAME] = true,
}

Constants.CABLE_ENTITIES = {
    [Constants.CABLE_NAME] = true,
    [Constants.CONNECTOR_NAME] = true,
}

Constants.SUPPORTED_ENTITY_TYPES = {}

Gridorius.Dictionary:new(Constants.MACHINE_TYPES):ForEach(function(_, type)
    table.insert(Constants.SUPPORTED_ENTITY_TYPES, type)
end)

Gridorius.Dictionary:new(Constants.TURRET_TYPES):ForEach(function(_, type)
    table.insert(Constants.SUPPORTED_ENTITY_TYPES, type)
end)

Gridorius.Dictionary:new(Constants.ABSORBABLE_CHEST_TYPES):ForEach(function(_, type)
    table.insert(Constants.SUPPORTED_ENTITY_TYPES, type)
end)

Constants.SUPPORTED_ENTITY_NAMES = {
    Constants.SERVER_NAME,
    Constants.TERMINAL_NAME,
    Constants.INSERTER_NAME,
    Constants.BULK_INSERTER_NAME,
    Constants.BUFFER_CHEST_NAME,
    Constants.FLUID_INPUT,
    Constants.FLUID_OUTPUT,
    Constants.PRODUCTION_COMBINATOR_NAME,
    Constants.UNLOADING_TRAIN_STOP_NAME,
}

return Constants
