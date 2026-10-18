local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("Scale", Gtk.Scale)

base_widget.apply_to_class(Ignis.Scale)

function Ignis.Scale:init(props)
    props = props or {}
    local env = base_widget.get_env(self)

    self:override_enum("value_pos", Gtk.PositionType)

    local adj = Gtk.Adjustment({
        value = 0,
        lower = 0,
        upper = 100,
        step_increment = 1,
        page_increment = 10,
        page_size = 0,
    })
    self.adjustment = adj
    env.on_change_val = nil
    env.suppress_change = false

    self:init_base_widget(props)

    self.on_value_changed = function(self_ptr)
        local e = base_widget.get_env(self_ptr)
        self_ptr:notify("value")
        if e.on_change_val and not e.suppress_change then
            e.on_change_val(self_ptr)
        end
    end

    if props.min ~= nil then self.min = props.min end
    if props.max ~= nil then self.max = props.max end
    if props.step ~= nil then self.step = props.step end
    if props.value ~= nil then self.value = props.value end
    if props.vertical ~= nil then self.vertical = props.vertical end
    if props.draw_value ~= nil then self.draw_value = props.draw_value end
    if props.value_pos ~= nil then self.value_pos = props.value_pos end
    if props.inverted ~= nil then self.inverted = props.inverted end
    if props.digits ~= nil then self.digits = props.digits end
    if props.round_digits ~= nil then self.round_digits = props.round_digits end
    if props.on_change ~= nil then self:set_on_change(props.on_change) end

    if props.marks then
        for _, mark in ipairs(props.marks) do
            local pos = mark.position or mark[2] or "BOTTOM"
            if type(pos) == "string" then pos = Gtk.PositionType[pos:upper()] or Gtk.PositionType.BOTTOM end
            self:add_mark(mark.value or mark[1], pos, mark.markup or mark.label or mark[3])
        end
    end
end

function Ignis.Scale:get_value()
    local adj = self.adjustment
    return adj and adj.value or 0
end

function Ignis.Scale:set_value(value)
    if value == nil then return end
    local env = base_widget.get_env(self)
    env.suppress_change = true
    Gtk.Range.set_value(self, value)
    env.suppress_change = false
end

function Ignis.Scale:get_min()
    return self.adjustment.lower
end

function Ignis.Scale:set_min(value)
    if value == nil then return end
    self.adjustment.lower = value
    self:notify("min")
end

function Ignis.Scale:get_max()
    return self.adjustment.upper
end

function Ignis.Scale:set_max(value)
    if value == nil then return end
    self.adjustment.upper = value
    self:notify("max")
end

function Ignis.Scale:get_step()
    return self.adjustment.step_increment
end

function Ignis.Scale:set_step(value)
    if value == nil then return end
    self.adjustment.step_increment = value
    self:notify("step")
end

function Ignis.Scale:get_vertical()
    return self:get_orientation() == "VERTICAL"
end

function Ignis.Scale:set_vertical(value)
    if value then
        self:set_orientation(Gtk.Orientation.VERTICAL)
    else
        self:set_orientation(Gtk.Orientation.HORIZONTAL)
    end
    self:notify("vertical")
end

function Ignis.Scale:get_on_change()
    return base_widget.get_env(self).on_change_val
end

function Ignis.Scale:set_on_change(value)
    base_widget.get_env(self).on_change_val = value
end

return Ignis.Scale
