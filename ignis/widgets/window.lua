local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local Gdk = lgi.require("Gdk", "4.0")
local Gtk4LayerShell = lgi.require("Gtk4LayerShell", "1.0")
local cairo = lgi.cairo
local base_widget = require("ignis.base_widget")
local exceptions = require("ignis.exceptions")
local window_manager = require("ignis.window_manager").get_default()
local monitor_util = require("ignis.utils.monitor")

local Ignis = lgi.package("Ignis")
---@class Ignis.Window : Gtk.Window
---@field namespace string
---@field anchor string[]
---@field exclusivity string
---@field layer string
---@field kb_mode string
---@field popup boolean
---@field monitor number|string
---@field input_width number
---@field input_height number
---@field margin_bottom number
---@field margin_left number
---@field margin_right number
---@field margin_top number
---@field dynamic_input_region boolean
Ignis:class("Window", Gtk.Window)

base_widget.apply_to_class(Ignis.Window)

local LAYER = {
    background = Gtk4LayerShell.Layer.BACKGROUND,
    bottom = Gtk4LayerShell.Layer.BOTTOM,
    top = Gtk4LayerShell.Layer.TOP,
    overlay = Gtk4LayerShell.Layer.OVERLAY,
}

local KB_MODE = {
    ["none"] = Gtk4LayerShell.KeyboardMode.NONE,
    exclusive = Gtk4LayerShell.KeyboardMode.EXCLUSIVE,
    on_demand = Gtk4LayerShell.KeyboardMode.ON_DEMAND,
}

local ANCHOR = {
    bottom = Gtk4LayerShell.Edge.BOTTOM,
    left = Gtk4LayerShell.Edge.LEFT,
    right = Gtk4LayerShell.Edge.RIGHT,
    top = Gtk4LayerShell.Edge.TOP,
}

local EXCLUSIVITY = {
    ignore = -1,
    normal = 0,
    exclusive = 1,
}

--- Constructor for Ignis.Window
---@param props {namespace: string, anchor: string[], exclusivity: string, layer: string, kb_mode: string, popup: boolean, monitor: number|string, margin_bottom: number, margin_left: number, margin_right: number, margin_top: number, dynamic_input_region: boolean, child: Ignis.Widget, halign: string, valign: string, hexpand: boolean, vexpand: boolean, style: string, setup: function}
function Ignis.Window:init(props)
    props = props or {}
    
    if not Gtk4LayerShell.is_supported() then
        error(exceptions.LayerShellNotSupportedError())
    end
    
    local app = require("ignis.app").get_initialized()
    local env = base_widget.get_env(self)
    
    self.application = app
    Gtk4LayerShell.init_for_window(self)
    
    env.namespace = props.namespace or "ignis-window"
    env.anchor = nil
    env.exclusivity = "normal"
    env.layer = "top"
    env.kb_mode = "none"
    env.popup = props.popup or false
    env.monitor = nil
    env.input_width = 0
    env.input_height = 0
    env.margin_bottom = props.margin_bottom or 0
    env.margin_left = props.margin_left or 0
    env.margin_right = props.margin_right or 0
    env.margin_top = props.margin_top or 0
    env.dynamic_input_region = props.dynamic_input_region or false
    
    self:init_base_widget(props)
    
    Gtk4LayerShell.set_namespace(self, env.namespace)
    window_manager:add_window(env.namespace, self)
    
    self.default_width = 2
    self.default_height = 2
    
    self:set_anchor(props.anchor)
    self:set_exclusivity(props.exclusivity or "normal")
    self:set_layer(props.layer or "top")
    self:set_kb_mode(props.kb_mode or "none")
    
    if props.monitor ~= nil then
        self:set_monitor(props.monitor)
    end
    
    self:set_margin_bottom(env.margin_bottom)
    self:set_margin_left(env.margin_left)
    self:set_margin_right(env.margin_right)
    self:set_margin_top(env.margin_top)
    
    local key_controller = Gtk.EventControllerKey()
    self:add_controller(key_controller)
    key_controller.on_key_pressed = function(controller, keyval, keycode, state)
        if env.popup and keyval == 65307 then -- 65307 is Escape key
            self.visible = false
            return true
        end
        return false
    end
    
    self.on_close_request = function()
        if not self.hide_on_close then
            self:__remove()
        end
    end
    
    if props.child then
        self:set_child(props.child)
    end

    if env.dynamic_input_region then
        self:__set_dynamic_input_region()
    end
end

--- Internal method to setup dynamic input region
function Ignis.Window:__set_dynamic_input_region()
    local child = self:get_child()
    if not child then
        error("Trying to set dynamic_input_region to true but the child is nil")
    end
    
    local function sync()
        self:set_input_width(child.width or child:get_width())
        self:set_input_height(child.height or child:get_height())
    end
    
    self.on_size_allocate = function(self_ptr, width, height, baseline)
        self:emit("size-changed")
        sync()
    end
    
    sync()
end

--- Internal method to change input region
function Ignis.Window:__change_input_region()
    local env = base_widget.get_env(self)
    if env.input_width < 0 or env.input_height < 0 then
        error("The input_width and input_height properties must be greater than 0")
    end
    
    local surface = self:get_surface()
    if not surface then
        self.on_realize = function()
            self:__change_input_region()
        end
        return
    end
    
    local rect = cairo.RectangleInt {
        x = 0,
        y = 0,
        width = env.input_width,
        height = env.input_height
    }
    local region = cairo.Region.create(rect)
    surface:set_input_region(region)
end

--- Internal method to remove window from manager
function Ignis.Window:__remove()
    local env = base_widget.get_env(self)
    pcall(function()
        window_manager:remove_window(env.namespace)
    end)
end

---@override
function Ignis.Window:destroy()
    self:__remove()
    Gtk.Window.destroy(self)
end

---@override
function Ignis.Window:unrealize()
    self:__remove()
    Gtk.Window.unrealize(self)
end

---@return string
function Ignis.Window:get_namespace()
    return base_widget.get_env(self).namespace
end

---@return string[]
function Ignis.Window:get_anchor()
    return base_widget.get_env(self).anchor
end

---@param value string[]
function Ignis.Window:set_anchor(value)
    local env = base_widget.get_env(self)
    env.anchor = value
    if value == nil then
        for _, edge in pairs(ANCHOR) do
            Gtk4LayerShell.set_anchor(self, edge, false)
        end
    else
        for _, item in ipairs(value) do
            local edge = ANCHOR[item]
            if edge then
                Gtk4LayerShell.set_anchor(self, edge, true)
            end
        end
    end
end

---@return string
function Ignis.Window:get_exclusivity()
    return base_widget.get_env(self).exclusivity
end

---@param value string
function Ignis.Window:set_exclusivity(value)
    local env = base_widget.get_env(self)
    env.exclusivity = value
    if value == "exclusive" then
        Gtk4LayerShell.auto_exclusive_zone_enable(self)
    else
        local val = EXCLUSIVITY[value] or 0
        Gtk4LayerShell.set_exclusive_zone(self, val)
    end
end

---@return string
function Ignis.Window:get_layer()
    return base_widget.get_env(self).layer
end

---@param value string
function Ignis.Window:set_layer(value)
    local env = base_widget.get_env(self)
    env.layer = value
    local layer_val = LAYER[value] or Gtk4LayerShell.Layer.TOP
    Gtk4LayerShell.set_layer(self, layer_val)
end

---@return string
function Ignis.Window:get_kb_mode()
    return base_widget.get_env(self).kb_mode
end

---@param value string
function Ignis.Window:set_kb_mode(value)
    local env = base_widget.get_env(self)
    env.kb_mode = value
    local kb_val = KB_MODE[value] or Gtk4LayerShell.KeyboardMode.NONE
    Gtk4LayerShell.set_keyboard_mode(self, kb_val)
end

---@return boolean
function Ignis.Window:get_popup()
    return base_widget.get_env(self).popup
end

---@param value boolean
function Ignis.Window:set_popup(value)
    base_widget.get_env(self).popup = value
end

---@return number|string
function Ignis.Window:get_monitor()
    return base_widget.get_env(self).monitor
end

---@param value number|string
function Ignis.Window:set_monitor(value)
    if value == nil then return end
    
    local gdkmonitor = monitor_util.get_monitor(value)
    if not gdkmonitor then
        error(exceptions.MonitorNotFoundError(tostring(value)))
    end
    
    Gtk4LayerShell.set_monitor(self, gdkmonitor)
    base_widget.get_env(self).monitor = value
end

---@return number
function Ignis.Window:get_input_width()
    return base_widget.get_env(self).input_width
end

---@param value number
function Ignis.Window:set_input_width(value)
    base_widget.get_env(self).input_width = value
    self:__change_input_region()
end

---@return number
function Ignis.Window:get_input_height()
    return base_widget.get_env(self).input_height
end

---@param value number
function Ignis.Window:set_input_height(value)
    base_widget.get_env(self).input_height = value
    self:__change_input_region()
end

---@return boolean
function Ignis.Window:get_dynamic_input_region()
    return base_widget.get_env(self).dynamic_input_region
end

---@return number
function Ignis.Window:get_margin_bottom() return base_widget.get_env(self).margin_bottom end
---@param value number
function Ignis.Window:set_margin_bottom(value)
    base_widget.get_env(self).margin_bottom = value
    Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, value)
end

---@return number
function Ignis.Window:get_margin_left() return base_widget.get_env(self).margin_left end
---@param value number
function Ignis.Window:set_margin_left(value)
    base_widget.get_env(self).margin_left = value
    Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, value)
end

---@return number
function Ignis.Window:get_margin_right() return base_widget.get_env(self).margin_right end
---@param value number
function Ignis.Window:set_margin_right(value)
    base_widget.get_env(self).margin_right = value
    Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, value)
end

---@return number
function Ignis.Window:get_margin_top() return base_widget.get_env(self).margin_top end
---@param value number
function Ignis.Window:set_margin_top(value)
    base_widget.get_env(self).margin_top = value
    Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, value)
end

return Ignis.Window
