local M = {}

local json = require("ignis.utils.json")
local shell = require("ignis.utils.shell")
local poll = require("ignis.utils.poll")
local timeout = require("ignis.utils.timeout")
local thread_task = require("ignis.utils.thread_task")
local socket = require("ignis.utils.socket")
local file = require("ignis.utils.file")
local native_ok, native = pcall(require, "ignis.native")

M.json = json
M.json_encode = json.encode
M.json_decode = json.decode

M.shell = shell
M.exec_sh = shell.exec_sh
M.exec_sh_async = shell.exec_sh_async
M.AsyncCompletedProcess = shell.AsyncCompletedProcess

M.Poll = poll
M.Timeout = timeout.Timeout
M.Debounce = timeout.Debounce
M.Throttle = timeout.Throttle
M.ThreadTask = thread_task

M.socket = socket
M.connect_unix_socket = socket.connect_unix_socket
M.send_socket = socket.send_socket
M.listen_socket = socket.listen_socket

M.file = file
M.expand_path = file.expand_path
M.file_exists = file.file_exists
M.is_dir = file.is_dir
M.read_file = file.read_file
M.write_file = file.write_file
M.read_file_async = file.read_file_async

function M.read_sys_telemetry()
    if native_ok and native and native.read_sys_telemetry then
        local t = native.read_sys_telemetry()
        if t then return t end
    end
    return {
        cpu_percent   = 0.0,
        mem_percent   = 0.0,
        mem_used_kb   = 0,
        mem_total_kb  = 0,
        mem_avail_kb  = 0,
        swap_percent  = 0.0,
        swap_used_kb  = 0,
        swap_total_kb = 0,
        temp_c        = 0.0,
        load_1m       = 0.0,
        load_5m       = 0.0,
        load_15m      = 0.0,
        net_rx_bps    = 0.0,
        net_tx_bps    = 0.0,
    }
end

function M.monotonic_us()
    if native_ok and native and native.monotonic_us then
        return native.monotonic_us()
    end
    local ok, lgi = pcall(require, "lgi")
    if ok and lgi.GLib then
        return lgi.GLib.get_monotonic_time()
    end
    return math.floor(os.clock() * 1000000)
end

local lazy_modules = {
    Spring = function() return require("ignis.utils.spring") end,
    FileMonitor = function() return require("ignis.utils.file_monitor") end,
    sass_compile = function() return require("ignis.utils.sass").sass_compile end,
    get_temp_dir = function() return require("ignis.utils.sass").get_temp_dir end,
    load_interface_xml = function() return require("ignis.utils.misc").load_interface_xml end,
    get_gdk_display = function() return require("ignis.utils.misc").get_gdk_display end,
    open_inspector = function() return require("ignis.utils.misc").open_inspector end,
    get_monitors = function() return require("ignis.utils.monitor").get_monitors end,
    get_monitor = function() return require("ignis.utils.monitor").get_monitor end,
    get_n_monitors = function() return require("ignis.utils.monitor").get_n_monitors end,
    scale_pixbuf = function() return require("ignis.utils.pixbuf").scale_pixbuf end,
    crop_pixbuf = function() return require("ignis.utils.pixbuf").crop_pixbuf end,
    get_paintable = function() return require("ignis.utils.pixbuf").get_paintable end,
    get_file_icon_name = function() return require("ignis.utils.pixbuf").get_file_icon_name end,
    get_app_icon_name = function() return require("ignis.utils.pixbuf").get_app_icon_name end,
    scss_compile = function() return require("ignis.utils.scss").compile_file end,
}

setmetatable(M, {
    __index = function(t, key)
        local loader = lazy_modules[key]
        if loader then
            local val = loader()
            rawset(t, key, val)
            return val
        end
        return nil
    end
})

return M
