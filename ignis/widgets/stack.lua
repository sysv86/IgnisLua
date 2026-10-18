local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")

Ignis:class("Stack", Gtk.Stack)
base_widget.apply_to_class(Ignis.Stack)

function Ignis.Stack:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.pages = {}

    self:override_enum("transition_type", Gtk.StackTransitionType)
    self:init_base_widget(props)

    if props.transition_type ~= nil then self.transition_type = props.transition_type end
    if props.transition_duration ~= nil then self.transition_duration = props.transition_duration end
    if props.hhomogeneous ~= nil then self.hhomogeneous = props.hhomogeneous end
    if props.vhomogeneous ~= nil then self.vhomogeneous = props.vhomogeneous end
    if props.interpolate_size ~= nil then self.interpolate_size = props.interpolate_size end

    local pages = props.pages or props.child
    if pages then
        self:set_pages(pages)
    end

    if props.visible_child_name ~= nil then
        self.visible_child_name = props.visible_child_name
    end
end

function Ignis.Stack:get_pages()
    return base_widget.get_env(self).pages or {}
end

function Ignis.Stack:set_pages(pages)
    if not pages then return end
    local env = base_widget.get_env(self)
    for _, p in ipairs(env.pages or {}) do
        if p.widget then
            Gtk.Stack.remove(self, p.widget)
        end
    end
    env.pages = {}

    for i, item in ipairs(pages) do
        if type(item) == "table" and not item._type then
            local w = item.child or item.widget or item[1]
            local name = item.name or item[2] or ("page_" .. tostring(i))
            local title = item.title or item[3]
            if w then
                if title then
                    self:add_titled(w, name, title)
                else
                    self:add_named(w, name)
                end
                table.insert(env.pages, { widget = w, name = name, title = title })
            end
        else
            local name = "page_" .. tostring(i)
            self:add_named(item, name)
            table.insert(env.pages, { widget = item, name = name })
        end
    end
    self:notify("pages")
end

Ignis.Stack.get_child = Ignis.Stack.get_pages
Ignis.Stack.set_child = Ignis.Stack.set_pages

Ignis:class("StackSwitcher", Gtk.StackSwitcher)
base_widget.apply_to_class(Ignis.StackSwitcher)

function Ignis.StackSwitcher:init(props)
    props = props or {}
    self:init_base_widget(props)
    if props.stack ~= nil then
        self.stack = props.stack
    end
end

return {
    Stack = Ignis.Stack,
    StackSwitcher = Ignis.StackSwitcher
}
