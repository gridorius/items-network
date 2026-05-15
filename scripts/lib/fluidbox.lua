local Fluidbox = {}
Fluidbox.__index = Fluidbox

function Fluidbox:new(entity)
    local self = setmetatable({}, Fluidbox)
    self.entity = entity
    self.fluids = {}
    self:Update()
    return self
end

function Fluidbox:Update()
    self.fluids = {}
    if self.entity and self.entity.valid and self.entity.fluidbox then
        for i = 1, #self.entity.fluidbox do
            local fluid = self.entity.fluidbox[i]
            if fluid then
                if not self.fluids[fluid.name] then
                    self.fluids[fluid.name] = {}
                end
                self.fluids[fluid.name][fluid.temperature] = fluid.amount
            end
        end
    end
end

function Fluidbox:GetFluids()
    self:Update()
    return self.fluids
end

function Fluidbox:Insert(name, temperature, amount)
    self:Update()
    local has_box = self.fluids[name] and self.fluids[name][temperature] ~= nil
    if self.entity and self.entity.valid and self.entity.fluidbox then
        if has_box then
            for i = 1, #self.entity.fluidbox do
                local fluid = self.entity.fluidbox[i]
                local capacity = self.entity.fluidbox.get_capacity(i)
                local to_insert = math.min(amount, capacity - (fluid and fluid.amount or 0))
                if fluid and fluid.name == name and fluid.temperature == temperature then
                    self.entity.fluidbox[i] = {
                        name = name,
                        temperature = temperature,
                        amount = fluid.amount + to_insert
                    }
                    return to_insert
                end
            end
        else
            for i = 1, #self.entity.fluidbox do
                local fluid = self.entity.fluidbox[i]
                if not fluid or not fluid.name then
                    local capacity = self.entity.fluidbox.get_capacity(i)
                    local to_insert = math.min(amount, capacity)
                    self.entity.fluidbox[i] = {
                        name = name,
                        temperature = temperature,
                        amount = to_insert
                    }
                    return to_insert
                end
            end
        end
    end
    return 0
end

function Fluidbox:Clear()
    if self.entity and self.entity.valid and self.entity.fluidbox then
        for i = 1, #self.entity.fluidbox do
            self.entity.fluidbox[i] = nil
        end
    end
    self:Update()
end

function Fluidbox:GetFluidAmount(name, temperature)
    self:Update()
    if temperature then
        return self.fluids[name] and self.fluids[name][temperature] or 0
    end

    local total = 0
    if self.fluids[name] then
        for _, amount in pairs(self.fluids[name]) do
            total = total + amount
        end
    end
    return total
end

function Fluidbox:RemoveFluid(name, temperature)
    self:Update()
    if self.entity and self.entity.valid and self.entity.fluidbox then
        for i = 1, #self.entity.fluidbox do
            local fluid = self.entity.fluidbox[i]
            if fluid and fluid.name == name and (not temperature or fluid.temperature == temperature) then
                self.entity.fluidbox[i] = nil
            end
        end
    end
    self:Update()
end

return Fluidbox
