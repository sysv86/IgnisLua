local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("CheckButton", Gtk.CheckButton)

base_widget.apply_to_class(Ignis.CheckButton)

function Ignis.CheckButton:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.on_toggled_val = nil

    self:init_base_widget(props)

    self.on_toggled = function(self_ptr)
        local cb = base_widget.get_env(self_ptr).on_toggled_val
        if cb then
            cb(self_ptr, self_ptr.active)
        end
    end

    if props.label ~= nil then self.label = props.label end
    if props.child ~= nil then self.child = props.child end
    if props.group ~= nil then self:set_group(props.group) end
    if props.inconsistent ~= nil then self.inconsistent = props.inconsistent end
    if props.active ~= nil then self.active = props.active end
    if props.on_toggled ~= nil then self:set_on_toggled(props.on_toggled) end
end

function Ignis.CheckButton:get_on_toggled()
    return base_widget.get_env(self).on_toggled_val
end

function Ignis.CheckButton:set_on_toggled(cb)
    base_widget.get_env(self).on_toggled_val = cb
end

return Ignis.CheckButton
