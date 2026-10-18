local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local Gdk = lgi.require("Gdk", "4.0")
local Gio = lgi.Gio
local exceptions = require("ignis.exceptions")
local gobject = require("ignis.gobject")

local Ignis = lgi.package("Ignis")
Ignis:class("App", Gtk.Application)

for k, v in pairs(gobject.ObjectMethods) do
    if type(v) == "function" and not Ignis.App[k] then
        Ignis.App[k] = v
    end
end
for k, v in pairs(gobject.Object) do
    if type(v) == "function" and not Ignis.App[k] then
        Ignis.App[k] = v
    end
end

local default_instance = nil
local instance_initialized = false

local reload_on_monitors_change = true
local autoreload_css = true
local ipc = nil

function Ignis.App:init()
    default_instance = self
    instance_initialized = true

    local success, IgnisIpc = pcall(require, "ignis.ipc")
    if success and IgnisIpc then
        local ok, instance = pcall(IgnisIpc, "com.github.linkfrg.ignis", self)
        if ok then
            ipc = instance
        else
            io.stderr:write("[WARN] Ignis D-Bus IPC unavailable: " .. tostring(instance) .. "\n")
        end
    end
end

function Ignis.App:__watch_monitors()
    local display = Gdk.Display.get_default()
    if not display then return end
    
    local monitors = display:get_monitors()
    if not monitors then return end
    
    monitors:connect("items-changed", function()
        if reload_on_monitors_change then
            print("[INFO] Monitors have changed, reloading.")
            self:reload()
        end
    end)
end

function Ignis.App:__activate()
    self:hold()
    self:__watch_monitors()

    if os.getenv("IGNIS_LOOP_HEARTBEAT") then
        local GLib = lgi.GLib
        GLib.timeout_add(GLib.PRIORITY_LOW, 1000, function()
            io.stderr:write(string.format("[HB %s] loop alive\n", os.date("%H:%M:%S")))
            io.stderr:flush()
            return true
        end)
    end
end

function Ignis.App:reload()
    self:quit()
    
    local cmd_parts = {}
    if arg[-1] then
        table.insert(cmd_parts, string.format('"%s"', arg[-1]))
    end
    local j = 0
    while arg[j] do
        table.insert(cmd_parts, string.format('"%s"', arg[j]))
        j = j + 1
    end
    
    local cmd = table.concat(cmd_parts, " ")
    local log = (os.getenv("XDG_CACHE_HOME") or ((os.getenv("HOME") or ".") .. "/.cache"))
        .. "/ignis-reload.log"
    os.execute(string.format("( sleep 2; %s ) >>%q 2>&1 &", cmd, log))
    os.exit(0)
end

function Ignis.App:quit()
    local ignis_mod = require("ignis")
    if ignis_mod._clear_temp_dir then
        ignis_mod._clear_temp_dir()
    end
    
    pcall(Gtk.Application.quit, self)
    print("[INFO] Quitting.")
end

function Ignis.App:get_reload_on_monitors_change()
    return reload_on_monitors_change
end

function Ignis.App:set_reload_on_monitors_change(value)
    reload_on_monitors_change = value
end

function Ignis.App:get_is_ready()
    local config_manager = require("ignis.config_manager").get_default()
    return config_manager.is_config_parsed
end

function Ignis.App:get_windows()
    local window_manager = require("ignis.window_manager").get_default()
    return window_manager.windows
end

function Ignis.App:get_autoreload_config()
    local config_manager = require("ignis.config_manager").get_default()
    return config_manager.autoreload_config
end

function Ignis.App:set_autoreload_config(value)
    local config_manager = require("ignis.config_manager").get_default()
    config_manager.autoreload_config = value
end

function Ignis.App:get_autoreload_css()
    return autoreload_css
end

function Ignis.App:set_autoreload_css(value)
    autoreload_css = value
end

function Ignis.App:get_widgets_style_priority()
    local css_manager = require("ignis.css_manager").get_default()
    return css_manager.widgets_style_priority
end

function Ignis.App:set_widgets_style_priority(value)
    local css_manager = require("ignis.css_manager").get_default()
    css_manager.widgets_style_priority = value
end

function Ignis.App.get_initialized()
    local gapp = Gtk.Application.get_default()
    if not gapp then
        error(exceptions.AppNotInitializedError())
    end

    if not instance_initialized or not default_instance then
        error("The default Gtk.Application is not an instance of IgnisApp")
    end

    return default_instance
end

function Ignis.App.get_default()
    if not default_instance then
        local app = Ignis.App {
            application_id = "com.github.linkfrg.ignis",
            flags = Gio.ApplicationFlags.DEFAULT_FLAGS
        }
        app:init()
        default_instance = app
    end
    return default_instance
end

function Ignis.App:add_icons(path)
    local success, icon_manager = pcall(require, "ignis.icon_manager")
    if success and icon_manager then
        icon_manager.get_default():add_icons(path)
    else
        print("[WARNING] IconManager not ported yet, add_icons ignored.")
    end
end

function Ignis.App:apply_css(style_path, style_priority, compiler)
    style_priority = style_priority or "application"
    local css_manager = require("ignis.css_manager")
    
    local compiler_function = nil
    if style_path:match("%.scss$") or style_path:match("%.sass$") then
        compiler_function = function(path)
            local sass = require("ignis.utils.sass")
            return sass.sass_compile({ path = path, compiler = compiler })
        end
    end
    
    local info = css_manager.CssInfoPath({
        name = style_path,
        priority = style_priority,
        compiler_function = compiler_function,
        path = style_path,
        autoreload = autoreload_css
    })
    
    css_manager.get_default():apply_css(info)
end

function Ignis.App:remove_css(style_path)
    local css_manager = require("ignis.css_manager")
    css_manager.get_default():remove_css(style_path)
end

function Ignis.App:reset_css()
    local css_manager = require("ignis.css_manager")
    css_manager.get_default():reset_css()
end

function Ignis.App:reload_css()
    local css_manager = require("ignis.css_manager")
    css_manager.get_default():reload_all_css()
end

function Ignis.App:get_window(window_name)
    local window_manager = require("ignis.window_manager")
    return window_manager.get_default():get_window(window_name)
end

function Ignis.App:open_window(window_name)
    local window_manager = require("ignis.window_manager")
    window_manager.get_default():open_window(window_name)
end

function Ignis.App:close_window(window_name)
    local window_manager = require("ignis.window_manager")
    window_manager.get_default():close_window(window_name)
end

function Ignis.App:toggle_window(window_name)
    local window_manager = require("ignis.window_manager")
    window_manager.get_default():toggle_window(window_name)
end

function Ignis.App:add_window(window_name, window)
    local window_manager = require("ignis.window_manager")
    window_manager.get_default():add_window(window_name, window)
end

function Ignis.App:remove_window(window_name)
    local window_manager = require("ignis.window_manager")
    window_manager.get_default():remove_window(window_name)
end

function Ignis.App:inspector()
    pcall(function()
        Gtk.Window.set_interactive_debugging(true)
    end)
end

return Ignis.App
