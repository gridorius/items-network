local CombinedInventory = {}
CombinedInventory.__index = CombinedInventory

function CombinedInventory:new()
    local self = setmetatable({}, CombinedInventory)
    self.inventories = {}
    self.insert_fluid_per_operation = settings.global.insert_fluid_per_operation.value or 20
    self.insert_item_stack_per_operation = settings.global.insert_item_stack_per_operation.value or 0.5

    Gridorius.Events:On(defines.events.on_runtime_mod_setting_changed, function(event)
        if event.setting == "insert_fluid_per_operation" then
            self.insert_fluid_per_operation = settings.global.insert_fluid_per_operation.value
        elseif event.setting == "insert_item_stack_per_operation" then
            self.insert_item_stack_per_operation = settings.global.insert_item_stack_per_operation.value
        end
    end)

    return self
end

function CombinedInventory:AddInventory(inventory)
    table.insert(self.inventories, inventory)
end

function CombinedInventory:RemoveInventory(inventory)
    for i, inv in ipairs(self.inventories) do
        if inv == inventory then
            table.remove(self.inventories, i)
            return
        end
    end
end

function CombinedInventory:Reset()
    self.inventories = {}
end

-- function CombinedInventory:BuildSignals()
--     local signals = {}
--     for _, inventory in ipairs(self.inventories) do
--         local inv_signals = inventory:BuildSignals()
--         for _, signal in ipairs(inv_signals) do
--             local existing_signal = signals[signal.name]
--             if existing_signal then
--                 existing_signal.count = existing_signal.count + signal.count
--             else
--                 signals[signal.name] = { name = signal.name, count = signal.count }
--             end
--         end
--     end
--     return signals
-- end

function CombinedInventory:GetItemCount(item_stack)
    local count = 0
    for _, inventory in ipairs(self.inventories) do
        count = count + inventory.get_item_count(item_stack)
    end
    return count
end

function CombinedInventory:Insert(item_stack)
    local remaining = item_stack.count
    for _, inventory in ipairs(self.inventories) do
        if remaining <= 0 then break end
        local inserted = inventory.insert(item_stack)
        remaining = remaining - inserted
    end
    return item_stack.count - remaining
end

function CombinedInventory:Remove(item_stack)
    local remaining = item_stack.count
    for _, inventory in ipairs(self.inventories) do
        if remaining <= 0 then break end
        local removed = inventory.remove(item_stack)
        remaining = remaining - removed
    end
    return item_stack.count - remaining
end

function CombinedInventory:Collect(inventory)
    if not (inventory and inventory.valid) then
        return
    end

    local contents = inventory.get_contents()
    for _, item in pairs(contents) do
        local inserted = self:Insert(item)
        if inserted > 0 then
            inventory.remove({ name = item.name, count = inserted })
        end
    end
end

function CombinedInventory:MoveToInventory(inventory, item_stack)
    local count = self:GetItemCount(item_stack)
    if count <= 0 then
        return 0
    end

    local to_insert = math.min(count, item_stack.count)
    local inserted = inventory.insert({ name = item_stack.name, count = to_insert })
    if inserted <= 0 then
        return 0
    end

    local removed = self:Remove({ name = item_stack.name, count = inserted })
    return removed
end

function CombinedInventory:ProcessTurret(inventory, use_ammo)
    if not (inventory and inventory.valid) then
        return
    end

    local current_count = inventory.get_item_count()
    if current_count >= 10 then
        return
    end

    for ammo_name, use in pairs(use_ammo) do
        if use then
            local moved = self:MoveToInventory(inventory, { name = ammo_name, count = 10 })
            if moved > 0 then
                break
            end
        end
    end
end

function CombinedInventory:ProcessLab(lab)
    if not (lab and lab.valid) then
        return
    end

    local input_inventory = lab.get_inventory(defines.inventory.lab_input)

    if not (input_inventory and input_inventory.valid) then
        return
    end

    for _, science_pack_name in ipairs(lab.prototype.lab_inputs) do
        if science_pack_name then
            local in_lab_count = input_inventory.get_item_count(science_pack_name)
            local needed = 2 - in_lab_count
            if needed > 0 then
                local moved = self:MoveToInventory(input_inventory, { name = science_pack_name, count = needed })
                if moved < needed then
                    break
                end
            end
        end
    end
end

function CombinedInventory:ProcessMachineItems(machine, use_fuels)
    if machine and machine.valid then
        if machine.type == "lab" then
            self:ProcessLab(machine)
            return
        end

        local input_inventory = machine.get_inventory(defines.inventory.crafter_input)
        local output_inventory = machine.get_inventory(defines.inventory.crafter_output)
        local fuel_inventory = machine.get_inventory(defines.inventory.fuel)
        local burner = machine.burner
        local recipe, recipe_quality = machine.get_recipe()
        recipe_quality = recipe_quality and recipe_quality.name or "normal"

        -- handle recipe
        if recipe and machine.active and input_inventory then
            for _, ingredient in pairs(recipe.ingredients) do
                if ingredient.type == "item" then
                    local ingredient_quality = recipe_quality or "normal"
                    if not input_inventory.can_insert(ingredient.name) then
                        goto next_ingriedient
                    end
                    local ingredient_name = ingredient.name
                    local max_move = math.ceil(prototypes.item[ingredient.name].stack_size *
                        self.insert_item_stack_per_operation)
                    local current_count = input_inventory.get_item_count(ingredient_name)
                    if current_count >= ingredient.amount * 2 then
                        goto next_ingriedient
                    end
                    self:MoveToInventory(input_inventory,
                        { name = ingredient_name, quality = ingredient_quality, count = max_move })
                end
                ::next_ingriedient::
            end
        end

        -- handle fuels
        if machine.active and burner and fuel_inventory and fuel_inventory.is_empty() and burner.remaining_burning_fuel < 100 then
            for fuel_name, use in pairs(use_fuels) do
                if use then
                    self:MoveToInventory(fuel_inventory, { name = fuel_name, count = 2 })
                end
            end
        end

        -- collect burning products
        if burner and burner.burnt_result_inventory and not burner.burnt_result_inventory.is_empty() then
            self:Collect(burner.burnt_result_inventory)
        end

        -- collect output items
        if output_inventory and not output_inventory.is_empty() then
            self:Collect(output_inventory)
        end
    end
end

return CombinedInventory
