local VirtualInventory = {}
VirtualInventory.__index = VirtualInventory

function VirtualInventory:new(inventory_id)
    local self = setmetatable({}, VirtualInventory)
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
    self.inventory_id = inventory_id
    self.items = storage_inventory.items
    self.fluids = storage_inventory.fluids
    return self
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
    self.items[name] = self.items[name] or {}
    self.items[name][quality or "normal"] = amount
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
    self.fluids[name][temperature] = amount
    return self
end

function VirtualInventory:ItemExists(name, quality)
    return self.items[name] and self.items[name][quality or "normal"] > 0
end

function VirtualInventory:FluidExists(name, temperature)
    return self.fluids[name] and self.fluids[name][temperature] > 0
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
    if self:ItemExists(name, quality) then
        local item_count = self.items[name][quality or "normal"]
        if item_count > amount then
            self.items[name][quality or "normal"] = item_count - amount
            return amount
        else
            self.items[name][quality or "normal"] = 0
            return item_count
        end
    end
    return 0
end

function VirtualInventory:RemoveFluid(name, amount, temperature)
    if self:FluidExists(name, temperature) then
        local fluid_amount = self.fluids[name][temperature]
        if fluid_amount > amount then
            self.fluids[name][temperature] = fluid_amount - amount
            return amount
        else
            self.fluids[name][temperature] = 0
            return fluid_amount
        end
    end
    return 0
end

return VirtualInventory
