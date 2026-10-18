local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("HeaderBar", Gtk.HeaderBar)

base_widget.apply_to_class(Ignis.HeaderBar)

function Ignis.HeaderBar:init(props)
    props = props or {}
    self:init_base_widget(props)

    if props.title_widget ~= nil then self.title_widget = props.title_widget end
    if props.show_title_buttons ~= nil then self.show_title_buttons = props.show_title_buttons end
    if props.decoration_layout ~= nil then self.decoration_layout = props.decoration_layout end

    for _, w in ipairs(props.start_widgets or {}) do
        self:pack_start(w)
    end
    for _, w in ipairs(props.end_widgets or {}) do
        self:pack_end(w)
    end
end

return Ignis.HeaderBar
