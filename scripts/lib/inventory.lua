local Inventory = {}
Inventory.__index = Inventory

function Inventory:new(inventory)
    local self = setmetatable({}, Inventory)
    self.inventory = inventory
    self.items = {}
    self:Update()
    return self
end

function Inventory:IsFull()
    if self.inventory and self.inventory.valid then
        return self.inventory.is_full()
    end
    return false
end

function Inventory:Update()
    self.items = {}
    if self.inventory and self.inventory.valid then
        for _, item in pairs(self.inventory.get_contents()) do
            local name = item.name
            local quality = item.quality and item.quality.name or "normal"
            if not self.items[name] then
                self.items[name] = {}
            end
            if not self.items[name][quality] then
                self.items[name][quality] = 0
            end
            self.items[name][quality] = self.items[name][quality] + item.count
        end
    end
end

function Inventory:GetItemCount(name, quality)
    self:Update()
    quality = quality or "normal"
    if self.items[name] and self.items[name][quality] then
        return self.items[name][quality]
    end
    return 0
end

function Inventory:Insert(name, count, quality)
    quality = quality or "normal"
    if self.inventory and self.inventory.valid then
        local stack = {name = name, count = count, quality = quality}
        return self.inventory.insert(stack)
    end
    return 0
end

return Inventory