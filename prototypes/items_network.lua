require("circuit-connector-sprites")

---@diagnostic disable-next-line: undefined-global
local default_circuit_wire_max_distance = default_circuit_wire_max_distance
---@diagnostic disable-next-line: undefined-global
local circuit_connector_definitions = circuit_connector_definitions

data:extend({
  {
    type = "collision-layer",
    name = "network-cable-layer",
  },
})

local network_server_entity = {
    type = "assembling-machine",
    name = "network-server",
    localised_name = {"entity-name.network-server"},
    localised_description = {"entity-description.network-server"},
    icon = "__items-network__/graphics/icons/server.png",
    icon_size = 100,
    flags = {"placeable-neutral", "player-creation"},
    minable = {
        mining_time = 10,
        result = "network-server"
    },
    max_health = 30000,
    tile_width = 2,
    tile_height = 2,
    collision_box = {{-1, -1}, {1, 1}},
    selection_box = {{-1, -1}, {1, 1}},
    crafting_categories = {"crafting"},
    crafting_speed = 1,
    fixed_recipe = "network-server-cycle",
    show_recipe_icon = false,
    show_recipe_icon_on_map = false,
    energy_usage = "20kW",
    energy_source = {
        type = "electric",
        usage_priority = "secondary-input"
    },


    graphics_set = {
      animation = {
        filename = "__items-network__/graphics/entity/server/server-sprite.png",
        width = 150,
        height = 199,
        frame_count = 36,
        animation_speed = 0.5,
        line_length = 6,
        scale = 0.45,
        shift = util.by_pixel(0, -10),
      }
    }
}

-- Clone the vanilla heat pipe so the cable keeps pipe-like connectivity and visuals.
local network_cable_entity = table.deepcopy(data.raw["heat-pipe"]["heat-pipe"])
network_cable_entity.name = "network-cable"
network_cable_entity.localised_name = {"item-name.network-cable"}
network_cable_entity.localised_description = {"item-description.network-cable"}
network_cable_entity.minable = { mining_time = 0.1, result = "network-cable" }

local network_connector = table.deepcopy(data.raw["heat-pipe"]["heat-pipe"])
network_connector.name = "network-connector"
network_connector.localised_name = {"item-name.network-connector"}
network_connector.localised_description = {"item-description.network-connector"}
network_connector.minable = nil
network_connector.collision_mask = { 
  layers = {
    ["network-cable-layer"] = true,
  }
}
network_connector.selection_box = {{0,0}, {0,0}}

-- Recolor every sprite layer recursively so the new entity reads as a distinct cable type.
local cable_tint = { r = 0.2, g = 0.9, b = 1.0, a = 1.0 }
local absorber_cable_tint = { r = 1.0, g = 0.7, b = 0.2, a = 1.0 }
local fluid_input_tint = { r = 0.15, g = 0.45, b = 1.0, a = 1.0 }
local fluid_output_tint = { r = 0.1, g = 0.85, b = 0.45, a = 1.0 }

local function apply_tint_to_sprites(node, tint)
  -- Walk the whole prototype table because sprite definitions can be nested deeply.
  if type(node) ~= "table" then
    return
  end

  if node.filename and not node.draw_as_shadow then
    node.tint = tint
  end

  for _, value in pairs(node) do
    if type(value) == "table" then
      apply_tint_to_sprites(value, tint)
    end
  end
end

apply_tint_to_sprites(network_cable_entity, cable_tint)
apply_tint_to_sprites(network_connector, cable_tint)

local network_absorber_cable_entity = table.deepcopy(data.raw["heat-pipe"]["heat-pipe"])
network_absorber_cable_entity.name = "network-absorber-cable"
network_absorber_cable_entity.localised_name = {"item-name.network-absorber-cable"}
network_absorber_cable_entity.localised_description = {"item-description.network-absorber-cable"}
network_absorber_cable_entity.minable = { mining_time = 0.1, result = "network-absorber-cable" }

apply_tint_to_sprites(network_absorber_cable_entity, absorber_cable_tint)

local network_fluid_input_entity = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
local vanilla_pipe_to_ground_item = data.raw["item"]["pipe-to-ground"]
network_fluid_input_entity.name = "network-fluid-input"
network_fluid_input_entity.localised_name = {"item-name.network-fluid-input"}
network_fluid_input_entity.localised_description = {"item-description.network-fluid-input"}
network_fluid_input_entity.minable = { mining_time = 0.1, result = "network-fluid-input" }

if vanilla_pipe_to_ground_item then
  network_fluid_input_entity.icons = table.deepcopy(vanilla_pipe_to_ground_item.icons)
  network_fluid_input_entity.icon = vanilla_pipe_to_ground_item.icon
  network_fluid_input_entity.icon_size = vanilla_pipe_to_ground_item.icon_size
end

if network_fluid_input_entity.fluid_box then
  network_fluid_input_entity.fluid_box.volume = 5000
end

apply_tint_to_sprites(network_fluid_input_entity, fluid_input_tint)

local network_fluid_output_entity = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
network_fluid_output_entity.name = "network-fluid-output"
network_fluid_output_entity.localised_name = {"item-name.network-fluid-output"}
network_fluid_output_entity.localised_description = {"item-description.network-fluid-output"}
network_fluid_output_entity.minable = { mining_time = 0.1, result = "network-fluid-output" }

if vanilla_pipe_to_ground_item then
  network_fluid_output_entity.icons = table.deepcopy(vanilla_pipe_to_ground_item.icons)
  network_fluid_output_entity.icon = vanilla_pipe_to_ground_item.icon
  network_fluid_output_entity.icon_size = vanilla_pipe_to_ground_item.icon_size
end

if network_fluid_output_entity.fluid_box then
  network_fluid_output_entity.fluid_box.volume = 1000
end

apply_tint_to_sprites(network_fluid_output_entity, fluid_output_tint)

local network_cable_item_icons = table.deepcopy(network_cable_entity.icons)
local network_cable_item_icon_size = network_cable_entity.icon_size
---@diagnostic disable-next-line: undefined-field
local network_cable_item_icon_mipmaps = rawget(network_cable_entity, "icon_mipmaps")

local network_absorber_cable_item_icons = table.deepcopy(network_absorber_cable_entity.icons)
local network_absorber_cable_item_icon_size = network_absorber_cable_entity.icon_size
---@diagnostic disable-next-line: undefined-field
local network_absorber_cable_item_icon_mipmaps = rawget(network_absorber_cable_entity, "icon_mipmaps")

local network_fluid_input_item_icons = table.deepcopy(network_fluid_input_entity.icons)
local network_fluid_input_item_icon_size = network_fluid_input_entity.icon_size
---@diagnostic disable-next-line: undefined-field
local network_fluid_input_item_icon_mipmaps = vanilla_pipe_to_ground_item and rawget(vanilla_pipe_to_ground_item, "icon_mipmaps") or nil

local network_fluid_output_item_icons = table.deepcopy(network_fluid_output_entity.icons)
local network_fluid_output_item_icon_size = network_fluid_output_entity.icon_size
---@diagnostic disable-next-line: undefined-field
local network_fluid_output_item_icon_mipmaps = vanilla_pipe_to_ground_item and rawget(vanilla_pipe_to_ground_item, "icon_mipmaps") or nil

if network_cable_item_icons then
  for _, icon_layer in ipairs(network_cable_item_icons) do
    icon_layer.tint = cable_tint
  end
else
  network_cable_item_icons = {
    {
      icon = network_cable_entity.icon,
      icon_size = network_cable_item_icon_size,
      tint = cable_tint,
    },
  }
end

if network_absorber_cable_item_icons then
  for _, icon_layer in ipairs(network_absorber_cable_item_icons) do
    icon_layer.tint = absorber_cable_tint
  end
else
  network_absorber_cable_item_icons = {
    {
      icon = network_absorber_cable_entity.icon,
      icon_size = network_absorber_cable_item_icon_size,
      tint = absorber_cable_tint,
    },
  }
end

if network_fluid_input_item_icons then
  for _, icon_layer in ipairs(network_fluid_input_item_icons) do
    icon_layer.tint = fluid_input_tint
  end
else
  network_fluid_input_item_icons = {
    {
      icon = network_fluid_input_entity.icon,
      icon_size = network_fluid_input_item_icon_size,
      tint = fluid_input_tint,
    },
  }
end

if network_fluid_output_item_icons then
  for _, icon_layer in ipairs(network_fluid_output_item_icons) do
    icon_layer.tint = fluid_output_tint
  end
else
  network_fluid_output_item_icons = {
    {
      icon = network_fluid_output_entity.icon,
      icon_size = network_fluid_output_item_icon_size,
      tint = fluid_output_tint,
    },
  }
end

-- Clone the constant combinator so the terminal can output network item counts to circuits.
local network_terminal_entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
local network_buffer_chest_entity = table.deepcopy(data.raw["logistic-container"]["buffer-chest"])

network_terminal_entity.name = "network-terminal"
network_terminal_entity.localised_name = {"entity-name.network-terminal"}
network_terminal_entity.localised_description = {"entity-description.network-terminal"}
network_terminal_entity.minable = { mining_time = 0.1, result = "network-terminal" }

network_buffer_chest_entity.name = "network-buffer-chest"
network_buffer_chest_entity.localised_name = {"entity-name.network-buffer-chest"}
network_buffer_chest_entity.localised_description = {"entity-description.network-buffer-chest"}
network_buffer_chest_entity.minable = { mining_time = 0.1, result = "network-buffer-chest" }
network_buffer_chest_entity.inventory_size = 160
network_buffer_chest_entity.render_not_in_network_icon = false

-- Expose the new entities, items, recipes, and technology in one data batch.
data:extend({
  network_server_entity,
  network_cable_entity,
  network_connector,
  network_absorber_cable_entity,
  network_fluid_input_entity,
  network_fluid_output_entity,
  network_terminal_entity,
  network_buffer_chest_entity,
  {
    type = "item-subgroup",
    name = "items-network",
    group = "logistics",
    order = "z[items-network]",
  },

  {
    type = "recipe",
    name = "network-server-cycle",
    localised_name = {"recipe-name.network-server"},
    icon = network_server_entity.icon,
    icon_size = network_server_entity.icon_size,
    subgroup = "items-network",
    order = "zz[network-server-cycle]",
    category = "crafting",
    enabled = true,
    hidden = true,
    hide_from_player_crafting = true,
    hide_from_stats = true,
    hide_from_signal_gui = true,
    allow_decomposition = false,
    allow_as_intermediate = false,
    allow_intermediates = false,
    main_product = "",
    energy_required = 1,
    ingredients = {},
    results = {},
  },

  -- Item entries let the player place the cable, absorber cable, and terminal.
  {
    type = "item",
    name = "network-cable",
    localised_name = {"item-name.network-cable"},
    localised_description = {"item-description.network-cable"},
    icons = network_cable_item_icons,
    icon_size = network_cable_item_icon_size,
    icon_mipmaps = network_cable_item_icon_mipmaps,
    subgroup = "intermediate-product",
    order = "z[network-cable]",
    place_result = "network-cable",
    stack_size = 200,
  },

  {
    type = "item",
    name = "network-absorber-cable",
    localised_name = {"item-name.network-absorber-cable"},
    localised_description = {"item-description.network-absorber-cable"},
    icons = network_absorber_cable_item_icons,
    icon_size = network_absorber_cable_item_icon_size,
    icon_mipmaps = network_absorber_cable_item_icon_mipmaps,
    subgroup = "intermediate-product",
    order = "z[network-absorber-cable]",
    place_result = "network-absorber-cable",
    stack_size = 200,
  },

  {
    type = "item",
    name = "network-terminal",
    localised_name = {"item-name.network-terminal"},
    localised_description = {"item-description.network-terminal"},
    icon = network_terminal_entity.icon or "__base__/graphics/icons/constant-combinator.png",
    icon_size = network_terminal_entity.icon_size or 64,
    subgroup = "items-network",
    order = "b[network-terminal]",
    place_result = "network-terminal",
    stack_size = 50,
  },

  {
    type = "item",
    name = "network-server",
    localised_name = {"item-name.network-server"},
    localised_description = {"item-description.network-server"},
    icon = network_server_entity.icon,
    icon_size = network_server_entity.icon_size,
    subgroup = "items-network",
    order = "ba[network-server]",
    place_result = "network-server",
    stack_size = 10,
  },

  {
    type = "item",
    name = "network-fluid-input",
    localised_name = {"item-name.network-fluid-input"},
    localised_description = {"item-description.network-fluid-input"},
    icons = network_fluid_input_item_icons,
    icon_size = network_fluid_input_item_icon_size,
    icon_mipmaps = network_fluid_input_item_icon_mipmaps,
    subgroup = "items-network",
    order = "bb[network-fluid-input]",
    place_result = "network-fluid-input",
    stack_size = 100,
  },

  {
    type = "item",
    name = "network-fluid-output",
    localised_name = {"item-name.network-fluid-output"},
    localised_description = {"item-description.network-fluid-output"},
    icons = network_fluid_output_item_icons,
    icon_size = network_fluid_output_item_icon_size,
    icon_mipmaps = network_fluid_output_item_icon_mipmaps,
    subgroup = "items-network",
    order = "bc[network-fluid-output]",
    place_result = "network-fluid-output",
    stack_size = 100,
  },

  {
    type = "item",
    name = "network-buffer-chest",
    localised_name = {"item-name.network-buffer-chest"},
    localised_description = {"item-description.network-buffer-chest"},
    icon = network_buffer_chest_entity.icon or "__base__/graphics/icons/buffer-chest.png",
    icon_size = network_buffer_chest_entity.icon_size or 64,
    subgroup = "items-network",
    order = "c[network-buffer-chest]",
    place_result = "network-buffer-chest",
    stack_size = 50,
  },

  -- Recipes are grouped under a custom subgroup to keep the crafting menu readable.
  {
    type = "recipe",
    name = "network-cable",
    localised_name = {"recipe-name.network-cable"},
    subgroup = "items-network",
    order = "a[network-cable]",
    enabled = false,
    energy_required = 1,
    ingredients = {
      { type = "item", name = "iron-plate", amount = 1 },
      { type = "item", name = "copper-cable",        amount = 20 },
      { type = "item", name = "electronic-circuit",  amount = 1 },
    },
    results = {
      { type = "item", name = "network-cable", amount = 2 },
    },
  },

  {
    type = "recipe",
    name = "network-absorber-cable",
    localised_name = {"recipe-name.network-absorber-cable"},
    subgroup = "items-network",
    order = "aa[network-absorber-cable]",
    enabled = false,
    energy_required = 1,
    ingredients = {
      { type = "item", name = "network-cable", amount = 3 },
      { type = "item", name = "iron-plate", amount = 1 },
    },
    results = {
      { type = "item", name = "network-absorber-cable", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-terminal",
    localised_name = {"recipe-name.network-terminal"},
    subgroup = "items-network",
    order = "b[network-terminal]",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "iron-plate", amount = 8 },
      { type = "item", name = "electronic-circuit", amount = 5 },
      { type = "item", name = "network-cable", amount = 6 },
    },
    results = {
      { type = "item", name = "network-terminal", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-server",
    localised_name = {"recipe-name.network-server"},
    subgroup = "items-network",
    order = "ba[network-server]",
    enabled = false,
    energy_required = 5,
    ingredients = {
      { type = "item", name = "iron-plate", amount = 20 },
      { type = "item", name = "electronic-circuit", amount = 20 },
      { type = "item", name = "network-cable", amount = 20 },
    },
    results = {
      { type = "item", name = "network-server", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-fluid-input",
    localised_name = {"recipe-name.network-fluid-input"},
    subgroup = "items-network",
    order = "bb[network-fluid-input]",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "pipe-to-ground", amount = 1 },
      { type = "item", name = "iron-plate", amount = 2 },
      { type = "item", name = "electronic-circuit", amount = 2 },
      { type = "item", name = "network-cable", amount = 2 },
    },
    results = {
      { type = "item", name = "network-fluid-input", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-fluid-output",
    localised_name = {"recipe-name.network-fluid-output"},
    subgroup = "items-network",
    order = "bc[network-fluid-output]",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "pipe-to-ground", amount = 1 },
      { type = "item", name = "iron-plate", amount = 2 },
      { type = "item", name = "electronic-circuit", amount = 2 },
      { type = "item", name = "network-cable", amount = 2 },
    },
    results = {
      { type = "item", name = "network-fluid-output", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-buffer-chest",
    localised_name = {"recipe-name.network-buffer-chest"},
    subgroup = "items-network",
    order = "c[network-buffer-chest]",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "electronic-circuit", amount = 10 },
      { type = "item", name = "network-cable", amount = 10 },
      { type = "item", name = "iron-chest", amount = 1 },
    },
    results = {
      { type = "item", name = "network-buffer-chest", amount = 1 },
    },
  },

  -- One research unlocks the whole cable network toolset.
  {
    type = "technology",
    name = "items-network",
    localised_name = {"technology-name.items-network"},
    localised_description = {"technology-description.items-network"},
    icon = "__base__/graphics/technology/circuit-network.png",
    icon_size = 256,
    prerequisites = {"automation-science-pack", "electronics"},
    unit = {
      count = 10,
      ingredients = {
        { "automation-science-pack", 1 }
      },
      time = 15,
    },
    effects = {
      { type = "unlock-recipe", recipe = "network-cable" },
      { type = "unlock-recipe", recipe = "network-absorber-cable" },
      { type = "unlock-recipe", recipe = "network-terminal" },
      { type = "unlock-recipe", recipe = "network-server" },
      { type = "unlock-recipe", recipe = "network-fluid-input" },
      { type = "unlock-recipe", recipe = "network-fluid-output" },
      { type = "unlock-recipe", recipe = "network-buffer-chest" },
    },
    order = "c-z[items-network]",
  },
})
