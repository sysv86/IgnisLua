local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local Pango = lgi.require("Pango")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("ProgressBar", Gtk.ProgressBar)

base_widget.apply_to_class(Ignis.ProgressBar)

function Ignis.ProgressBar:init(props)
    props = props or {}

    self:override_enum("ellipsize", Pango.EllipsizeMode)
    self:init_base_widget(props)

    if props.vertical ~= nil then self.vertical = props.vertical end
    if props.inverted ~= nil then self.inverted = props.inverted end
    if props.show_text ~= nil then self.show_text = props.show_text end
    if props.text ~= nil then self.text = props.text end
    if props.pulse_step ~= nil then self.pulse_step = props.pulse_step end
    if props.ellipsize ~= nil then self.ellipsize = props.ellipsize end
    if props.fraction ~= nil then self.fraction = props.fraction end
    if props.value ~= nil then self.value = props.value end
end

function Ignis.ProgressBar:get_value()
    return self:get_fraction()
end

function Ignis.ProgressBar:set_value(val)
    if val == nil then return end
    if val > 1 and val <= 100 then
        val = val / 100.0
    end
    self:set_fraction(math.max(0.0, math.min(1.0, val)))
    self:notify("value")
end

function Ignis.ProgressBar:get_vertical()
    return self:get_orientation() == "VERTICAL"
end

function Ignis.ProgressBar:set_vertical(value)
    if value then
        self:set_orientation(Gtk.Orientation.VERTICAL)
    else
        self:set_orientation(Gtk.Orientation.HORIZONTAL)
    end
    self:notify("vertical")
end

return Ignis.ProgressBar
