local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
---@class Ignis.Button : Gtk.Button
---@field child Ignis.Widget
---@field label string
---@field icon_name string
---@field on_click function
---@field on_right_click function
---@field on_middle_click function
---@field on_hover function
---@field on_hover_lost function
---@field on_scroll_up function
---@field on_scroll_down function
Ignis:class("Button", Gtk.Button)

base_widget.apply_to_class(Ignis.Button)

local function init_click_controller(self, button_num, callback)
    local controller = Gtk.GestureClick()
    controller:set_button(button_num)
    self:add_controller(controller)

    controller.on_pressed = function(gesture, n_press, x, y)
        gesture:set_state(Gtk.EventSequenceState.CLAIMED)
        callback(self, n_press, x, y)
    end

    return controller
end

local function ensure_motion_controller(self)
    local env = base_widget.get_env(self)
    if not env.motion_controller then
        local controller = Gtk.EventControllerMotion()
        self:add_controller(controller)
        controller.on_enter = function(_, x, y)
            if env.on_hover then env.on_hover(self, x, y) end
        end
        controller.on_leave = function()
            if env.on_hover_lost then env.on_hover_lost(self) end
        end
        env.motion_controller = controller
    end
end

local function ensure_scroll_controller(self)
    local env = base_widget.get_env(self)
    if not env.scroll_controller then
        local controller = Gtk.EventControllerScroll.new(Gtk.EventControllerScrollFlags.BOTH_AXES)
        self:add_controller(controller)
        controller.on_scroll = function(_, dx, dy)
            if dy < 0 and env.on_scroll_up then
                env.on_scroll_up(self, dx, dy)
                return true
            elseif dy > 0 and env.on_scroll_down then
                env.on_scroll_down(self, dx, dy)
                return true
            end
            return false
        end
        env.scroll_controller = controller
    end
end

---@param props table
function Ignis.Button:init(props)
    props = props or {}

    self:init_base_widget(props)

    if props.label ~= nil then self.label = props.label end
    if props.icon_name ~= nil then self.icon_name = props.icon_name end
    if props.has_frame ~= nil then self.has_frame = props.has_frame end
    if props.child ~= nil then self.child = props.child end

    self.on_clicked = function()
        local env = base_widget.get_env(self)
        if env.on_click then
            env.on_click(self)
        end
    end

    if props.on_click then self:set_on_click(props.on_click) end
    if props.on_right_click then self:set_on_right_click(props.on_right_click) end
    if props.on_middle_click then self:set_on_middle_click(props.on_middle_click) end
    if props.on_hover then self:set_on_hover(props.on_hover) end
    if props.on_hover_lost then self:set_on_hover_lost(props.on_hover_lost) end
    if props.on_scroll_up then self:set_on_scroll_up(props.on_scroll_up) end
    if props.on_scroll_down then self:set_on_scroll_down(props.on_scroll_down) end
end

function Ignis.Button:get_on_click()
    return base_widget.get_env(self).on_click
end

function Ignis.Button:set_on_click(callback)
    base_widget.get_env(self).on_click = callback
end

function Ignis.Button:get_on_right_click()
    return base_widget.get_env(self).on_right_click
end

function Ignis.Button:set_on_right_click(callback)
    local env = base_widget.get_env(self)
    env.on_right_click = callback
    if callback and not env.right_click_controller then
        env.right_click_controller = init_click_controller(self, 3, function(_, n_press, x, y)
            if env.on_right_click then env.on_right_click(self, n_press, x, y) end
        end)
    end
end

function Ignis.Button:get_on_middle_click()
    return base_widget.get_env(self).on_middle_click
end

function Ignis.Button:set_on_middle_click(callback)
    local env = base_widget.get_env(self)
    env.on_middle_click = callback
    if callback and not env.middle_click_controller then
        env.middle_click_controller = init_click_controller(self, 2, function(_, n_press, x, y)
            if env.on_middle_click then env.on_middle_click(self, n_press, x, y) end
        end)
    end
end

function Ignis.Button:get_on_hover()
    return base_widget.get_env(self).on_hover
end

function Ignis.Button:set_on_hover(callback)
    base_widget.get_env(self).on_hover = callback
    if callback then ensure_motion_controller(self) end
end

function Ignis.Button:get_on_hover_lost()
    return base_widget.get_env(self).on_hover_lost
end

function Ignis.Button:set_on_hover_lost(callback)
    base_widget.get_env(self).on_hover_lost = callback
    if callback then ensure_motion_controller(self) end
end

function Ignis.Button:get_on_scroll_up()
    return base_widget.get_env(self).on_scroll_up
end

function Ignis.Button:set_on_scroll_up(callback)
    base_widget.get_env(self).on_scroll_up = callback
    if callback then ensure_scroll_controller(self) end
end

function Ignis.Button:get_on_scroll_down()
    return base_widget.get_env(self).on_scroll_down
end

function Ignis.Button:set_on_scroll_down(callback)
    base_widget.get_env(self).on_scroll_down = callback
    if callback then ensure_scroll_controller(self) end
end

return Ignis.Button
