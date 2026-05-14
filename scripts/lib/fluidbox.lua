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

function Fluidbox:FluidExists(name, temperature)
    if temperature then
        return self.fluids[name] and self.fluids[name][temperature] and self.fluids[name][temperature] > 0
    end

    local total = 0
    if self.fluids[name] then
        for _, amount in pairs(self.fluids[name]) do
            total = total + amount
        end
    end
    return total > 0
end

function Fluidbox:GetFluid(name, temperature)
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

return Fluidbox