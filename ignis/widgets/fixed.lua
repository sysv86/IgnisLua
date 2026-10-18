local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("Fixed", Gtk.Fixed)

base_widget.apply_to_class(Ignis.Fixed)

function Ignis.Fixed:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.child_items = {}

    self:init_base_widget(props)

    if props.child ~= nil then
        self.child = props.child
    end
end

function Ignis.Fixed:get_child()
    return base_widget.get_env(self).child_items or {}
end

function Ignis.Fixed:set_child(child_list)
    if not child_list then return end
    local env = base_widget.get_env(self)
    for _, item in ipairs(env.child_items or {}) do
        local w = item.widget or item[1] or item
        if w then
            Gtk.Fixed.remove(self, w)
        end
    end
    env.child_items = {}

    for _, item in ipairs(child_list) do
        table.insert(env.child_items, item)
        if type(item) == "table" and not item._type then
            local w = item.widget or item[1]
            local x = item.x or item[2] or 0
            local y = item.y or item[3] or 0
            if w then
                Gtk.Fixed.put(self, w, x, y)
            end
        else
            Gtk.Fixed.put(self, item, 0, 0)
        end
    end
    self:notify("child")
end

return Ignis.Fixed
