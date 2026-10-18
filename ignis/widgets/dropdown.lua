local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("DropDown", Gtk.DropDown)

base_widget.apply_to_class(Ignis.DropDown)

function Ignis.DropDown:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.items_list = {}
    env.on_selected_val = nil

    self:init_base_widget(props)

    self:connect("notify::selected", function(self_ptr)
        local cb = base_widget.get_env(self_ptr).on_selected_val
        if cb then
            cb(self_ptr, self_ptr:get_selected_value())
        end
    end)

    if props.items ~= nil then self:set_items(props.items) end
    if props.enable_search ~= nil then self.enable_search = props.enable_search end
    if props.show_arrow ~= nil then self.show_arrow = props.show_arrow end
    if props.selected ~= nil then self:set_selected_item_by_value(props.selected) end
    if props.on_selected ~= nil then self:set_on_selected(props.on_selected) end
end

function Ignis.DropDown:get_items()
    return base_widget.get_env(self).items_list or {}
end

function Ignis.DropDown:set_items(items)
    if not items then return end
    local env = base_widget.get_env(self)
    env.items_list = items
    local model = Gtk.StringList.new(items)
    self:set_model(model)
    self:notify("items")
end

function Ignis.DropDown:get_selected_value()
    local idx = Gtk.DropDown.get_selected(self)
    local items = self:get_items()
    return items and items[idx + 1] or nil
end

function Ignis.DropDown:set_selected_item_by_value(val)
    if type(val) == "number" then
        Gtk.DropDown.set_selected(self, val)
        return
    end
    local items = self:get_items()
    for i, item in ipairs(items) do
        if item == val then
            Gtk.DropDown.set_selected(self, i - 1)
            return
        end
    end
end

function Ignis.DropDown:get_on_selected()
    return base_widget.get_env(self).on_selected_val
end

function Ignis.DropDown:set_on_selected(cb)
    base_widget.get_env(self).on_selected_val = cb
end

return Ignis.DropDown
