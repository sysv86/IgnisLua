local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
---@class Ignis.Entry : Gtk.Entry
---@field text string
---@field placeholder_text string
---@field visibility boolean
---@field max_length number
---@field editable boolean
---@field has_frame boolean
---@field on_accept function
---@field on_change function
Ignis:class("Entry", Gtk.Entry)

base_widget.apply_to_class(Ignis.Entry)

---@param props table
function Ignis.Entry:init(props)
    props = props or {}
    local env = base_widget.get_env(self)

    env.on_accept_val = nil
    env.on_change_val = nil

    if Gtk.InputPurpose then
        self:override_enum("input_purpose", Gtk.InputPurpose)
    end

    self:init_base_widget(props)

    self:connect("activate", function(self_ptr)
        local on_accept = base_widget.get_env(self_ptr).on_accept_val
        if on_accept then
            on_accept(self_ptr)
        end
    end)

    self:connect("notify::text", function(self_ptr)
        local on_change = base_widget.get_env(self_ptr).on_change_val
        if on_change then
            on_change(self_ptr)
        end
    end)

    if props.text ~= nil then self.text = props.text end
    if props.placeholder_text ~= nil then self.placeholder_text = props.placeholder_text end
    if props.visibility ~= nil then self.visibility = props.visibility end
    if props.invisible_char ~= nil then self.invisible_char = props.invisible_char end
    if props.max_length ~= nil then self.max_length = props.max_length end
    if props.editable ~= nil then self.editable = props.editable end
    if props.has_frame ~= nil then self.has_frame = props.has_frame end
    if props.input_purpose ~= nil then self.input_purpose = props.input_purpose end
    if props.primary_icon_name ~= nil then self.primary_icon_name = props.primary_icon_name end
    if props.secondary_icon_name ~= nil then self.secondary_icon_name = props.secondary_icon_name end
    if props.on_accept ~= nil then self:set_on_accept(props.on_accept) end
    if props.on_change ~= nil then self:set_on_change(props.on_change) end
end

function Ignis.Entry:get_on_accept()
    return base_widget.get_env(self).on_accept_val
end

function Ignis.Entry:set_on_accept(value)
    base_widget.get_env(self).on_accept_val = value
end

function Ignis.Entry:get_on_change()
    return base_widget.get_env(self).on_change_val
end

function Ignis.Entry:set_on_change(value)
    base_widget.get_env(self).on_change_val = value
end

function Ignis.Entry:get_text()
    return Gtk.Entry.get_text(self)
end

function Ignis.Entry:set_text(value)
    Gtk.Entry.set_text(self, value or "")
end

return Ignis.Entry
