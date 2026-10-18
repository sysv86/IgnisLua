local lgi = require("lgi")
local GLib = lgi.GLib
local Gio = lgi.Gio
local dbus = require("ignis.dbus")
local misc = require("ignis.utils.misc")
local gobject = require("ignis.gobject")
local unpack = table.unpack or unpack

local WindowManager = require("ignis.window_manager")
local CommandManager = require("ignis.command_manager")

local window_manager = WindowManager.get_default()
local command_manager = CommandManager.get_default()

local IgnisIpc = gobject.class(gobject.Object, {
    init = function(self, name, app)
        self._name = name or "com.github.linkfrg.ignis"
        self._app = app

        local info = misc.load_interface_xml("com.github.linkfrg.ignis")

        self._dbus = dbus.DBusService(
            self._name,
            "/com/github/linkfrg/ignis",
            info
        )

        self._dbus:register_dbus_method("OpenWindow", function(invocation, window_name)
            return self:__OpenWindow(invocation, window_name)
        end)

        self._dbus:register_dbus_method("CloseWindow", function(invocation, window_name)
            return self:__CloseWindow(invocation, window_name)
        end)

        self._dbus:register_dbus_method("ToggleWindow", function(invocation, window_name)
            return self:__ToggleWindow(invocation, window_name)
        end)

        self._dbus:register_dbus_method("ListWindows", function(invocation)
            return self:__ListWindows(invocation)
        end)

        self._dbus:register_dbus_method("Quit", function(invocation)
            return self:__Quit(invocation)
        end)

        self._dbus:register_dbus_method("Reload", function(invocation)
            return self:__Reload(invocation)
        end)

        self._dbus:register_dbus_method("Inspector", function(invocation)
            return self:__Inspector(invocation)
        end)

        self._dbus:register_dbus_method("RunPython", function(invocation, code)
            return self:__RunLua(invocation, code)
        end)

        self._dbus:register_dbus_method("RunLua", function(invocation, code)
            return self:__RunLua(invocation, code)
        end)

        self._dbus:register_dbus_method("RunFile", function(invocation, path)
            return self:__RunFile(invocation, path)
        end)

        self._dbus:register_dbus_method("RunCommand", function(invocation, command_name, command_args)
            return self:__RunCommand(invocation, command_name, command_args)
        end)

        self._dbus:register_dbus_method("ListCommands", function(invocation)
            return self:__ListCommands(invocation)
        end)
    end,

    __call_window_method = function(self, type_name, window_name)
        local success = pcall(function()
            window_manager[type_name .. "_window"](window_manager, window_name)
        end)
        return GLib.Variant("(b)", { success })
    end,

    __OpenWindow = function(self, _, window_name)
        return self:__call_window_method("open", window_name)
    end,

    __CloseWindow = function(self, _, window_name)
        return self:__call_window_method("close", window_name)
    end,

    __ToggleWindow = function(self, _, window_name)
        return self:__call_window_method("toggle", window_name)
    end,

    __ListWindows = function(self, _)
        local windows = window_manager:list_window_names()
        return GLib.Variant("(as)", { windows })
    end,

    __ListCommands = function(self, _)
        local commands = command_manager:list_command_names()
        return GLib.Variant("(as)", { commands })
    end,

    __RunCommand = function(self, _, command_name, command_args)
        local success, output = pcall(function()
            return command_manager:run_command(command_name, unpack(command_args or {}))
        end)
        if success then
            return GLib.Variant("(ss)", { "", tostring(output or "") })
        else
            return GLib.Variant("(ss)", { tostring(output), "" })
        end
    end,

    __RunLua = function(self, invocation, code)
        local fn, load_err = load(code, "=(ipc-run-lua)")
        if not fn then
            invocation:return_dbus_error("com.github.linkfrg.ignis.Error", tostring(load_err))
            return
        end
        local ok, exec_err = pcall(fn)
        if not ok then
            invocation:return_dbus_error("com.github.linkfrg.ignis.Error", tostring(exec_err))
            return
        end
        pcall(function() invocation:return_value(nil) end)
    end,

    __RunFile = function(self, invocation, path)
        local ok, exec_err = pcall(dofile, path)
        if not ok then
            invocation:return_dbus_error("com.github.linkfrg.ignis.Error", tostring(exec_err))
            return
        end
        pcall(function() invocation:return_value(nil) end)
    end,

    __Inspector = function(self, invocation)
        pcall(function() invocation:return_value(nil) end)
        misc.open_inspector()
    end,

    __Reload = function(self, invocation)
        pcall(function() invocation:return_value(nil) end)
        self._app:reload()
    end,

    __Quit = function(self, invocation)
        pcall(function() invocation:return_value(nil) end)
        self._app:quit()
    end
})

return IgnisIpc
