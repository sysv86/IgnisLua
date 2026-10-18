local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("Separator", Gtk.Separator)

base_widget.apply_to_class(Ignis.Separator)

function Ignis.Separator:init(props)
    props = props or {}
    self:init_base_widget(props)

    if props.vertical ~= nil then
        self.vertical = props.vertical
    end
end

function Ignis.Separator:get_vertical()
    return self:get_orientation() == "VERTICAL"
end

function Ignis.Separator:set_vertical(value)
    if value then
        self:set_orientation(Gtk.Orientation.VERTICAL)
    else
        self:set_orientation(Gtk.Orientation.HORIZONTAL)
    end
    self:notify("vertical")
end

return Ignis.Separator
