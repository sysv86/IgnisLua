local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")
local Box = require("ignis.widgets.box")

local Ignis = lgi.package("Ignis")
Ignis:class("EventBox", Box)

base_widget.apply_to_class(Ignis.EventBox)

local function add_click_gesture(self, button_num, handler_key)
    local env = base_widget.get_env(self)
    local ctrl_key = "_click_ctrl_" .. tostring(button_num)
    if not env[ctrl_key] then
        local controller = Gtk.GestureClick()
        controller:set_button(button_num)
        self:add_controller(controller)
        controller.on_pressed = function(gesture, n_press, x, y)
            if env[handler_key] then
                gesture:set_state(Gtk.EventSequenceState.CLAIMED)
                env[handler_key](self, n_press, x, y)
            end
        end
        env[ctrl_key] = controller
    end
end

local function ensure_motion(self)
    local env = base_widget.get_env(self)
    if not env._motion_ctrl then
        local controller = Gtk.EventControllerMotion()
        self:add_controller(controller)
        controller.on_enter = function(_, x, y)
            if env.on_hover then env.on_hover(self, x, y) end
        end
        controller.on_leave = function()
            if env.on_hover_lost then env.on_hover_lost(self) end
        end
        controller.on_motion = function(_, x, y)
            if env.on_motion then env.on_motion(self, x, y) end
        end
        env._motion_ctrl = controller
    end
end

local function ensure_scroll(self)
    local env = base_widget.get_env(self)
    if not env._scroll_ctrl then
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
        env._scroll_ctrl = controller
    end
end

local function ensure_key(self)
    local env = base_widget.get_env(self)
    if not env._key_ctrl then
        local controller = Gtk.EventControllerKey()
        self:add_controller(controller)
        controller.on_key_pressed = function(_, keyval, keycode, state)
            if env.on_key_pressed then
                return env.on_key_pressed(self, keyval, keycode, state) or false
            end
            return false
        end
        controller.on_key_released = function(_, keyval, keycode, state)
            if env.on_key_released then
                env.on_key_released(self, keyval, keycode, state)
            end
        end
        env._key_ctrl = controller
    end
end

function Ignis.EventBox:init(props)
    props = props or {}
    Box.init(self, props)

    if props.on_click then self:set_on_click(props.on_click) end
    if props.on_right_click then self:set_on_right_click(props.on_right_click) end
    if props.on_middle_click then self:set_on_middle_click(props.on_middle_click) end
    if props.on_hover then self:set_on_hover(props.on_hover) end
    if props.on_hover_lost then self:set_on_hover_lost(props.on_hover_lost) end
    if props.on_motion then self:set_on_motion(props.on_motion) end
    if props.on_scroll_up then self:set_on_scroll_up(props.on_scroll_up) end
    if props.on_scroll_down then self:set_on_scroll_down(props.on_scroll_down) end
    if props.on_key_pressed then self:set_on_key_pressed(props.on_key_pressed) end
    if props.on_key_released then self:set_on_key_released(props.on_key_released) end
end

function Ignis.EventBox:get_on_click() return base_widget.get_env(self).on_click end
function Ignis.EventBox:set_on_click(cb)
    base_widget.get_env(self).on_click = cb
    if cb then add_click_gesture(self, 1, "on_click") end
end

function Ignis.EventBox:get_on_middle_click() return base_widget.get_env(self).on_middle_click end
function Ignis.EventBox:set_on_middle_click(cb)
    base_widget.get_env(self).on_middle_click = cb
    if cb then add_click_gesture(self, 2, "on_middle_click") end
end

function Ignis.EventBox:get_on_right_click() return base_widget.get_env(self).on_right_click end
function Ignis.EventBox:set_on_right_click(cb)
    base_widget.get_env(self).on_right_click = cb
    if cb then add_click_gesture(self, 3, "on_right_click") end
end

function Ignis.EventBox:get_on_hover() return base_widget.get_env(self).on_hover end
function Ignis.EventBox:set_on_hover(cb)
    base_widget.get_env(self).on_hover = cb
    if cb then ensure_motion(self) end
end

function Ignis.EventBox:get_on_hover_lost() return base_widget.get_env(self).on_hover_lost end
function Ignis.EventBox:set_on_hover_lost(cb)
    base_widget.get_env(self).on_hover_lost = cb
    if cb then ensure_motion(self) end
end

function Ignis.EventBox:get_on_motion() return base_widget.get_env(self).on_motion end
function Ignis.EventBox:set_on_motion(cb)
    base_widget.get_env(self).on_motion = cb
    if cb then ensure_motion(self) end
end

function Ignis.EventBox:get_on_scroll_up() return base_widget.get_env(self).on_scroll_up end
function Ignis.EventBox:set_on_scroll_up(cb)
    base_widget.get_env(self).on_scroll_up = cb
    if cb then ensure_scroll(self) end
end

function Ignis.EventBox:get_on_scroll_down() return base_widget.get_env(self).on_scroll_down end
function Ignis.EventBox:set_on_scroll_down(cb)
    base_widget.get_env(self).on_scroll_down = cb
    if cb then ensure_scroll(self) end
end

function Ignis.EventBox:get_on_key_pressed() return base_widget.get_env(self).on_key_pressed end
function Ignis.EventBox:set_on_key_pressed(cb)
    base_widget.get_env(self).on_key_pressed = cb
    if cb then
        self.focusable = true
        ensure_key(self)
    end
end

function Ignis.EventBox:get_on_key_released() return base_widget.get_env(self).on_key_released end
function Ignis.EventBox:set_on_key_released(cb)
    base_widget.get_env(self).on_key_released = cb
    if cb then
        self.focusable = true
        ensure_key(self)
    end
end

return Ignis.EventBox
