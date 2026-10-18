local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
---@class Ignis.CenterBox : Gtk.CenterBox
---@field start_widget Ignis.Widget
---@field center_widget Ignis.Widget
---@field end_widget Ignis.Widget
---@field vertical boolean
---@field shrink_center_last boolean
Ignis:class("CenterBox", Gtk.CenterBox)

base_widget.apply_to_class(Ignis.CenterBox)

---@param props table
function Ignis.CenterBox:init(props)
    props = props or {}

    self:init_base_widget(props)

    if props.vertical ~= nil then
        self.vertical = props.vertical
    end
    if props.shrink_center_last ~= nil then
        self.shrink_center_last = props.shrink_center_last
    end
    if props.start_widget ~= nil then
        self.start_widget = props.start_widget
    end
    if props.center_widget ~= nil then
        self.center_widget = props.center_widget
    end
    if props.end_widget ~= nil then
        self.end_widget = props.end_widget
    end
end

---@return boolean
function Ignis.CenterBox:get_vertical()
    return self:get_orientation() == "VERTICAL"
end

---@param value boolean
function Ignis.CenterBox:set_vertical(value)
    if value then
        self:set_orientation(Gtk.Orientation.VERTICAL)
    else
        self:set_orientation(Gtk.Orientation.HORIZONTAL)
    end
    self:notify("vertical")
end

return Ignis.CenterBox
