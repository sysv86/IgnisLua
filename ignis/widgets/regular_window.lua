local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")
local WindowManager = require("ignis.window_manager")

local Ignis = lgi.package("Ignis")
---@class Ignis.RegularWindow : Gtk.Window
---@field namespace string
---@field title string
---@field child Ignis.Widget
---@field titlebar Ignis.Widget
---@field default_width number
---@field default_height number
---@field resizable boolean
---@field modal boolean
---@field decorated boolean
---@field hide_on_close boolean
Ignis:class("RegularWindow", Gtk.Window)

base_widget.apply_to_class(Ignis.RegularWindow)

---@param props table
function Ignis.RegularWindow:init(props)
    props = props or {}
    local env = base_widget.get_env(self)

    local ns = props.namespace
    if not ns then
        error("RegularWindow requires a unique 'namespace' property")
    end
    env.namespace = ns

    local ok_app, app = pcall(function() return require("ignis.app").get_initialized() end)
    if ok_app and app then
        self.application = app
    end

    self:init_base_widget(props)

    if props.title ~= nil then self.title = props.title end
    if props.default_width ~= nil then self.default_width = props.default_width end
    if props.default_height ~= nil then self.default_height = props.default_height end
    if props.resizable ~= nil then self.resizable = props.resizable end
    if props.modal ~= nil then self.modal = props.modal end
    if props.decorated ~= nil then self.decorated = props.decorated end
    if props.hide_on_close ~= nil then self.hide_on_close = props.hide_on_close end
    if props.titlebar ~= nil then self.titlebar = props.titlebar end
    if props.child ~= nil then self.child = props.child end

    local win_mgr = WindowManager.get_default()
    win_mgr:add_window(ns, self)

    self:connect("close-request", function(self_ptr)
        if self_ptr.hide_on_close then
            self_ptr:set_visible(false)
            return true
        else
            self_ptr:remove_from_manager()
        end
        return false
    end)
end

function Ignis.RegularWindow:get_visible()
    return Gtk.Widget.get_visible(self)
end

function Ignis.RegularWindow:set_visible(value)
    value = value and true or false
    Gtk.Window.set_visible(self, value)
    if value then
        pcall(function() Gtk.Window.present(self) end)
    end
    self:notify("visible")
end

---@return string
function Ignis.RegularWindow:get_namespace()
    return base_widget.get_env(self).namespace
end

function Ignis.RegularWindow:remove_from_manager()
    local win_mgr = WindowManager.get_default()
    pcall(function()
        win_mgr:remove_window(self:get_namespace())
    end)
end

function Ignis.RegularWindow:destroy()
    self:remove_from_manager()
    Gtk.Window.destroy(self)
end

function Ignis.RegularWindow:unrealize()
    self:remove_from_manager()
    Gtk.Window.unrealize(self)
end

return Ignis.RegularWindow
