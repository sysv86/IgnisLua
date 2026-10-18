local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("Switch", Gtk.Switch)

base_widget.apply_to_class(Ignis.Switch)

function Ignis.Switch:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.on_change_val = nil
    env.suppress_change = false

    self:init_base_widget(props)

    self:connect("notify::active", function(self_ptr)
        local e = base_widget.get_env(self_ptr)
        if e.on_change_val and not e.suppress_change then
            e.on_change_val(self_ptr, self_ptr.active)
        end
    end)

    if props.state ~= nil then self.state = props.state end
    if props.active ~= nil then self.active = props.active end
    if props.on_change ~= nil then self:set_on_change(props.on_change) end
end

function Ignis.Switch:get_on_change()
    return base_widget.get_env(self).on_change_val
end

function Ignis.Switch:set_on_change(value)
    base_widget.get_env(self).on_change_val = value
end

return Ignis.Switch
