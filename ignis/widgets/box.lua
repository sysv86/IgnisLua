local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
---@class Ignis.Box : Gtk.Box
---@field child Ignis.Widget[]
---@field vertical boolean
---@field spacing number
---@field homogeneous boolean
Ignis:class("Box", Gtk.Box)

base_widget.apply_to_class(Ignis.Box)

---@param props table
function Ignis.Box:init(props)
    props = props or {}
    base_widget.get_env(self).child_widgets = {}

    self:init_base_widget(props)

    if props.vertical ~= nil then
        self.vertical = props.vertical
    end
    if props.spacing ~= nil then
        self.spacing = props.spacing
    end
    if props.homogeneous ~= nil then
        self.homogeneous = props.homogeneous
    end
    if props.child ~= nil then
        self.child = props.child
    end
end

---@return Ignis.Widget[]
function Ignis.Box:get_child()
    return base_widget.get_env(self).child_widgets or {}
end

---@param child_list Ignis.Widget[]
function Ignis.Box:set_child(child_list)
    if not child_list then return end

    local env = base_widget.get_env(self)
    local current_children = env.child_widgets or {}
    for _, child in ipairs(current_children) do
        Gtk.Box.remove(self, child)
    end
    env.child_widgets = {}

    for _, child in ipairs(child_list) do
        if child then
            self:append(child)
        end
    end
end

---@param child_widget Ignis.Widget
function Ignis.Box:append(child_widget)
    if not child_widget then return end

    local env = base_widget.get_env(self)
    if not env.child_widgets then env.child_widgets = {} end
    table.insert(env.child_widgets, child_widget)

    Gtk.Box.append(self, child_widget)
    self:notify("child")
end

---@param child_widget Ignis.Widget
function Ignis.Box:remove(child_widget)
    if not child_widget then return end

    local env = base_widget.get_env(self)
    local children = env.child_widgets or {}
    for i, child in ipairs(children) do
        if child == child_widget then
            table.remove(children, i)
            break
        end
    end

    Gtk.Box.remove(self, child_widget)
    self:notify("child")
end

---@param child_widget Ignis.Widget
function Ignis.Box:prepend(child_widget)
    if not child_widget then return end

    local env = base_widget.get_env(self)
    if not env.child_widgets then env.child_widgets = {} end
    table.insert(env.child_widgets, 1, child_widget)

    Gtk.Box.prepend(self, child_widget)
    self:notify("child")
end

--- Clear all child widgets from the Box
function Ignis.Box:clear()
    self:set_child({})
end

--- Alias for clear()
function Ignis.Box:clear_children()
    self:set_child({})
end

---@return boolean
function Ignis.Box:get_vertical()
    return self:get_orientation() == "VERTICAL"
end

---@param value boolean
function Ignis.Box:set_vertical(value)
    if value then
        self:set_orientation(Gtk.Orientation.VERTICAL)
    else
        self:set_orientation(Gtk.Orientation.HORIZONTAL)
    end
    self:notify("vertical")
end

return Ignis.Box
