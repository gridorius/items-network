local Dictionary = {}
Dictionary.__index = Dictionary

function Dictionary:new(items)
    local self = setmetatable({}, Dictionary)
    self.items = items or {}
    self.length = 0
    for _ in pairs(self.items) do
        self.length = self.length + 1
    end
    return self
end

function Dictionary:Set(key, value)
    if self.items[key] == nil then
        self.length = self.length + 1
    end
    self.items[key] = value
end

function Dictionary:Get(key)
    return self.items[key]
end

function Dictionary:Remove(key)
    if self.items[key] ~= nil then
        self.length = self.length - 1
    end
    self.items[key] = nil
    return self
end

function Dictionary:ForEach(callback)
    for key, value in pairs(self.items) do
        callback(value, key)
    end
    return self
end

function Dictionary:Select(callback)
    local result = Dictionary:new()
    for key, value in pairs(self.items) do
        result:Set(key, callback(value, key))
    end
    return result
end

function Dictionary:Where(callback)
    local result = Dictionary:new()
    for key, value in pairs(self.items) do
        if callback(value, key) then
            result:Set(key, value)
        end
    end
    return result
end

function Dictionary:Merge(data)
    for key, value in pairs(data) do
        self:Set(key, value)
    end
    return self
end

function Dictionary:Keys()
    local result = {}
    for key, _ in pairs(self.items) do
        table.insert(result, key)
    end
    return result
end

function Dictionary:Values()
    local result = {}
    for _, value in pairs(self.items) do
        table.insert(result, value)
    end
    return result
end

function Dictionary:Count()
    return self.length
end

function Dictionary:Clear()
    self.items = {}
    self.length = 0
end

return Dictionary