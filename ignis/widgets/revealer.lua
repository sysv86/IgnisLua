local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("Revealer", Gtk.Revealer)

base_widget.apply_to_class(Ignis.Revealer)

function Ignis.Revealer:init(props)
    props = props or {}

    self:override_enum("transition_type", Gtk.RevealerTransitionType)
    self:init_base_widget(props)

    if props.transition_type ~= nil then
        self.transition_type = props.transition_type
    end
    if props.transition_duration ~= nil then
        self.transition_duration = props.transition_duration
    end
    if props.reveal_child ~= nil then
        self.reveal_child = props.reveal_child
    end
    if props.child ~= nil then
        self.child = props.child
    end
end

function Ignis.Revealer:toggle()
    self.reveal_child = not self.reveal_child
end

return Ignis.Revealer
