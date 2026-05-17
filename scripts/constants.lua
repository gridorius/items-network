local Constants = {
    SERVER_NAME = "network-server",
    CABLE_NAME = "network-cable",
    UNDERGROUND_CABLE_NAME = "network-underground-cable",
    CONNECTOR_NAME = "network-connector",
    HIDDEN_POWER_POLE_NAME = "network-hidden-power-pole",
    POWER_TECH_NAME = "network-power-conductivity",
    TERMINAL_NAME = "network-terminal",
    BUFFER_CHEST_NAME = "network-buffer-chest",
    FLUID_INPUT = "network-fluid-input",
    FLUID_OUTPUT = "network-fluid-output",
    REBUILD_DELAY = 60,
    MACHINE_TYPES = {
        ["assembling-machine"] = true,
        ["furnace"] = true,
        ["lab"] = true,
        ["rocket-silo"] = true,
    },
    ABSORBABLE_CHEST_TYPES = {
        ["container"] = true,
        ["infinity-container"] = true,
    },
    TYPE = {
        SERVER = "server",
        TERMINAL = "terminal",
        BUFFER_CHEST = "buffer_chest",
        FLUID_INPUT = "fluid_input",
        FLUID_OUTPUT = "fluid_output",
        MACHINE = "machine",
        CHEST = "chest",
        UNKNOWN = "unknown",
        CABLE = "cable",
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
}

Constants.ENTITY_TYPES_MAP = {
    [Constants.SERVER_NAME] = Constants.TYPE.SERVER,
    [Constants.TERMINAL_NAME] = Constants.TYPE.TERMINAL,
    [Constants.BUFFER_CHEST_NAME] = Constants.TYPE.BUFFER_CHEST,
    [Constants.FLUID_INPUT] = Constants.TYPE.FLUID_INPUT,
    [Constants.FLUID_OUTPUT] = Constants.TYPE.FLUID_OUTPUT,
    [Constants.CABLE_NAME] = Constants.TYPE.CABLE,
    [Constants.UNDERGROUND_CABLE_NAME] = Constants.TYPE.CABLE,
}

Constants.SUPPORTED_ENTITIES = {
    [Constants.SERVER_NAME] = true,
    [Constants.CABLE_NAME] = true,
    [Constants.UNDERGROUND_CABLE_NAME] = true,
    [Constants.TERMINAL_NAME] = true,
    [Constants.BUFFER_CHEST_NAME] = true,
    [Constants.FLUID_INPUT] = true,
    [Constants.FLUID_OUTPUT] = true,
}

Constants.ENTITIES_WITH_CONNECTORS = {
    [Constants.SERVER_NAME] = true,
    [Constants.UNDERGROUND_CABLE_NAME] = true,
    [Constants.TERMINAL_NAME] = true,
    [Constants.BUFFER_CHEST_NAME] = true,
    [Constants.FLUID_INPUT] = true,
    [Constants.FLUID_OUTPUT] = true,
}

Constants.ENTITIES_WITH_POWER_POLES = {
    [Constants.CABLE_NAME] = true,
    [Constants.CONNECTOR_NAME] = true,
}

Constants.CABLE_ENTITIES = {
    [Constants.CABLE_NAME] = true,
    [Constants.UNDERGROUND_CABLE_NAME] = true,
}

return Constants
