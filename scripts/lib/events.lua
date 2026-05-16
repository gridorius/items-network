local Events = {}
Events.__index = Events

function Events:new()
    local self = setmetatable({}, Events)
    self.handlers = {}
    self.nth_tick_handlers = {}
    self.next_handler_id = 1
    return self
end

function Events:on_event(name, event, handler_id)
    if self.handlers[name] then
        for id, handler_data in pairs(self.handlers[name]) do
            handler_data.handler(event, handler_id)
            if handler_data.single then
                self.handlers[name][id] = nil
            end
        end
    end
end

function Events:on_nth_tick_event(tick, event, handler_id)
    if self.nth_tick_handlers[tick] then
        for id, handler_data in pairs(self.nth_tick_handlers[tick]) do
            handler_data.handler(event, handler_id)
            if handler_data.single then
                self.nth_tick_handlers[tick][id] = nil
            end
        end
    end
end

function Events:OnNthTick(tick, handler)
    local handler_id = self:GetHandlerId()
    if not self.nth_tick_handlers[tick] then
        self.nth_tick_handlers[tick] = {}
        script.on_nth_tick(tick, function(event) self:on_nth_tick_event(tick, event, handler_id) end)
    end
    self.nth_tick_handlers[tick][handler_id] = {
        handler = handler,
        single = false
    }
end

function Events:GetHandlerId()
    local id = self.next_handler_id
    self.next_handler_id = self.next_handler_id + 1
    return id
end

function Events:On(event_name, handler, single)
    local handler_id = self:GetHandlerId()
    if not self.handlers[event_name] then
        self.handlers[event_name] = {}
        script.on_event(event_name, function(event) self:on_event(event_name, event, handler_id) end)
    end

    self.handlers[event_name][handler_id] = {
        handler = handler,
        single = single or false
    }
end

function Events:Remove(event, id)
    if self.handlers[event] and self.handlers[event][id] then
        self.handlers[event][id] = nil
    end
end

function Events:RemoveNthTickEvent(tick, id)
    if self.nth_tick_handlers[tick] and self.nth_tick_handlers[tick][id] then
        self.nth_tick_handlers[tick][id] = nil
    end
end

return Events
