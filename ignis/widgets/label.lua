local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local Pango = lgi.require("Pango")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
---@class Ignis.Label : Gtk.Label
---@field label string
---@field use_markup boolean
---@field justify string
---@field wrap boolean
---@field wrap_mode string
---@field ellipsize string
---@field max_width_chars number
---@field width_chars number
---@field xalign number
---@field yalign number
---@field selectable boolean
---@field single_line_mode boolean
---@field lines number
Ignis:class("Label", Gtk.Label)

base_widget.apply_to_class(Ignis.Label)

---@param props table
function Ignis.Label:init(props)
    props = props or {}

    self:override_enum("justify", Gtk.Justification)
    self:override_enum("wrap_mode", Pango.WrapMode)
    self:override_enum("ellipsize", Pango.EllipsizeMode)

    self:init_base_widget(props)

    if props.label ~= nil then self.label = props.label end
    if props.use_markup ~= nil then self.use_markup = props.use_markup end
    if props.justify ~= nil then self.justify = props.justify end
    if props.wrap ~= nil then self.wrap = props.wrap end
    if props.wrap_mode ~= nil then self.wrap_mode = props.wrap_mode end
    if props.ellipsize ~= nil then self.ellipsize = props.ellipsize end
    if props.max_width_chars ~= nil then self.max_width_chars = props.max_width_chars end
    if props.width_chars ~= nil then self.width_chars = props.width_chars end
    if props.xalign ~= nil then self.xalign = props.xalign end
    if props.yalign ~= nil then self.yalign = props.yalign end
    if props.selectable ~= nil then self.selectable = props.selectable end
    if props.single_line_mode ~= nil then self.single_line_mode = props.single_line_mode end
    if props.lines ~= nil then self.lines = props.lines end
end

return Ignis.Label
