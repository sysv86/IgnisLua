local lgi = require("lgi")
local Gio = lgi.Gio
local Gdk = lgi.require("Gdk", "4.0")
local misc = require("ignis.utils.misc")

local M = {}

function M.get_monitors()
    local display = misc.get_gdk_display()
    return display:get_monitors()
end

function M.get_monitor(monitor_id)
    if not monitor_id then return nil end
    local monitors = M.get_monitors()
    if not monitors then return nil end
    return monitors:get_item(monitor_id)
end

function M.get_n_monitors()
    local monitors = M.get_monitors()
    if not monitors then return 0 end
    return monitors:get_n_items()
end

return M
