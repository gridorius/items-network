local Gui = {}
Gui.__index = Gui

function Gui:new()
    local self = setmetatable({}, Gui)
    self.stylesheet = {
        default_frame = {
            padding = 12,
            horizontally_stretchable = true,
            vertically_stretchable = true,
            minimal_width = 200,
            minimal_height = 100,
        },
        frame_title = {
            font = "default-bold",
            top_padding = 8,
            bottom_padding = 8,
        },
    }
    self.click_name_handlers = {}
    self.click_tags_handlers = {}
    self.interface_bindings = {}
    self.delay_queue = {}

    script.on_event(defines.events.on_gui_click, function(event) self:on_gui_click_handler(event) end)
    script.on_event(defines.events.on_gui_opened, function(event) self:on_gui_opened_handler(event) end)
    script.on_event(defines.events.on_gui_closed, function(event) self:on_gui_closed_handler(event) end)
    script.on_nth_tick(1, function(event) self:on_tick_handler(event) end)
    return self
end

-- #region Gui event handlers
function Gui:on_gui_click_handler(event)
    local handler = self.click_name_handlers[event.element.name]
    if handler then
        handler(event)
    end
    local tags = event.element.tags
    if tags then
        for i = 1, #self.click_tags_handlers do
            local tag_handler = self.click_tags_handlers[i]
            tag_handler(tags, event)
        end
    end

    if event.element and event.element.valid and event.element.name == "close_button" then
        self:CloseInterface(game.get_player(event.player_index))
    end

    return self
end

function Gui:on_tick_handler(event)
    for player_index, queue in pairs(self.delay_queue) do
        local bindings = queue[event.tick]
        if bindings then
            local player = game.get_player(player_index)
            for execute_after, binding in pairs(bindings) do
                if game.tick >= execute_after then
                    self:RenderInterface(player, binding)
                    queue[execute_after] = nil
                end
            end
        end
    end
end

function Gui:on_gui_opened_handler(event)
    local entity = event.entity
    if entity and entity.valid then
        local binding = self.interface_bindings[entity.name]
        if binding then
            if binding.delay and binding.delay > 0 then
                self.delay_queue[event.player_index] = self.delay_queue[event.player_index] or {}
                self.delay_queue[event.player_index][game.tick + binding.delay] = binding
            end
            self:RenderInterface(game.get_player(event.player_index), binding)
        end
    end
    return self
end

function Gui:on_gui_closed_handler(event)
    self:CloseInterface(game.get_player(event.player_index))
    return self
end

function Gui:on_tagged_click(handler)
    table.insert(self.click_tags_handlers, handler)
    return self
end

-- #endregion
--#region Gui operations

function Gui:RenderInterface(player, binding)
    self:CloseInterface(player)
    self.current_interface = binding.interface:RenderRoot(player, binding.target(player))
    if binding.replace then
        player.opened = self.current_interface.element
    end
end

function Gui:BindInterface(entity_name, interface, target, replace, delay)
    self.interface_bindings[entity_name] = {
        interface = interface,
        target = target,
        delay = delay or 0,
        replace = replace or false,
    }
    return self
end

function Gui:CloseInterface(player)
    player.opened = nil
    if self.current_interface then
        self.current_interface.element.destroy()
        self.current_interface = nil
    end
end

function Gui:SetStylesheet(stylesheet)
    self.stylesheet = stylesheet
    return self
end

function Gui:ApplyStyles(element, classes)
    for _, class in pairs(classes) do
        local style = self.stylesheet[class]
        if style then
            for key, value in pairs(style) do
                element.style[key] = value
            end
        end
    end
end

--#endregion
--#region Element creation

function Gui:CreateFrame(name, properties)
    return Gridorius.InterfaceBuilder:new(self, name, function(parent)
        return parent.add(Gridorius.MergeProperties({ type = "frame", name = name, direction = "vertical", draggable = true },
            properties))
    end)
end

function Gui:CreateDefaultFrame(name, title, properties)
    return
        Gridorius.InterfaceBuilder:new(self, name, function(parent)
            return parent.add(Gridorius.MergeProperties({ type = "frame", name = name, direction = "vertical", draggable = true },
                properties))
        end)
        :AfterCreate(function(frame)
            frame.auto_center = true
        end)
        :SetClasses({ "default_frame" })
        :AppendChild(
            self:CreateFlow(name .. "_titlebar", "horizontal")
            :AppendChildrens(
                self:CreateLabel(name .. "_title", title, {
                    style = "frame_title",
                }):AfterCreate(function(label)
                    label.drag_target = label.parent.parent
                end),

                self:CreateEmptyWidget(name .. "_drag", {
                    style = "draggable_space",
                }):AfterCreate(function(widget)
                    widget.style.horizontally_stretchable = true
                    widget.style.height = 24
                    widget.style.natural_width = 100
                    widget.drag_target = widget.parent.parent
                end),

                self:CreateCloseButton(name .. "_close_button")
            )
        )
end

function Gui:CreateFlow(name, direction, properties)
    direction = direction or "horizontal"
    return Gridorius.InterfaceBuilder:new(self, name, function(parent)
        return parent.add(Gridorius.MergeProperties({ type = "flow", name = name, direction = direction }, properties))
    end)
end

function Gui:CreateButton(name, caption, properties)
    return Gridorius.InterfaceBuilder:new(self, name, function(parent)
        return parent.add(Gridorius.MergeProperties({ type = "button", name = name, caption = caption }, properties))
    end)
end

function Gui:CreateCloseButton(properties)
    return Gridorius.InterfaceBuilder:new(self, "close_button", function(parent)
        return parent.add(Gridorius.MergeProperties({
                type = "sprite-button",
                name = "close_button",
                sprite = "utility/close",
                hovered_sprite = "utility/close_black",
                style = "frame_action_button",
                mouse_button_filter = { "left" }
            },
            properties))
    end)
end

function Gui:CreateSpriteButton(name, sprite, properties)
    return Gridorius.InterfaceBuilder:new(self, name, function(parent)
        return parent.add(Gridorius.MergeProperties({ type = "sprite-button", name = name, sprite = sprite }, properties))
    end)
end

function Gui:CreateLabel(name, caption, properties)
    return Gridorius.InterfaceBuilder:new(self, name, function(parent)
        return parent.add(Gridorius.MergeProperties({ type = "label", name = name, caption = caption }, properties))
    end)
end

function Gui:CreateEmptyWidget(name, properties)
    return Gridorius.InterfaceBuilder:new(self, name, function(parent)
        return parent.add(Gridorius.MergeProperties({ type = "empty-widget", name = name }, properties))
    end)
end

function Gui:CreateScroll(name, direction, properties)
    direction = direction or "vertical"
    return Gridorius.InterfaceBuilder:new(self, name, function(parent)
        return parent.add(Gridorius.MergeProperties({ type = "scroll-pane", name = name, direction = direction }, properties))
    end)
end

function Gui:CreateTable(name, column_count, properties)
    return Gridorius.InterfaceBuilder:new(self, name, function(parent)
        return parent.add(Gridorius.MergeProperties({ type = "table", name = name, column_count = column_count }, properties))
    end)
end

--#endregion

return Gui