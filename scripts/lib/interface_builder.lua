local InterfaceBuilder = {}
InterfaceBuilder.__index = InterfaceBuilder

function InterfaceBuilder:new(gui, name, render_function)
    local self = setmetatable({}, InterfaceBuilder)
    self.gui = gui
    self.name = name or "root"
    self.render_function = render_function or function(parent) return parent end
    self.children = {}
    self.classes = {}
    self.after_create_handler = nil
    return self
end

-- #region Element operations

function InterfaceBuilder:CreateHierarhy(element)
    return setmetatable({
        element = element,
        children = {},
        destroy_children = function(self)
            for _, child in pairs(self.children) do
                child.element.destroy()
            end
            self.children = {}
        end,
    }, {
        __index = function(self, key)
            return self.children[key]
        end
    })
end

function InterfaceBuilder:AfterCreate(handler)
    self.after_create_handler = handler
    return self
end

function InterfaceBuilder:OnClick(handler)
    self.gui.click_name_handlers[self.name] = function(event)
        local player = game.get_player(event.player_index)
        local target = event.element
        handler(player, target, event)
    end
    return self
end

function InterfaceBuilder:RenderRoot(player, parent)
    local element = self.render_function(parent)
    if self.after_create_handler then
        self.after_create_handler(element)
    end
    local hierarhy = self:CreateHierarhy(element)
    self:RenderElementData(
        element,
        self.classes, player, hierarhy
    )
    return hierarhy
end

function InterfaceBuilder:Render(player, parent, hierarhy)
    local element = self.render_function(parent)
    if self.after_create_handler then
        self.after_create_handler(element)
    end
    local element_hierarhy = self:CreateHierarhy(element)
    hierarhy.children[self.name] = element_hierarhy
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
    return element
end

function InterfaceBuilder:SetClasses(classes)
    self.classes = classes
    return self
end

--#endregion

--#region Element creation

function InterfaceBuilder:AppendChild(builder)
    self.children[builder.name] = builder
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