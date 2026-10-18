local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("Overlay", Gtk.Overlay)

base_widget.apply_to_class(Ignis.Overlay)

function Ignis.Overlay:init(props)
    props = props or {}
    base_widget.get_env(self).overlay_widgets = {}

    self:init_base_widget(props)

    if props.child ~= nil then
        self.child = props.child
    end
    if props.overlays ~= nil then
        self.overlays = props.overlays
    end
end

function Ignis.Overlay:get_overlays()
    return base_widget.get_env(self).overlay_widgets or {}
end

function Ignis.Overlay:set_overlays(overlay_list)
    if not overlay_list then return end
    local env = base_widget.get_env(self)
    for _, ov in ipairs(env.overlay_widgets or {}) do
        Gtk.Overlay.remove_overlay(self, ov)
    end
    env.overlay_widgets = {}

    for _, ov in ipairs(overlay_list) do
        if ov then
            self:add_overlay(ov)
        end
    end
end

function Ignis.Overlay:add_overlay(widget)
    if not widget then return end
    local env = base_widget.get_env(self)
    if not env.overlay_widgets then env.overlay_widgets = {} end
    table.insert(env.overlay_widgets, widget)
    Gtk.Overlay.add_overlay(self, widget)
    self:notify("overlays")
end

function Ignis.Overlay:remove_overlay(widget)
    if not widget then return end
    local env = base_widget.get_env(self)
    local list = env.overlay_widgets or {}
    for i, ov in ipairs(list) do
        if ov == widget then
            table.remove(list, i)
            break
        end
    end
    Gtk.Overlay.remove_overlay(self, widget)
    self:notify("overlays")
end

return Ignis.Overlay
