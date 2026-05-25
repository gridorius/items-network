local InterfaceBuilder = {}
InterfaceBuilder.__index = InterfaceBuilder

function InterfaceBuilder:new(gui, name, render_function)
    local self = setmetatable({}, InterfaceBuilder)
    self.gui = gui
    self.name = name
    self.render_function = render_function or function(parent) return parent end
    self.children = {}
    self.classes = {}
    self.on_close_handler = nil
    self.after_create_handler = nil
    return self
end

-- #region Element operations

function InterfaceBuilder:CreateConnector()
    return {
        root = nil,
        on_close_handlers = {}
    }
end

function InterfaceBuilder:OnClose(handler)
    self.on_close_handler = handler
    return self
end

function InterfaceBuilder:AfterCreate(handler)
    self.after_create_handler = handler
    return self
end

function InterfaceBuilder:AfterCreateChilds(handler)
    self.after_create_childs_handler = handler
    return self
end

function InterfaceBuilder:OnClick(handler)
    if not self.name then return self end
    self.gui.click_name_handlers[self.name] = function(event)
        local player = game.get_player(event.player_index)
        local target = event.element
        handler(player, target, event)
    end
    return self
end

function InterfaceBuilder:RenderElement(player, parent, connector)
    local element = self.render_function(parent, player, connector)
    if self.after_create_handler then
        self.after_create_handler(element, player)
    end
    return element
end

function InterfaceBuilder:RenderRoot(player, parent)
    local connector = self:CreateConnector()
    local element = self:RenderElement(player, parent, connector)
    connector.root = element
    if self.on_close_handler then
        table.insert(connector.on_close_handlers, self.on_close_handler)
    end
    self:RenderElementData(
        element,
        self.classes, player, connector
    )
    return connector
end

function InterfaceBuilder:Render(player, parent, connector)
    local element = self:RenderElement(player, parent, connector)
    if self.on_close_handler then
        table.insert(connector.on_close_handlers, self.on_close_handler)
    end
    self:RenderElementData(
        element,
        self.classes, player, connector
    )
    return element
end

function InterfaceBuilder:RenderChildren(player, parent, connector)
    for _, child in pairs(self.children) do
        child:Render(player, parent, connector)
    end
end

function InterfaceBuilder:RenderElementData(element, classes, player, connector)
    self.gui:ApplyStyles(element, classes)
    self:RenderChildren(player, element, connector)
    if self.after_create_childs_handler then
        self.after_create_childs_handler(element, player)
    end
    return element
end

function InterfaceBuilder:SetClasses(...)
    self.classes = { ... }
    return self
end

--#endregion

--#region Element creation

function InterfaceBuilder:AppendChild(builder)
    table.insert(self.children, builder)
    return self
end

function InterfaceBuilder:AppendChildrens(...)
    local child = { ... }
    for i = 1, #child do
        self:AppendChild(child[i])
    end
    return self
end

return InterfaceBuilder
