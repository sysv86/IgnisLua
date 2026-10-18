local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("FlowBox", Gtk.FlowBox)

base_widget.apply_to_class(Ignis.FlowBox)

function Ignis.FlowBox:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.child_widgets = {}
    env.on_child_activated_val = nil

    self:override_enum("selection_mode", Gtk.SelectionMode)
    self:init_base_widget(props)

    self.on_child_activated = function(self_ptr, flowbox_child)
        local cb = base_widget.get_env(self_ptr).on_child_activated_val
        if cb then
            cb(self_ptr, flowbox_child)
        end
    end

    if props.min_children_per_line ~= nil then self.min_children_per_line = props.min_children_per_line end
    if props.max_children_per_line ~= nil then self.max_children_per_line = props.max_children_per_line end
    if props.row_spacing ~= nil then self.row_spacing = props.row_spacing end
    if props.column_spacing ~= nil then self.column_spacing = props.column_spacing end
    if props.homogeneous ~= nil then self.homogeneous = props.homogeneous end
    if props.selection_mode ~= nil then self.selection_mode = props.selection_mode end
    if props.activate_on_single_click ~= nil then self.activate_on_single_click = props.activate_on_single_click end
    if props.on_child_activated ~= nil then self:set_on_child_activated(props.on_child_activated) end
    if props.child ~= nil then self.child = props.child end
end

function Ignis.FlowBox:get_child()
    return base_widget.get_env(self).child_widgets or {}
end

function Ignis.FlowBox:set_child(child_list)
    if not child_list then return end
    local env = base_widget.get_env(self)
    for _, child in ipairs(env.child_widgets or {}) do
        Gtk.FlowBox.remove(self, child)
    end
    env.child_widgets = {}

    for _, child in ipairs(child_list) do
        if child then
            table.insert(env.child_widgets, child)
            Gtk.FlowBox.append(self, child)
        end
    end
    self:notify("child")
end

function Ignis.FlowBox:get_on_child_activated()
    return base_widget.get_env(self).on_child_activated_val
end

function Ignis.FlowBox:set_on_child_activated(cb)
    base_widget.get_env(self).on_child_activated_val = cb
end

return Ignis.FlowBox
