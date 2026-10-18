local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local GLib = lgi.GLib
local base_widget = require("ignis.base_widget")
local Window = require("ignis.widgets.window")
local Spring = require("ignis.utils.spring")

local Ignis = lgi.package("Ignis")
Ignis:class("RevealerWindow", Window)

base_widget.apply_to_class(Ignis.RevealerWindow)

---@class RevealerWindow : Window
---@field revealer Gtk.Revealer

local function cancel_timer(env, key)
    local id = env[key]
    if id then
        pcall(GLib.source_remove, id)
        env[key] = nil
    end
end

local function sync_open_classes(win, rev, is_open)
    if is_open then
        win:remove_css_class("is-closing")
        win:add_css_class("is-open")
        if rev and rev.add_css_class then
            rev:remove_css_class("is-closing")
            rev:add_css_class("is-open")
            local child = rev.get_child and rev:get_child()
            if child and child.add_css_class then
                child:remove_css_class("is-closing")
                child:add_css_class("is-open")
                child:add_css_class("open")
            end
        end
    else
        win:remove_css_class("is-open")
        win:add_css_class("is-closing")
        if rev and rev.remove_css_class then
            rev:remove_css_class("is-open")
            rev:add_css_class("is-closing")
            local child = rev.get_child and rev:get_child()
            if child and child.remove_css_class then
                child:remove_css_class("is-open")
                child:remove_css_class("open")
                child:add_css_class("is-closing")
            end
        end
    end
end

function Ignis.RevealerWindow:init(props)
    props = props or {}
    local env = base_widget.get_env(self)

    local rev = props.revealer
    if not rev then
        error("RevealerWindow requires a 'revealer' property")
    end
    env.revealer_instance = rev
    env._logical_visible = props.visible == true
    env._configured_kb_mode = props.kb_mode or "none"

    rev.reveal_child = env._logical_visible

    Window.init(self, props)

    self:add_css_class("exo-revealer-window")

    env.spring = Spring.new(self, Spring.Presets.EXPRESSIVE_DEFAULT, function(_, done)
        if done and not env._logical_visible then
            if not rev.child_revealed then
                Gtk.Window.set_visible(self, false)
            end
        end
    end)

    rev:connect("notify::child-revealed", function(self_rev)
        if not env._logical_visible and not self_rev.reveal_child and not self_rev.child_revealed then
            cancel_timer(env, "_close_fallback_id")
            self:remove_css_class("is-closing")
            Gtk.Window.set_visible(self, false)
        end
    end)

    if env._logical_visible then
        sync_open_classes(self, rev, true)
        env.spring:set_value(1.0, false)
    end
end

function Ignis.RevealerWindow:get_revealer()
    return base_widget.get_env(self).revealer_instance
end

function Ignis.RevealerWindow:set_revealer(value)
    base_widget.get_env(self).revealer_instance = value
end

function Ignis.RevealerWindow:get_spring()
    return base_widget.get_env(self).spring
end

function Ignis.RevealerWindow:get_visible()
    local env = base_widget.get_env(self)
    if env._logical_visible ~= nil then
        return env._logical_visible
    end
    local rev = self:get_revealer()
    return rev and rev.reveal_child or false
end

function Ignis.RevealerWindow:set_visible(value)
    value = value and true or false
    local env = base_widget.get_env(self)
    local rev = self:get_revealer()
    if not rev then
        env._logical_visible = value
        Gtk.Window.set_visible(self, value)
        self:notify("visible")
        return
    end

    cancel_timer(env, "_open_timer_id")
    cancel_timer(env, "_close_fallback_id")

    env._logical_visible = value

    if value then
        if env._configured_kb_mode and env._configured_kb_mode ~= "none" then
            self:set_kb_mode(env._configured_kb_mode)
        end

        local was_mapped = Gtk.Widget.get_visible(self)
        if not was_mapped then
            rev.reveal_child = false
            sync_open_classes(self, rev, false)
            Gtk.Window.set_visible(self, true)

            env._open_timer_id = GLib.timeout_add(GLib.PRIORITY_HIGH, 8, function()
                env._open_timer_id = nil
                if env._logical_visible then
                    sync_open_classes(self, rev, true)
                    rev.reveal_child = true
                    if env.spring then
                        env.spring:animate_to(1.0)
                    end
                end
                return false
            end)
        else
            sync_open_classes(self, rev, true)
            rev.reveal_child = true
            if env.spring then
                env.spring:animate_to(1.0)
            end
        end
    else
        if env.kb_mode and env.kb_mode ~= "none" then
            env._configured_kb_mode = env.kb_mode
            self:set_kb_mode("none")
        end

        sync_open_classes(self, rev, false)
        rev.reveal_child = false
        if env.spring then
            env.spring:animate_to(0.0)
        end

        if not rev.child_revealed then
            self:remove_css_class("is-closing")
            Gtk.Window.set_visible(self, false)
        else
            local duration = (rev.transition_duration or 240) + 60
            env._close_fallback_id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, duration, function()
                env._close_fallback_id = nil
                if not env._logical_visible then
                    self:remove_css_class("is-closing")
                    Gtk.Window.set_visible(self, false)
                end
                return false
            end)
        end
    end

    self:notify("visible")
end

return Ignis.RevealerWindow
