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

function InterfaceBuilder:CreateHierarhy(element, root)
    local hierarhy = setmetatable({
        element = element,
        children = {},
    }, {
        __index = function(self, key)
            return self.children[key]
        end
    })
    if not root then
        root = hierarhy
        hierarhy.on_close_handlers = {}
    end
    hierarhy.root = root
    return hierarhy
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

function InterfaceBuilder:RenderElement(player, parent)
    local element = self.render_function(parent, player)
    if self.after_create_handler then
        self.after_create_handler(element, player)
    end
    return element
end

function InterfaceBuilder:RenderRoot(player, parent)
    local element = self:RenderElement(player, parent)
    local hierarhy = self:CreateHierarhy(element)
    if self.on_close_handler then
        table.insert(hierarhy.root.on_close_handlers, self.on_close_handler)
    end
    self:RenderElementData(
        element,
        self.classes, player, hierarhy
    )
    return hierarhy
end

function InterfaceBuilder:Render(player, parent, hierarhy)
    local element = self:RenderElement(player, parent)
    if self.on_close_handler then
        table.insert(hierarhy.root.on_close_handlers, self.on_close_handler)
    end
    local element_hierarhy = self:CreateHierarhy(element, hierarhy)
    if self.name then
        hierarhy.children[self.name] = element_hierarhy
    end
    self:RenderElementData(
        element,
        self.classes, player, element_hierarhy
    )
    return element
end

function InterfaceBuilder:RenderChildren(player, parent, hierarhy)
    for _, child in pairs(self.children) do
        child:Render(player, parent, hierarhy)
    end
end

function InterfaceBuilder:RenderElementData(element, classes, player, hierarhy)
    self.gui:ApplyStyles(element, classes)
    self:RenderChildren(player, element, hierarhy)
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
