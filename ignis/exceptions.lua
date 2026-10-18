local M = {}

local function create_error_class(name, message_fn)
    local klass = {}
    klass.__index = klass
    
    function klass:new(...)
        local self_instance = setmetatable({}, klass)
        self_instance.name = name
        local msg, attrs = message_fn(...)
        self_instance.message = msg or (name .. " occurred")
        if attrs then
            for k, v in pairs(attrs) do
                self_instance[k] = v
            end
        end
        return self_instance
    end

    klass.__tostring = function(self)
        return self.message
    end

    setmetatable(klass, {
        __call = function(t, ...)
            return t:new(...)
        end
    })

    return klass
end

M.AppNotInitializedError = create_error_class("AppNotInitializedError", function()
    return "Called IgnisApp.get_initialized(), but IgnisApp is not initialized!"
end)

M.DisplayNotFoundError = create_error_class("DisplayNotFoundError", function()
    return "Display not found! Ensure you are running a Wayland compositor"
end)

M.WindowNotFoundError = create_error_class("WindowNotFoundError", function(window_name)
    return string.format('No such window: "%s"', tostring(window_name)), { window_name = window_name }
end)

M.WindowAddedError = create_error_class("WindowAddedError", function(window_name)
    return string.format('Window already added: "%s"', tostring(window_name)), { window_name = window_name }
end)

M.CommandNotFoundError = create_error_class("CommandNotFoundError", function(command_name)
    return string.format('No such command: "%s"', tostring(command_name)), { command_name = command_name }
end)

M.CommandAddedError = create_error_class("CommandAddedError", function(command_name)
    return string.format('Command already added: "%s"', tostring(command_name)), { command_name = command_name }
end)

M.GvcNotFoundError = create_error_class("GvcNotFoundError", function()
    return "Gvc not found! To use the audio service, install ignis-gvc"
end)

M.HyprlandIPCNotFoundError = create_error_class("HyprlandIPCNotFoundError", function()
    return "Hyprland IPC not found! To use the Hyprland service, ensure that Hyprland is running"
end)

M.NiriIPCNotFoundError = create_error_class("NiriIPCNotFoundError", function()
    return "Niri IPC not found! To use the Niri service, ensure that Niri is running"
end)

M.NetworkManagerNotFoundError = create_error_class("NetworkManagerNotFoundError", function()
    return "NetworkManager not found! To use the network service, install NetworkManager"
end)

M.SassCompilationError = create_error_class("SassCompilationError", function(stderr)
    return string.format("SASS compilation error:\n%s", tostring(stderr)), { stderr = stderr }
end)

M.SassNotFoundError = create_error_class("SassNotFoundError", function()
    return "Sass compiler not found! To compile SCSS/SASS, install either dart-sass or grass-sass"
end)

M.MonitorNotFoundError = create_error_class("MonitorNotFoundError", function(monitor_id)
    return string.format("No such monitor with id: %s", tostring(monitor_id)), { monitor_id = monitor_id }
end)

M.LayerShellNotSupportedError = create_error_class("LayerShellNotSupportedError", function()
    return "zwlr_layer_shell_v1 is not supported! Ensure you are running a Wayland compositor that implements the zwlr_layer_shell_v1 protocol"
end)

M.IgnisNotRunningError = create_error_class("IgnisNotRunningError", function()
    return "Ignis is not running"
end)

M.DBusMethodNotFoundError = create_error_class("DBusMethodNotFoundError", function(method_name)
    return string.format('No such registered D-Bus method with name: "%s"', tostring(method_name)), { method_name = method_name }
end)

M.DBusPropertyNotFoundError = create_error_class("DBusPropertyNotFoundError", function(property_name)
    return string.format('No such registered D-Bus property with name: "%s"', tostring(property_name)), { property_name = property_name }
end)

M.Gtk4LayerShellNotFoundError = create_error_class("Gtk4LayerShellNotFoundError", function()
    return "GTK4 Layer Shell is not found! To use Ignis, first install it"
end)

M.CssParsingError = create_error_class("CssParsingError", function(section, gerror)
    local sec_str = section and section:to_string() or "CSS parsing error"
    local err_msg = gerror and gerror.message or "Unknown"
    return string.format("%s: %s", sec_str, err_msg), { section = section, gerror = gerror }
end)

M.AnotherNotificationDaemonRunningError = create_error_class("AnotherNotificationDaemonRunningError", function(name)
    return string.format("Another notification daemon is already running: %s", tostring(name)), { name = name }
end)

M.AnotherSystemTrayRunningError = create_error_class("AnotherSystemTrayRunningError", function(name)
    return string.format("Another system tray is already running: %s", tostring(name)), { name = name }
end)

M.UPowerNotRunningError = create_error_class("UPowerNotRunningError", function()
    return "UPower is not running! To use the UPower Service, install UPower and run it"
end)

M.PowerProfilesDaemonNotRunningError = create_error_class("PowerProfilesDaemonNotRunningError", function()
    return "Power Profiles daemon is not running. To use the Power Profile service, install and run power-profiles-daemon"
end)

M.GnomeBluetoothNotFoundError = create_error_class("GnomeBluetoothNotFoundError", function()
    return "GnomeBluetooth-3.0 is not found! To use the Bluetooth Service, install GnomeBluetooth-3.0"
end)

M.GpuScreenRecorderError = create_error_class("GpuScreenRecorderError", function(returncode, stderr)
    return string.format("gpu-screen-recorder exited with returncode %s:\n%s", tostring(returncode), tostring(stderr)), { returncode = returncode, stderr = stderr }
end)

M.GpuScreenRecorderNotFoundError = create_error_class("GpuScreenRecorderNotFoundError", function()
    return "gpu-screen-recorder is not found! To use the Recorder Service, install gpu-screen-recorder"
end)

M.RecorderPortalCaptureCanceled = create_error_class("RecorderPortalCaptureCanceled", function()
    return "The desktop portal capture was canceled by the user"
end)

M.CssInfoNotFoundError = create_error_class("CssInfoNotFoundError", function(name)
    return string.format('CSS info with the given name is not found: "%s"', tostring(name)), { name = name }
end)

M.CssInfoAlreadyAppliedError = create_error_class("CssInfoAlreadyAppliedError", function(name)
    return string.format('CSS info with the given name is already applied: "%s"', tostring(name)), { name = name }
end)

return M
