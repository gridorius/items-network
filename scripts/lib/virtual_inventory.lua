local VirtualInventory = {}
VirtualInventory.__index = VirtualInventory

function VirtualInventory:new(inventory_id)
    local self = setmetatable({}, VirtualInventory)
    local storage_inventory = self:AttachOrCreateStorage(inventory_id)
    self.inventory_id = inventory_id
    self.items = storage_inventory.items
    self.fluids = storage_inventory.fluids
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
        local wrapper = Gridorius.Fluidbox:new(entity)
        local contents = wrapper:GetFluids()
        for name, temperatures in pairs(contents) do
            for temperature, amount in pairs(temperatures) do
                self:InsertFluid(name, amount, temperature)
            end
        end
        wrapper:Clear()
    end
end

function VirtualInventory:BuildSignals()
    local signals = {}
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
    for _, fluid in pairs(self:GetFluids()) do
        table.insert(signals, {
            value = {
                type = "fluid",
                name = fluid.name,
                temperature = fluid.temperature,
            },
            min = fluid.amount,
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

function VirtualInventory:InsertFluid(name, amount, temperature)
    self.fluids[name] = self.fluids[name] or {}
    self.fluids[name][temperature] = amount + (self.fluids[name][temperature] or 0)
    return self
end

function VirtualInventory:GetItemCount(name, quality)
    return self.items[name] and self.items[name][quality or "normal"] or 0
end

function VirtualInventory:GetFluidAmount(name, temperature)
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

function VirtualInventory:MoveToInventory(item, count, inventory)
    local inventory_count = self:GetItemCount(item.name, item.quality or "normal")
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

function VirtualInventory:ProcessMachine(machine, use_fuels)
    if machine and machine.valid then
        local input_inventory = machine.get_inventory(defines.inventory.crafter_input)
        local output_inventory = machine.get_inventory(defines.inventory.crafter_output)
        local fuel_inventory = machine.get_inventory(defines.inventory.fuel)
        local fluidbox = Gridorius.Fluidbox:new(machine)
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
                    local max_move = math.ceil(prototypes.item[ingredient.name].stack_size / 5)
                    self:MoveToInventory({ name = ingredient_name, quality = ingredient_quality }, max_move,
                        input_inventory)
                elseif ingredient.type == "fluid" and fluidbox and not fluidbox.is_full() then
                    local fluid_name = ingredient.name
                    local fluid_temperature = ingredient.temperature
                    local inventory_amount = self:GetFluidAmount(fluid_name, fluid_temperature)
                    local max_move = 1000

                    if inventory_amount > 0 then
                        local insert_amount = math.min(inventory_amount, max_move)
                        local inserted = fluidbox:Insert(fluid_name, fluid_temperature, insert_amount)
                        if inserted > 0 then
                            self:RemoveFluid(fluid_name, inserted, fluid_temperature)
                        end
                    end
                end
                ::next_ingriedient::
            end
        end

        -- handle fuels
        if machine.active and burner and fuel_inventory and not fuel_inventory.is_full() and burner.remaining_burning_fuel < 100 then
            for fuel_name, use in pairs(use_fuels) do
                if use then
                    self:MoveToInventory({ name = fuel_name }, 1, fuel_inventory)
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
                    local fluid_name = product.name
                    local fluid_temperature = product.temperature
                    local produced_amount = fluidbox:GetFluidAmount(fluid_name, fluid_temperature)
                    if produced_amount > 0 then
                        self:InsertFluid(fluid_name, produced_amount, fluid_temperature)
                        fluidbox:RemoveFluid(fluid_name, fluid_temperature)
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

function VirtualInventory:ProcessBufferChest(chest)
    local point = chest.get_requester_point()
    local filters = point.filters
    local inventory = Gridorius.Inventory:new(chest.get_inventory(defines.inventory.chest))
    local trash = chest.get_inventory(defines.inventory.logistic_container_trash)
    self:CollectInventory(trash)

    if inventory:IsFull() or not filters then
        return
    end

    for i = 1, #filters do
        local filter = filters[i]
        if filter and filter.name then
            local name = filter.name
            local quality = filter.quality or "normal"
            local count = filter.count
            local current_count = inventory:GetItemCount(name, quality)
            if current_count < count then
                local needed = count - current_count
                local moved = self:MoveToInventory({ name = name, quality = quality }, needed, inventory.inventory)
                if moved < needed then
                    break
                end
            end
        end
    end
end

return VirtualInventory
