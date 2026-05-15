local IngameState = {}
IngameState.__index = IngameState

function IngameState:new()
    local self = setmetatable({}, IngameState)
    self.shared = {}
    self.players = {}
    return self
end

function IngameState:set(key, value)
    self.shared[key] = value
    return self
end

function IngameState:get(key, default)
    return self.shared[key] or default
end

function IngameState:set_player(player_index, key, value)
    if not self.players[player_index] then
        self.players[player_index] = {}
    end
    self.players[player_index][key] = value
    return self
end

function IngameState:get_player(player_index, key, default)
    if not self.players[player_index] then
        return default
    end
    return self.players[player_index][key] or default
end

return IngameState