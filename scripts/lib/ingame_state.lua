local IngameState = {}
IngameState.__index = IngameState

function IngameState:new()
    local self = setmetatable({}, IngameState)
    self.data = {}
    return self
end

function IngameState:set(key, value)
    self.data[key] = value
    return self
end

function IngameState:get(key, default)
    return self.data[key] or default
end

return IngameState