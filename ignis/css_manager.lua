local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local Gdk = lgi.require("Gdk", "4.0")
local Gio = lgi.Gio
local GLib = lgi.GLib
local gobject = require("ignis.gobject")
local exceptions = require("ignis.exceptions")
local FileMonitor = require("ignis.utils.file_monitor")

local GTK_STYLE_PRIORITIES = {
    application = Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    fallback = Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK,
    settings = Gtk.STYLE_PROVIDER_PRIORITY_SETTINGS,
    theme = Gtk.STYLE_PROVIDER_PRIORITY_THEME,
    user = Gtk.STYLE_PROVIDER_PRIORITY_USER,
}

local function get_gdk_display()
    local display = Gdk.Display.get_default()
    if display then
        return display
    else
        error(exceptions.DisplayNotFoundError())
    end
end

local function load_provider_css(provider, css_str)
    for _, method in ipairs({ "load_from_string", "load_from_data", "load_css" }) do
        local fn = provider[method]
        if type(fn) == "function" or type(fn) == "userdata" then
            local ok = pcall(function()
                if method == "load_from_data" then
                    fn(provider, css_str, #css_str)
                else
                    fn(provider, css_str)
                end
            end)
            if ok then
                return true
            end
        end
    end
    return false
end

local CssInfoBase = gobject.class(gobject.Object, {
    init = function(self, args)
        args = args or {}
        self.name = args.name
        self.priority = args.priority or "application"
        self.compiler_function = args.compiler_function
    end,

    _get_type = function(self)
        return "base"
    end,

    _get_string = function(self)
        return ""
    end
})

local CssInfoString = gobject.class(CssInfoBase, {
    init = function(self, args)
        CssInfoBase.init(self, args)
        self.string = args.string
    end,

    _get_type = function(self)
        return "string"
    end,

    _get_string = function(self)
        if self.compiler_function then
            return self.compiler_function(self.string)
        end
        return self.string
    end
})

local CssInfoPath = gobject.class(CssInfoBase, {
    init = function(self, args)
        CssInfoBase.init(self, args)
        self.path = args.path
        self.autoreload = args.autoreload ~= false
        self.watch_dir = args.watch_dir ~= false
        self.watch_recursively = args.watch_recursively ~= false
    end,

    _get_type = function(self)
        return "path"
    end,

    _get_string = function(self)
        if self.compiler_function then
            return self.compiler_function(self.path)
        end

        local extension = self.path:match("%.([^%.]+)$")
        if extension == "scss" or extension == "sass" then
            local sass = require("ignis.utils.sass")
            return sass.sass_compile({ path = self.path })
        end

        local f = io.open(self.path, "r")
        if not f then
            error("Could not open CSS file: " .. tostring(self.path))
        end
        local content = f:read("*a")
        f:close()
        return content
    end
})

local CssManager = gobject.class(gobject.Object, {
    init = function(self)
        self._css_infos = {}
        self._watchers = {}
        self._debounce_timers = {}
        self._suppress_watch_until = 0
        self._widgets_style_priority = "application"
    end,

    properties = {
        widgets_style_priority = {
            get = function(self)
                return self._widgets_style_priority
            end,
            set = function(self, value)
                self._widgets_style_priority = value
            end
        }
    },

    suppress_watch = function(self, duration_ms)
        self._suppress_watch_until = GLib.get_monotonic_time() + ((duration_ms or 220) * 1000)
    end,

    __watch_css_files = function(self, changed_path, event_type, name)
        local ev = tostring(event_type or ""):lower()
        if ev ~= "changes_done_hint" and ev ~= "changed" then
            return
        end
        if GLib.get_monotonic_time() < (self._suppress_watch_until or 0) then
            return
        end

        local extension = changed_path and changed_path:match("%.([^%.]+)$")
        if extension ~= "css" and extension ~= "scss" and extension ~= "sass" then
            return
        end

        if self._debounce_timers[name] then
            return
        end
        self._debounce_timers[name] = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 40, function()
            self._debounce_timers[name] = nil
            if self._css_infos[name] then
                pcall(function() self:reload_css(name) end)
            end
            return false
        end)
    end,

    __start_watching = function(self, info)
        if self._watchers[info.name] then
            return
        end
        local watch_path
        if info.watch_dir then
            local file = Gio.File.new_for_path(info.path)
            local parent = file:get_parent()
            watch_path = parent and parent:get_path() or "."
        else
            watch_path = info.path
        end

        local monitor = FileMonitor(watch_path, {
            prevent_gc = false,
            flags = Gio.FileMonitorFlags.NONE
        })
        monitor:connect("changed", function(_, path, event_type)
            self:__watch_css_files(path, event_type, info.name)
        end)

        self._watchers[info.name] = monitor
    end,

    __stop_watching = function(self, name)
        if self._debounce_timers[name] then
            pcall(GLib.source_remove, self._debounce_timers[name])
            self._debounce_timers[name] = nil
        end
        local file_monitor = self._watchers[name]
        if not file_monitor then
            return
        end
        file_monitor:cancel()
        self._watchers[name] = nil
    end,

    apply_css = function(self, info)
        if self._css_infos[info.name] then
            self:reload_css(info.name)
            return
        end

        local provider = Gtk.CssProvider()
        provider:connect("parsing-error", function(_, section, gerror)
            local line = "?"
            pcall(function()
                line = tostring(section:get_start_line())
            end)
            io.stderr:write(string.format(
                '[WARN] CSS parsing error in "%s" (line %s): %s\n',
                tostring(info.name), line, tostring(gerror)))
            self._last_parsing_error = { info = info, section = section, error = gerror }
        end)

        local success, css_str = pcall(function() return info:_get_string() end)
        if not success then
            error("Failed to compile or load CSS/SCSS: " .. tostring(css_str))
        end

        if not load_provider_css(provider, css_str) then
            error("Gtk.CssProvider could not load the stylesheet: no usable load method")
        end

        local display = get_gdk_display()
        local priority = GTK_STYLE_PRIORITIES[info.priority] or Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION

        Gtk.StyleContext.add_provider_for_display(
            display,
            provider,
            priority
        )

        self._css_infos[info.name] = { info = info, provider = provider }

        if info:_get_type() == "path" and info.autoreload then
            self:__start_watching(info)
        end

        self:emit("css-applied", info)
    end,

    remove_css = function(self, name)
        local item = self._css_infos[name]
        if not item then
            error(exceptions.CssInfoNotFoundError(name))
        end

        local info = item.info
        local provider = item.provider

        if info:_get_type() == "path" and info.autoreload then
            self:__stop_watching(name)
        end

        local display = get_gdk_display()
        Gtk.StyleContext.remove_provider_for_display(
            display,
            provider
        )

        self._css_infos[name] = nil
        self:emit("css-removed", info)
    end,

    reset_css = function(self)
        local names = {}
        for name, _ in pairs(self._css_infos) do
            table.insert(names, name)
        end
        for _, name in ipairs(names) do
            self:remove_css(name)
        end
        self:emit("css-resetted")
    end,

    reload_css = function(self, name)
        local item = self._css_infos[name]
        if not item then
            error(exceptions.CssInfoNotFoundError(name))
        end

        local info = item.info
        local provider = item.provider
        local ok_scss, scss = pcall(require, "ignis.utils.scss")
        if ok_scss and scss and scss.invalidate_cache then
            scss.invalidate_cache()
        end

        local success, css_str = pcall(function() return info:_get_string() end)
        if not success then
            io.stderr:write("[WARN] Failed to recompile CSS '" .. tostring(name) .. "': " .. tostring(css_str) .. "\n")
            return
        end

        load_provider_css(provider, css_str)
        self:emit("css-reloaded", info)
    end,

    reload_all_css = function(self)
        self:suppress_watch(250)
        local ok_scss, scss = pcall(require, "ignis.utils.scss")
        if ok_scss and scss and scss.invalidate_cache then
            scss.invalidate_cache()
        end
        for name, _ in pairs(self._css_infos) do
            self:reload_css(name)
        end
        self:emit("all-css-reloaded")
    end,

    get_css_info_by_name = function(self, name)
        local item = self._css_infos[name]
        return item and item.info or nil
    end,

    list_css_infos = function(self)
        local list = {}
        for _, item in pairs(self._css_infos) do
            table.insert(list, item.info)
        end
        return list
    end,

    list_css_info_names = function(self)
        local list = {}
        for name, _ in pairs(self._css_infos) do
            table.insert(list, name)
        end
        return list
    end
})

local default_instance = nil

function CssManager.get_default()
    if not default_instance then
        default_instance = CssManager()
    end
    return default_instance
end

return {
    CssInfoString = CssInfoString,
    CssInfoPath = CssInfoPath,
    CssManager = CssManager,
    get_default = CssManager.get_default
}
