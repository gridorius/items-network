local Events = {}
Events.__index = Events

function Events:new()
    local self = setmetatable({}, Events)
    self.handlers = {}
    self.nth_tick_handlers = {}
    self.next_handler_id = 1
    return self
end

function Events:UseEvents(...)
    local event_names = { ... }
    for _, event_name in pairs(event_names) do
        script.on_event(event_name, function(event) self:on_event(event_name, event) end)
    end
end

function Events:UseTick(...)
    local tick_intervals = { ... }
    for _, tick in pairs(tick_intervals) do
        script.on_nth_tick(tick, function(event) self:on_nth_tick_event(tick, event) end)
        self.nth_tick_handlers[tick] = {}
    end
end

function Events:on_event(name, event)
    for handler_id, handler_data in pairs(self.handlers) do
        if handler_data.events[name] then
            handler_data.events[name](event, handler_id)
            if handler_data.single then
                self.handlers[handler_id] = nil
            end
        end
    end
end

function Events:on_nth_tick_event(tick, event)
    if self.nth_tick_handlers[tick] then
        for id, handler_data in pairs(self.nth_tick_handlers[tick]) do
            handler_data.handler(event, id)
            if handler_data.single then
                self.nth_tick_handlers[tick][id] = nil
            end
        end
    end
end

function Events:OnClick(handler)
    local handler_id = self:GetHandlerId()
    local event_name = defines.events.on_gui_click
    self:On(event_name, handler)
    return handler_id
end

function Events:OnTaggedClick(handler)
    local handler_id = self:GetHandlerId()
    local event_name = defines.events.on_gui_click
    self:On(event_name, function(event)
        if not event.element or not event.element.valid then return end
        local tags = event.element.tags
        if tags then
            handler(tags, event)
        end
    end)
    return handler_id
end

function Events:OnNthTick(tick, handler)
    if not self.nth_tick_handlers[tick] then
        return nil
    end

    local handler_id = self:GetHandlerId()
    self.nth_tick_handlers[tick][handler_id] = {
        handler = handler,
        single = false
    }
    return handler_id
end

function Events:GetHandlerId()
    local id = self.next_handler_id
    self.next_handler_id = self.next_handler_id + 1
    return id
end

function Events:On(event_name, handler, single)
    local handler_id = self:GetHandlerId()
    self.handlers[handler_id] = {
        events = {},
        single = single or false,
    }

    if type(event_name) == "table" then
        for _, name in pairs(event_name) do
            self.handlers[handler_id].events[name] = handler
        end
        return handler_id
    else
        self.handlers[handler_id].events[event_name] = handler
    end

    return handler_id
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
