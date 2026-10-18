local gi = require("ignis.gi")
local GLib = gi.GLib
local Gtk = gi.Gtk
local Gdk = gi.Gdk
local Gtk4LayerShell = gi.Gtk4LayerShell
local GdkPixbuf = gi.GdkPixbuf

local M = {}

M.VERSION = "0.8.0-m3-expressive"
M.GI_BACKEND = gi.backend_name
M.native = gi.native
M.gi = gi

M.CACHE_DIR = GLib.get_user_cache_dir() .. "/ignis"
M.DATA_DIR = GLib.get_user_data_dir() .. "/ignis"

local function makedirs(path)
    GLib.mkdir_with_parents(path, 493) -- 0755
end
makedirs(M.CACHE_DIR)
makedirs(M.DATA_DIR)

M.Gtk = Gtk
M.Gdk = Gdk
M.Gtk4LayerShell = Gtk4LayerShell
M.GdkPixbuf = GdkPixbuf
M.GLib = GLib
M.Gio = gi.Gio
M.GObject = gi.GObject

local gobject = require("ignis.gobject")
M.class = gobject.class
M.Object = gobject.Object
M.Binding = gobject.Binding

M.Variable = require("ignis.variable")
M.Spring = require("ignis.utils.spring")
M.exceptions = require("ignis.exceptions")
M.FileMonitor = require("ignis.utils.file_monitor")
M.sass = require("ignis.utils.sass")

local options_manager = require("ignis.options_manager")
M.OptionsManager = options_manager.OptionsManager
M.OptionsGroup = options_manager.OptionsGroup
M.options_manager = options_manager

M.App = require("ignis.app")
M.WindowManager = require("ignis.window_manager")
M.ConfigManager = require("ignis.config_manager")
M.CommandManager = require("ignis.command_manager")
M.IconManager = require("ignis.icon_manager")

local css = require("ignis.css_manager")
M.CssManager = css
M.CssInfoString = css.CssInfoString
M.CssInfoPath = css.CssInfoPath

local dbus = require("ignis.dbus")
M.DBusService = dbus.DBusService
M.DBusProxy = dbus.DBusProxy
M.Ipc = require("ignis.ipc")

M.utils = require("ignis.utils")
M.widgets = require("ignis.widgets")
M.services = require("ignis.services")
M.cli = require("ignis.cli")

local temp_dir = nil
function M.get_temp_dir()
    if not temp_dir then
        temp_dir = GLib.dir_make_tmp("ignis-XXXXXX")
    end
    return temp_dir
end

function M._clear_temp_dir()
    if temp_dir then
        os.execute("rm -rf " .. temp_dir)
        temp_dir = nil
    end
end

return M
