local VirtualInventory = {}
VirtualInventory.__index = VirtualInventory

function VirtualInventory:new(inventory_id)
    local self = setmetatable({}, VirtualInventory)
    local storage_inventory = self:AttachOrCreateStorage(inventory_id)
    self.inventory_id = inventory_id
    self.items = storage_inventory.items
    self.fluids = storage_inventory.fluids
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

function VirtualInventory:AttachOrCreateStorage(inventory_id)
    storage.next_inventory_id = storage.next_inventory_id or 1
    storage.inventories = storage.inventories or {}
    if not inventory_id then
        inventory_id = storage.next_inventory_id
        storage.next_inventory_id = storage.next_inventory_id + 1
    end
    local storage_inventory = storage.inventories[inventory_id]
    if not storage_inventory then
        storage_inventory = {
            items = {},
            fluids = {},
        }
        storage.inventories[inventory_id] = storage_inventory
    end
    return storage_inventory
end

function VirtualInventory:Destroy()
    storage.inventories[self.inventory_id] = nil
end

function VirtualInventory:IsEmpty()
    for _, qualities in pairs(self.items) do
        for _, amount in pairs(qualities) do
            if amount > 0 then
                return false
            end
        end
    end
    for _, temperatures in pairs(self.fluids) do
        for _, amount in pairs(temperatures) do
            if amount > 0 then
                return false
            end
        end
    end
    return true
end

function VirtualInventory:GetFormattedInventory()
    local formatted = {}
    for name, qualities in pairs(self.items) do
        for quality, amount in pairs(qualities) do
            table.insert(formatted, {
                type = "item",
                name = name,
                quality = quality,
                count = amount
            })
        end
    end
    for name, temperatures in pairs(self.fluids) do
        for temperature, amount in pairs(temperatures) do
            table.insert(formatted, {
                type = "fluid",
                name = name,
                temperature = temperature,
                amount = amount
            })
        end
    end
    return formatted
end

function VirtualInventory:CollectInventory(inventory)
    if inventory.valid and not inventory.is_empty() then
        local contents = inventory.get_contents()
        self:InsertItems(contents)
        inventory.clear()
    end
end

function VirtualInventory:CollectFluidbox(entity)
    if entity and entity.valid then
        for i = 1, #entity.fluidbox do
            local fluid = entity.fluidbox[i]
            if fluid and fluid.name and fluid.amount > 0 then
                self:InsertFluid(fluid.name, fluid.amount, fluid.temperature)
                entity.fluidbox[i] = nil
            end
        end
    end
end

function VirtualInventory:BuildSignals()
    local signals = {}
    for name, amount in pairs(self:GetTotalFluids()) do
        table.insert(signals, {
            value = {
                type = "fluid",
                name = name,
                quality = "normal",
            },
            min = amount,
        })
    end

    for _, item in pairs(self:GetItems()) do
        table.insert(signals, {
            value = {
                type = "item",
                name = item.name,
                quality = item.quality,
            },
            min = item.count,
        })
    end

    return signals
end

function VirtualInventory:InsertItem(name, amount, quality)
    quality = quality or "normal"
    self.items[name] = self.items[name] or {}
    self.items[name][quality] = amount + (self.items[name][quality] or 0)
    return self
end

function VirtualInventory:InsertItems(items)
    for _, item in pairs(items) do
        self:InsertItem(item.name, item.count, item.quality)
    end
    return self
end

function VirtualInventory:ParseTemperature(name, temperature)
    if not temperature then
        temperature = "default"
    elseif temperature == self.fluids[name].default_temperature then
        temperature = "default"
    end
    return temperature
end

function VirtualInventory:InsertFluid(name, amount, temperature)
    if not self.fluids[name] then
        local default_temperature = prototypes.fluid[name] and prototypes.fluid[name].default_temperature or 25
        self.fluids[name] = {
            ["default_temperature"] = default_temperature,
            ["default"] = 0
        }
    end
    temperature = self:ParseTemperature(name, temperature)
    self.fluids[name] = self.fluids[name] or {}
    self.fluids[name][temperature] = amount + (self.fluids[name][temperature] or 0)
    return self
end

function VirtualInventory:GetItemCount(name, quality)
    return self.items[name] and self.items[name][quality or "normal"] or 0
end

function VirtualInventory:GetFluidAmount(name, temperature)
    temperature = temperature or "default"
    return self.fluids[name] and self.fluids[name][temperature] or 0
end

function VirtualInventory:GetItems()
    local items = {}
    for name, qualities in pairs(self.items) do
        for quality, amount in pairs(qualities) do
            table.insert(items, {
                name = name,
                quality = quality,
                count = amount
            })
        end
    end
    return items
end

function VirtualInventory:GetFluids()
    local fluids = {}
    for name, temperatures in pairs(self.fluids) do
        for temperature, amount in pairs(temperatures) do
            table.insert(fluids, {
                name = name,
                temperature = temperature,
                amount = amount
            })
        end
    end
    return fluids
end

function VirtualInventory:GetTotalFluids()
    local fluids = {}
    for name, temperatures in pairs(self.fluids) do
        for temperature, amount in pairs(temperatures) do
            fluids[name] = fluids[name] or 0
            fluids[name] = fluids[name] + amount
        end
    end
    return fluids
end

function VirtualInventory:RemoveItem(name, amount, quality)
    local current_count = self:GetItemCount(name, quality)
    if current_count > 0 then
        if current_count > amount then
            self.items[name][quality or "normal"] = current_count - amount
            return amount
        else
            self.items[name][quality or "normal"] = 0
            return current_count
        end
    end
    return 0
end

function VirtualInventory:RemoveFluid(name, amount, temperature)
    if not self.fluids[name] then
        return 0
    end
    temperature = self:ParseTemperature(name, temperature)
    local current_amount = self:GetFluidAmount(name, temperature)
    if current_amount > 0 then
        if current_amount > amount then
            self.fluids[name][temperature] = current_amount - amount
            return amount
        else
            self.fluids[name][temperature] = 0
            return current_amount
        end
    end
    return 0
end

function VirtualInventory:GetMaxItemQuality(name)
    local qualities = self.items[name]
    if not qualities then
        return nil
    end
    local quality_order = prototypes.quality.order or {}

    local max_quality = "normal"
    for quality, amount in pairs(qualities) do
        if amount > 0 then
            if quality_order[quality] and quality_order[max_quality] then
                if quality_order[quality] > quality_order[max_quality] then
                    max_quality = quality
                end
            elseif quality_order[quality] and not quality_order[max_quality] then
                max_quality = quality
            end
        end
    end
    return max_quality
end

function VirtualInventory:MoveToInventory(item, count, inventory)
    local inventory_count = self:GetItemCount(item.name, item.quality)
    if inventory_count > 0 then
        local move_amount = math.min(inventory_count, count)
        local inserted = inventory.insert({
            name = item.name,
            count = move_amount,
            quality = item.quality
        })
        if inserted > 0 then
            self:RemoveItem(item.name, inserted, item.quality)
            return inserted
        end
    end
    return 0
end

function VirtualInventory:ProcessLab(lab)
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
                local moved = self:MoveToInventory({ name = science_pack_name }, needed, input_inventory)
                if moved < needed then
                    break
                end
            end
        end
    end
end

function VirtualInventory:ProcessTurret(inventory, use_ammo)
    if not (inventory and inventory.valid) then
        return
    end

    local current_count = inventory.get_item_count()
    if current_count > 10 then
        return
    end

    for ammo_name, use in pairs(use_ammo) do
        if use then
            local moved = self:MoveToInventory({ name = ammo_name }, 10, inventory)
            if moved > 0 then
                break
            end
        end
    end
end

function VirtualInventory:ProcessMachine(machine, use_fuels)
    if machine and machine.valid then
        if machine.type == "lab" then
            self:ProcessLab(machine)
            return
        end

        local input_inventory = machine.get_inventory(defines.inventory.crafter_input)
        local output_inventory = machine.get_inventory(defines.inventory.crafter_output)
        local fuel_inventory = machine.get_inventory(defines.inventory.fuel)
        local fluidbox = machine.fluidbox
        local burner = machine.burner
        local recipe, recipe_quality = machine.get_recipe()
        recipe_quality = recipe_quality and recipe_quality.name or "normal"
        local fluids_to_insert = {}

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
                    self:MoveToInventory({ name = ingredient_name, quality = ingredient_quality }, max_move,
                        input_inventory)
                elseif ingredient.type == "fluid" and fluidbox then
                    local fluid_name = ingredient.name
                    local fluid_temperature = ingredient.temperature
                    local inventory_amount = self:GetFluidAmount(fluid_name, fluid_temperature)
                    fluids_to_insert[fluid_name] = {
                        temperature = fluid_temperature,
                        amount = math.min(inventory_amount, self.insert_fluid_per_operation)
                    }
                end
                ::next_ingriedient::
            end
        end

        local insert_index = 1
        for name, data in pairs(fluids_to_insert) do
            local inserted = Gridorius.insert_fluid(fluidbox,
                { name = name, amount = data.amount, temperature = data.temperature }, insert_index, data.amount)
            if inserted > 0 then
                self:RemoveFluid(name, inserted, data.temperature)
            end
            insert_index = insert_index + 1
        end

        -- handle fuels
        if machine.active and burner and fuel_inventory and fuel_inventory.is_empty() and burner.remaining_burning_fuel < 100 then
            for fuel_name, use in pairs(use_fuels) do
                if use then
                    self:MoveToInventory({ name = fuel_name }, 2, fuel_inventory)
                end
            end
        end

        -- collect burning products
        if burner and burner.burnt_result_inventory and not burner.burnt_result_inventory.is_empty() then
            local contents = burner.burnt_result_inventory.get_contents()
            for _, item in pairs(contents) do
                self:InsertItem(item.name, item.count, item.quality)
            end
            burner.burnt_result_inventory.clear()
        end


        -- collect fluid products
        if recipe and fluidbox then
            for _, product in pairs(recipe.products) do
                if product.type == "fluid" then
                    for i = 1, #fluidbox do
                        local fluid = fluidbox[i]
                        if fluid and fluid.name and fluid.name == product.name then
                            local amount = fluid.amount
                            self:InsertFluid(product.name, amount, product.temperature)
                            fluidbox[i] = nil
                        end
                    end
                end
            end
        end

        -- collect output items
        if output_inventory and not output_inventory.is_empty() then
            self:CollectInventory(output_inventory)
        end
    end
end

function VirtualInventory:ProcessLogisticInventory(entity, inventory, trash)
    local point = entity.get_requester_point()

    if not point or not point.enabled then
        return
    end

    if trash and trash.valid then
        self:CollectInventory(trash)
    end
    if not point then
        return
    end

    local filters = point.filters
    if not filters then
        return
    end

    if not inventory or not inventory.valid or inventory.is_full() or not filters then
        return
    end

    for i = 1, #filters do
        local filter = filters[i]
        if filter and filter.name then
            local name = filter.name
            local quality = filter.quality or "normal"
            local count = filter.count
            local current_count = inventory.get_item_count({ name = name, quality = quality })
            if current_count < count then
                local needed = count - current_count
                self:MoveToInventory({ name = name, quality = quality }, needed, inventory)
            end
        end
    end
end

function VirtualInventory:ProcessBufferChest(chest)
    local inventory = chest.get_inventory(defines.inventory.chest)
    local trash = chest.get_inventory(defines.inventory.logistic_container_trash)
    self:ProcessLogisticInventory(chest, inventory, trash)
end

function VirtualInventory:ProcessPlayer(player)
    local inventory = player.get_main_inventory()
    local trash = player.get_inventory(defines.inventory.character_trash)
    self:ProcessLogisticInventory(player, inventory, trash)
end

return VirtualInventory
