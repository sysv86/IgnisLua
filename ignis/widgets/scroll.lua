local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("Scroll", Gtk.ScrolledWindow)

base_widget.apply_to_class(Ignis.Scroll)

function Ignis.Scroll:init(props)
    props = props or {}

    self:override_enum("hscrollbar_policy", Gtk.PolicyType)
    self:override_enum("vscrollbar_policy", Gtk.PolicyType)

    self:init_base_widget(props)

    if props.hscrollbar_policy ~= nil then self.hscrollbar_policy = props.hscrollbar_policy end
    if props.vscrollbar_policy ~= nil then self.vscrollbar_policy = props.vscrollbar_policy end
    if props.propagate_natural_width ~= nil then self.propagate_natural_width = props.propagate_natural_width end
    if props.propagate_natural_height ~= nil then self.propagate_natural_height = props.propagate_natural_height end
    if props.min_content_width ~= nil then self.min_content_width = props.min_content_width end
    if props.min_content_height ~= nil then self.min_content_height = props.min_content_height end
    if props.max_content_width ~= nil then self.max_content_width = props.max_content_width end
    if props.max_content_height ~= nil then self.max_content_height = props.max_content_height end
    if props.kinetic_scrolling ~= nil then self.kinetic_scrolling = props.kinetic_scrolling end
    if props.overlay_scrolling ~= nil then self.overlay_scrolling = props.overlay_scrolling end
    if props.has_frame ~= nil then self.has_frame = props.has_frame end
    if props.child ~= nil then self.child = props.child end
end

return Ignis.Scroll
