local lgi = require("lgi")
local Gio = lgi.Gio
local Gdk = lgi.require("Gdk", "4.0")
local Gtk = lgi.require("Gtk", "4.0")
local exceptions = require("ignis.exceptions")

local M = {}

local DBUS_DIR
local ok, path = pcall(package.searchpath, "ignis.init", package.path)
if ok and path then
    DBUS_DIR = path:gsub("init%.lua$", "dbus")
else
    DBUS_DIR = "./ignis/dbus"
end

function M.load_interface_xml(interface_name, path, xml_string)
    local content
    if interface_name then
        local file_path = DBUS_DIR .. "/" .. interface_name .. ".xml"
        local file = io.open(file_path, "r")
        if not file then
            error("Could not open D-Bus interface file: " .. file_path)
        end
        content = file:read("*a")
        file:close()
    elseif path then
        local file = io.open(path, "r")
        if not file then
            error("Could not open D-Bus interface file at path: " .. path)
        end
        content = file:read("*a")
        file:close()
    elseif xml_string then
        content = xml_string
    else
        error("load_interface_xml() requires at least one argument")
    end

    local node_info, err = Gio.DBusNodeInfo.new_for_xml(content)
    if not node_info then
        error("Failed to parse D-Bus interface XML: " .. tostring(err))
    end
    return node_info.interfaces[1]
end

function M.get_gdk_display()
    local display = Gdk.Display.get_default()
    if display then
        return display
    else
        error(exceptions.DisplayNotFoundError())
    end
end

function M.open_inspector()
    Gtk.Window.set_interactive_debugging(true)
end

return M
