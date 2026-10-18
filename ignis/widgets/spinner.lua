local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("Spinner", Gtk.Spinner)

base_widget.apply_to_class(Ignis.Spinner)

function Ignis.Spinner:init(props)
    props = props or {}
    self:init_base_widget(props)

    if props.spinning ~= nil then
        self.spinning = props.spinning
    else
        self.spinning = true
    end
end

return Ignis.Spinner
