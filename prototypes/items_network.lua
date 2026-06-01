require("circuit-connector-sprites")

data:extend({
  {
    type = "collision-layer",
    name = "network-cable-layer",
  },
})

local network_server_entity = {
  type = "assembling-machine",
  name = "network-server",
  localised_name = { "entity-name.network-server" },
  localised_description = { "entity-description.network-server" },
  icon = "__items-network__/graphics/icons/server.png",
  icon_size = 100,
  flags = { "placeable-neutral", "player-creation" },
  minable = {
    mining_time = 3,
    result = "network-server"
  },
  max_health = 30000,
  tile_width = 2,
  tile_height = 2,
  collision_box = { { -1, -1 }, { 1, 1 } },
  selection_box = { { -1, -1 }, { 1, 1 } },
  crafting_categories = { "crafting" },
  crafting_speed = 1,
  fixed_recipe = "network-server-cycle",
  show_recipe_icon = false,
  show_recipe_icon_on_map = false,
  energy_usage = "20kW",
  energy_source = {
    type = "void",
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



local network_cable_entity = table.deepcopy(data.raw["heat-pipe"]["heat-pipe"])
network_cable_entity.name = "network-cable"
network_cable_entity.localised_name = { "item-name.network-cable" }
network_cable_entity.localised_description = { "item-description.network-cable" }
network_cable_entity.minable = { mining_time = 0.1, result = "network-cable" }
network_cable_entity.fast_replaceable_group = "network-cable"
network_cable_entity.collision_mask = {
  layers = {
    ["network-cable-layer"] = true,
  }
}

local network_connector = table.deepcopy(data.raw["heat-pipe"]["heat-pipe"])
network_connector.name = "network-connector"
network_connector.localised_name = { "item-name.network-connector" }
network_connector.localised_description = { "item-description.network-connector" }
network_connector.minable = { mining_time = 0.1, result = "network-connector" }
network_connector.fast_replaceable_group = "network-cable"
network_connector.collision_mask = {
  layers = {
    ["network-cable-layer"] = true,
  }
}

local network_storage_chest_entity = table.deepcopy(data.raw["container"]["steel-chest"])
network_storage_chest_entity.name = "network-storage-chest"
network_storage_chest_entity.localised_name = { "entity-name.network-storage-chest" }
network_storage_chest_entity.localised_description = { "entity-description.network-storage-chest" }
network_storage_chest_entity.inventory_type = "with_custom_stack_size"
network_storage_chest_entity.inventory_properties = {
  stack_size_min = 4000000000,
}
network_storage_chest_entity.minable = { mining_time = 2, result = "steel-chest" }
network_storage_chest_entity.inventory_size = 65000



local network_hidden_power_pole = table.deepcopy(data.raw["electric-pole"]["small-electric-pole"])
network_hidden_power_pole.name = "network-hidden-power-pole"
network_hidden_power_pole.localised_name = { "entity-name.network-cable" }
network_hidden_power_pole.hidden = true
network_hidden_power_pole.hidden_in_factoriopedia = true
network_hidden_power_pole.flags = {
  "not-on-map",
  "placeable-off-grid",
  "not-blueprintable",
  "not-deconstructable",
  "hide-alt-info",
}
network_hidden_power_pole.minable = nil
network_hidden_power_pole.selectable_in_game = false
network_hidden_power_pole.collision_box = { { 0, 0 }, { 0, 0 } }
network_hidden_power_pole.selection_box = { { 0, 0 }, { 0, 0 } }
network_hidden_power_pole.collision_mask = { layers = {} }
network_hidden_power_pole.maximum_wire_distance = 1.8
network_hidden_power_pole.supply_area_distance = 1.5
network_hidden_power_pole.draw_copper_wires = false
network_hidden_power_pole.draw_circuit_wires = false
network_hidden_power_pole.active_picture = nil
network_hidden_power_pole.light = nil
network_hidden_power_pole.pictures = {
  filename = "__core__/graphics/empty.png",
  priority = "low",
  width = 1,
  height = 1,
  direction_count = 4,
}
network_hidden_power_pole.radius_visualisation_picture = {
  filename = "__core__/graphics/empty.png",
  width = 1,
  height = 1,
}

local network_hidden_energy_interface = {
  type = "electric-energy-interface",
  name = "network-hidden-energy-interface",
  localised_name = { "entity-name.network-hidden-energy-interface" },
  hidden = true,
  hidden_in_factoriopedia = true,
  minable = nil,
  max_health = 1,
  selectable_in_game = false,
  collision_box = { { 0, 0 }, { 0, 0 } },
  selection_box = { { 0, 0 }, { 0, 0 } },
  collision_mask = { layers = {} },
  gui_mode = "none",
  icon = "__items-network__/graphics/icons/server.png",
  icon_size = 100,
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    buffer_capacity = "1J",
    input_flow_limit = "10000GW",
    output_flow_limit = "0W",
    render_no_power_icon = false,
    render_no_network_icon = false,
  },
  energy_production = "0W",
  energy_usage = "0W",
  picture = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
  },
}

-- Recolor every sprite layer recursively so the new entity reads as a distinct cable type.
local cable_tint = { r = 0.2, g = 0.9, b = 1.0, a = 1.0 }
local absorber_cable_tint = { 0.05, 1, 0.1 }
local fluid_input_tint = { r = 0.15, g = 0.45, b = 1.0, a = 1.0 }
local fluid_output_tint = { r = 0.1, g = 0.85, b = 0.45, a = 1.0 }
local buffer_chest_tint = { 0.17, 0, 0.67 }
local inserter_tint = { r = 1.0, g = 0.65, b = 0.15, a = 1.0 }
local bulk_inserter_tint = { r = 0.95, g = 0.35, b = 0.1, a = 1.0 }
local train_stop_tint = { r = 0.15, g = 0.8, b = 0.8, a = 1.0 }

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

local function apply_item_tint(item, entity, tint)
  item.icons = {
    {
      icon = entity.icon,
      icon_size = entity.icon_size,
      tint = tint,
    }
  }
  item.icon_size = entity.icon_size
  item.icon_mipmaps = entity.icon_mipmaps
  return item
end

apply_tint_to_sprites(network_cable_entity, cable_tint)
apply_tint_to_sprites(network_connector, absorber_cable_tint)


local network_fluid_input_entity = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
network_fluid_input_entity.name = "network-fluid-input"
network_fluid_input_entity.localised_name = { "item-name.network-fluid-input" }
network_fluid_input_entity.localised_description = { "item-description.network-fluid-input" }
network_fluid_input_entity.minable = { mining_time = 0.1, result = "network-fluid-input" }
network_fluid_input_entity.fluid_box.volume = 5000

apply_tint_to_sprites(network_fluid_input_entity, fluid_input_tint)

local network_fluid_output_entity = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
network_fluid_output_entity.name = "network-fluid-output"
network_fluid_output_entity.localised_name = { "item-name.network-fluid-output" }
network_fluid_output_entity.localised_description = { "item-description.network-fluid-output" }
network_fluid_output_entity.minable = { mining_time = 0.1, result = "network-fluid-output" }
network_fluid_output_entity.fluid_box.volume = 5000

apply_tint_to_sprites(network_fluid_output_entity, fluid_output_tint)

local network_terminal_entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
local network_production_combinator_entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
local network_buffer_chest_entity = table.deepcopy(data.raw["logistic-container"]["buffer-chest"])
local network_unloading_train_stop_entity = table.deepcopy(data.raw["train-stop"]["train-stop"])
local base_network_inserter = data.raw["inserter"]["fast-inserter"] or data.raw["inserter"]["inserter"]
local base_bulk_network_inserter = data.raw["inserter"]["bulk-inserter"] or data.raw["inserter"]["stack-inserter"] or base_network_inserter
local base_bulk_network_inserter_item = data.raw["item"]["bulk-inserter"] or data.raw["item"]["stack-inserter"] or data.raw["item"]["fast-inserter"]
local network_inserter_entity = table.deepcopy(base_network_inserter)
local network_bulk_inserter_entity = table.deepcopy(base_bulk_network_inserter)

network_terminal_entity.name = "network-terminal"
network_terminal_entity.localised_name = { "entity-name.network-terminal" }
network_terminal_entity.localised_description = { "entity-description.network-terminal" }
network_terminal_entity.icon = "__items-network__/graphics/entity/terminal/terminal.png"
network_terminal_entity.icon_size = 500
network_terminal_entity.sprites = {
  filename = "__items-network__/graphics/entity/terminal/terminal.png",
  width = 500,
  height = 500,
  scale = 0.06,
}
network_terminal_entity.minable = { mining_time = 0.1, result = "network-terminal" }

network_production_combinator_entity.name = "network-production-combinator"
network_production_combinator_entity.localised_name = { "entity-name.network-production-combinator" }
network_production_combinator_entity.minable = { mining_time = 0.1, result = "network-production-combinator" }

network_buffer_chest_entity.name = "network-buffer-chest"
network_buffer_chest_entity.localised_name = { "entity-name.network-buffer-chest" }
network_buffer_chest_entity.localised_description = { "entity-description.network-buffer-chest" }
network_buffer_chest_entity.icon = "__items-network__/graphics/icons/buffer-chest.png"
network_buffer_chest_entity.icon_size = 64
network_buffer_chest_entity.icon_mipmaps = 4
network_buffer_chest_entity.minable = { mining_time = 0.1, result = "network-buffer-chest" }
network_buffer_chest_entity.inventory_size = 60
network_buffer_chest_entity.trash_inventory_size = 30
network_buffer_chest_entity.render_not_in_network_icon = false
network_buffer_chest_entity.picture = {
  filename = "__items-network__/graphics/entity/buffer-chest.png",
  width = 66,
  height = 74,
  x = 0,
  y = 0,
  scale = 0.5,
  shift = util.by_pixel(0, -2),
}
network_buffer_chest_entity.animation = {
  filename = "__items-network__/graphics/entity/buffer-chest.png",
  width = 66,
  height = 74,
  frame_count = 7,
  line_length = 7,
  scale = 0.5,
  shift = util.by_pixel(0, -2),
  animation_speed = 0.25,
}

network_unloading_train_stop_entity.name = "network-unloading-train-stop"
network_unloading_train_stop_entity.localised_name = { "entity-name.network-unloading-train-stop" }
network_unloading_train_stop_entity.localised_description = { "entity-description.network-unloading-train-stop" }
network_unloading_train_stop_entity.minable = { mining_time = 0.5, result = "network-unloading-train-stop" }

network_inserter_entity.name = "network-inserter"
network_inserter_entity.localised_name = { "entity-name.network-inserter" }
network_inserter_entity.localised_description = { "entity-description.network-inserter" }
network_inserter_entity.minable = { mining_time = 0.1, result = "network-inserter" }
network_inserter_entity.next_upgrade = nil
network_inserter_entity.fast_replaceable_group = "inserter"
network_inserter_entity.filter_count = 1

network_bulk_inserter_entity.name = "network-bulk-inserter"
network_bulk_inserter_entity.localised_name = { "entity-name.network-bulk-inserter" }
network_bulk_inserter_entity.localised_description = { "entity-description.network-bulk-inserter" }
network_bulk_inserter_entity.minable = { mining_time = 0.1, result = "network-bulk-inserter" }
network_bulk_inserter_entity.next_upgrade = nil
network_bulk_inserter_entity.fast_replaceable_group = "inserter"
network_bulk_inserter_entity.filter_count = 1
apply_tint_to_sprites(network_buffer_chest_entity, buffer_chest_tint)
apply_tint_to_sprites(network_production_combinator_entity, buffer_chest_tint)
apply_tint_to_sprites(network_unloading_train_stop_entity, train_stop_tint)
apply_tint_to_sprites(network_inserter_entity, inserter_tint)
apply_tint_to_sprites(network_bulk_inserter_entity, bulk_inserter_tint)

-- Expose the new entities, items, recipes, and technology in one data batch.
data:extend({
  network_server_entity,
  network_cable_entity,
  network_connector,
  network_hidden_power_pole,
  network_hidden_energy_interface,
  network_fluid_input_entity,
  network_fluid_output_entity,
  network_terminal_entity,
  network_production_combinator_entity,
  network_buffer_chest_entity,
  network_unloading_train_stop_entity,
  network_inserter_entity,
  network_bulk_inserter_entity,
  network_storage_chest_entity,
  {
    type = "item-subgroup",
    name = "items-network",
    group = "logistics",
    order = "z[items-network]",
  },

  {
    type = "recipe",
    name = "network-server-cycle",
    localised_name = { "recipe-name.network-server" },
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

  apply_item_tint({
    type = "item",
    name = "network-cable",
    localised_name = { "item-name.network-cable" },
    localised_description = { "item-description.network-cable" },
    subgroup = "items-network",
    order = "a[network-cable]",
    place_result = "network-cable",
    stack_size = 200,
  }, network_cable_entity, cable_tint),

  apply_item_tint({
    type = "item",
    name = "network-connector",
    localised_name = { "item-name.network-connector" },
    localised_description = { "item-description.network-connector" },
    subgroup = "items-network",
    order = "ab[network-connector]",
    place_result = "network-connector",
    stack_size = 100,
  }, network_connector, absorber_cable_tint),

  {
    type = "item",
    name = "network-terminal",
    localised_name = { "item-name.network-terminal" },
    localised_description = { "item-description.network-terminal" },
    icon = network_terminal_entity.icon or "__base__/graphics/icons/constant-combinator.png",
    icon_size = network_terminal_entity.icon_size or 64,
    subgroup = "items-network",
    order = "b[network-terminal]",
    place_result = "network-terminal",
    stack_size = 50,
  },

  apply_item_tint({
    type = "item",
    name = "network-inserter",
    localised_name = { "item-name.network-inserter" },
    localised_description = { "item-description.network-inserter" },
    subgroup = "items-network",
    order = "bza[network-inserter]",
    place_result = "network-inserter",
    stack_size = 50,
  }, network_inserter_entity, inserter_tint),

  apply_item_tint({
    type = "item",
    name = "network-bulk-inserter",
    localised_name = { "item-name.network-bulk-inserter" },
    localised_description = { "item-description.network-bulk-inserter" },
    subgroup = "items-network",
    order = "bzb[network-bulk-inserter]",
    place_result = "network-bulk-inserter",
    stack_size = 50,
  }, network_bulk_inserter_entity, bulk_inserter_tint),

  apply_item_tint({
    type = "item",
    name = "network-production-combinator",
    localised_name = { "item-name.network-production-combinator" },
    subgroup = "items-network",
    order = "bz[network-production-combinator]",
    place_result = "network-production-combinator",
    stack_size = 50,
  }, network_production_combinator_entity, buffer_chest_tint),

  {
    type = "item",
    name = "network-server",
    localised_name = { "item-name.network-server" },
    localised_description = { "item-description.network-server" },
    icon = network_server_entity.icon,
    icon_size = network_server_entity.icon_size,
    subgroup = "items-network",
    order = "ba[network-server]",
    place_result = "network-server",
    stack_size = 10,
  },

  apply_item_tint({
    type = "item",
    name = "network-fluid-input",
    localised_name = { "item-name.network-fluid-input" },
    localised_description = { "item-description.network-fluid-input" },
    subgroup = "items-network",
    order = "bb[network-fluid-input]",
    place_result = "network-fluid-input",
    stack_size = 100,
  }, network_fluid_input_entity, fluid_input_tint),

  apply_item_tint({
    type = "item",
    name = "network-fluid-output",
    localised_name = { "item-name.network-fluid-output" },
    localised_description = { "item-description.network-fluid-output" },
    subgroup = "items-network",
    order = "bc[network-fluid-output]",
    place_result = "network-fluid-output",
    stack_size = 100,
  }, network_fluid_output_entity, fluid_output_tint),

  apply_item_tint({
    type = "item",
    name = "network-buffer-chest",
    localised_name = { "item-name.network-buffer-chest" },
    localised_description = { "item-description.network-buffer-chest" },
    subgroup = "items-network",
    order = "c[network-buffer-chest]",
    place_result = "network-buffer-chest",
    stack_size = 50,
  }, network_buffer_chest_entity, buffer_chest_tint),

  apply_item_tint({
    type = "item",
    name = "network-unloading-train-stop",
    localised_name = { "item-name.network-unloading-train-stop" },
    localised_description = { "item-description.network-unloading-train-stop" },
    subgroup = "items-network",
    order = "d[network-unloading-train-stop]",
    place_result = "network-unloading-train-stop",
    stack_size = 20,
  }, network_unloading_train_stop_entity, train_stop_tint),

  -- Recipes are grouped under a custom subgroup to keep the crafting menu readable.
  {
    type = "recipe",
    name = "network-cable",
    localised_name = { "recipe-name.network-cable" },
    subgroup = "items-network",
    order = "a[network-cable]",
    enabled = false,
    energy_required = 1,
    ingredients = {
      { type = "item", name = "iron-plate",   amount = 2 },
      { type = "item", name = "copper-plate", amount = 3 },
      { type = "item", name = "copper-cable", amount = 20 },
    },
    results = {
      { type = "item", name = "network-cable", amount = 2 },
    },
  },

  {
    type = "recipe",
    name = "network-connector",
    localised_name = { "item-name.network-connector" },
    subgroup = "items-network",
    order = "ab[network-connector]",
    enabled = false,
    energy_required = 1,
    ingredients = {
      { type = "item", name = "electronic-circuit", amount = 2 },
      { type = "item", name = "network-cable",      amount = 1 },
    },
    results = {
      { type = "item", name = "network-connector", amount = 1 },
    },
  },


  {
    type = "recipe",
    name = "network-terminal",
    localised_name = { "recipe-name.network-terminal" },
    subgroup = "items-network",
    order = "b[network-terminal]",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "iron-plate",         amount = 8 },
      { type = "item", name = "electronic-circuit", amount = 5 },
      { type = "item", name = "network-cable",      amount = 6 },
    },
    results = {
      { type = "item", name = "network-terminal", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-production-combinator",
    localised_name = { "recipe-name.network-production-combinator" },
    subgroup = "items-network",
    order = "bz[network-production-combinator]",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "iron-plate",         amount = 8 },
      { type = "item", name = "electronic-circuit", amount = 5 },
      { type = "item", name = "network-cable",      amount = 6 },
    },
    results = {
      { type = "item", name = "network-production-combinator", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-inserter",
    localised_name = { "recipe-name.network-inserter" },
    subgroup = "items-network",
    order = "bza[network-inserter]",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "fast-inserter",      amount = 1 },
      { type = "item", name = "network-cable",      amount = 1 },
      { type = "item", name = "electronic-circuit", amount = 4 },
    },
    results = {
      { type = "item", name = "network-inserter", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-bulk-inserter",
    localised_name = { "recipe-name.network-bulk-inserter" },
    subgroup = "items-network",
    order = "bzb[network-bulk-inserter]",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = base_bulk_network_inserter_item.name, amount = 1 },
      { type = "item", name = "network-cable", amount = 2 },
      { type = "item", name = "electronic-circuit", amount = 8 },
    },
    results = {
      { type = "item", name = "network-bulk-inserter", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-server",
    localised_name = { "recipe-name.network-server" },
    subgroup = "items-network",
    order = "ba[network-server]",
    enabled = false,
    energy_required = 5,
    ingredients = {
      { type = "item", name = "iron-plate",         amount = 20 },
      { type = "item", name = "electronic-circuit", amount = 20 },
      { type = "item", name = "network-cable",      amount = 20 },
    },
    results = {
      { type = "item", name = "network-server", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-fluid-input",
    localised_name = { "recipe-name.network-fluid-input" },
    subgroup = "items-network",
    order = "bb[network-fluid-input]",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "pipe-to-ground",     amount = 1 },
      { type = "item", name = "iron-plate",         amount = 2 },
      { type = "item", name = "electronic-circuit", amount = 2 },
      { type = "item", name = "network-cable",      amount = 2 },
    },
    results = {
      { type = "item", name = "network-fluid-input", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-fluid-output",
    localised_name = { "recipe-name.network-fluid-output" },
    subgroup = "items-network",
    order = "bc[network-fluid-output]",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "pipe-to-ground",     amount = 1 },
      { type = "item", name = "iron-plate",         amount = 2 },
      { type = "item", name = "electronic-circuit", amount = 2 },
      { type = "item", name = "network-cable",      amount = 2 },
    },
    results = {
      { type = "item", name = "network-fluid-output", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-buffer-chest",
    localised_name = { "recipe-name.network-buffer-chest" },
    subgroup = "items-network",
    order = "c[network-buffer-chest]",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "electronic-circuit", amount = 10 },
      { type = "item", name = "network-cable",      amount = 10 },
      { type = "item", name = "iron-chest",         amount = 1 },
    },
    results = {
      { type = "item", name = "network-buffer-chest", amount = 1 },
    },
  },

  {
    type = "recipe",
    name = "network-unloading-train-stop",
    localised_name = { "recipe-name.network-unloading-train-stop" },
    subgroup = "items-network",
    order = "d[network-unloading-train-stop]",
    enabled = false,
    energy_required = 4,
    ingredients = {
      { type = "item", name = "train-stop", amount = 1 },
      { type = "item", name = "network-cable", amount = 10 },
      { type = "item", name = "electronic-circuit", amount = 10 },
      { type = "item", name = "steel-plate", amount = 5 },
    },
    results = {
      { type = "item", name = "network-unloading-train-stop", amount = 1 },
    },
  },

  -- One research unlocks the whole cable network toolset.
  {
    type = "technology",
    name = "items-network",
    localised_name = { "technology-name.items-network" },
    localised_description = { "technology-description.items-network" },
    icon = "__base__/graphics/technology/circuit-network.png",
    icon_size = 256,
    prerequisites = { "automation-science-pack", "electronics" },
    unit = {
      count = 10,
      ingredients = {
        { "automation-science-pack", 1 }
      },
      time = 15,
    },
    effects = {
      { type = "unlock-recipe", recipe = "network-cable" },
      { type = "unlock-recipe", recipe = "network-connector" },
      { type = "unlock-recipe", recipe = "network-terminal" },
      { type = "unlock-recipe", recipe = "network-inserter" },
      { type = "unlock-recipe", recipe = "network-bulk-inserter" },
      { type = "unlock-recipe", recipe = "network-production-combinator" },
      { type = "unlock-recipe", recipe = "network-server" },
      { type = "unlock-recipe", recipe = "network-fluid-input" },
      { type = "unlock-recipe", recipe = "network-fluid-output" },
      { type = "unlock-recipe", recipe = "network-buffer-chest" },
    },
    order = "c-z[items-network]",
  },
  {
    type = "technology",
    name = "network-player-supply",
    localised_name = { "technology-name.network-player-supply" },
    localised_description = { "technology-description.network-player-supply" },
    icon = "__base__/graphics/technology/circuit-network.png",
    icon_size = 256,
    prerequisites = { "logistic-science-pack", "items-network" },
    unit = {
      count = 100,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 }
      },
      time = 15,
    },
    effects = {
      { type = "character-inventory-slots-bonus", modifier = 30 },
      { type = "character-logistic-trash-slots",  modifier = 20 },
    },
    order = "c-z[network-player-supply]",
  },
  {
    type = "technology",
    name = "network-power-conductivity",
    localised_name = { "technology-name.network-power-conductivity" },
    localised_description = { "technology-description.network-power-conductivity" },
    icon = "__base__/graphics/technology/electric-energy-distribution-1.png",
    icon_size = 256,
    prerequisites = { "logistic-science-pack", "items-network" },
    unit = {
      count = 75,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 }
      },
      time = 15,
    },
    effects = {},
    order = "c-z[network-power-conductivity]",
  },
  {
    type = "technology",
    name = "network-train-unloading",
    localised_name = { "technology-name.network-train-unloading" },
    localised_description = { "technology-description.network-train-unloading" },
    icon = (data.raw["technology"]["railway"] and data.raw["technology"]["railway"].icon) or "__base__/graphics/technology/railway.png",
    icon_size = (data.raw["technology"]["railway"] and data.raw["technology"]["railway"].icon_size) or 256,
    prerequisites = { "railway", "items-network" },
    unit = {
      count = 100,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 }
      },
      time = 15,
    },
    effects = {
      { type = "unlock-recipe", recipe = "network-unloading-train-stop" },
    },
    order = "c-z[network-train-unloading]",
  },
})
