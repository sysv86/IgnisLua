require("ignis.gi")

local exceptions = require("ignis.exceptions")
local file_utils = require("ignis.utils.file")

local M = {}
M.VERSION = "0.6.0-lua5.5.1"

local HELP_TEXT = [[
IgnisLua — A high-performance reactive GTK4 widget framework for Wayland desktop shells in Lua 5.5

Usage:
  ignis <command> [options] [arguments]

Commands:
  init [-c|--config PATH] [--debug]   Initialize IgnisLua and load configuration
  open-window <WINDOW_NAME>           Open a window by namespace
  close-window <WINDOW_NAME>          Close a window by namespace
  toggle-window <WINDOW_NAME>         Toggle visibility of a window by namespace
  list-windows                        List all registered window namespaces
  run-command <NAME> [ARGS...]        Run a registered CommandManager command
  list-commands                       List all registered CommandManager commands
  run-lua <CODE>                      Evaluate Lua code inside the running Ignis instance
  run-file <PATH>                     Execute a Lua file inside the running Ignis instance
  inspector                           Open the GTK4 interactive debugger
  reload                              Reload the running Ignis instance
  quit                                Quit the running Ignis instance
  system-info                         Print system and runtime diagnostics

Options:
  -h, --help                          Show this help message and exit
  -v, --version                       Show IgnisLua version and exit
]]

local function get_ipc_proxy()
    local dbus = require("ignis.dbus")
    local misc = require("ignis.utils.misc")
    local proxy = dbus.DBusProxy.new(
        "com.github.linkfrg.ignis",
        "/com/github/linkfrg/ignis",
        "com.github.linkfrg.ignis",
        misc.load_interface_xml("com.github.linkfrg.ignis"),
        "session"
    )
    if not proxy.has_owner then
        io.stderr:write("Error: " .. tostring(exceptions.IgnisNotRunningError()) .. "\n")
        os.exit(1)
    end
    return proxy
end

function M.print_help()
    print(HELP_TEXT)
end

function M.print_version()
    print(string.format("IgnisLua %s (%s)", M.VERSION, _VERSION))
end

function M.print_system_info()
    local fetch = require("ignis.services.fetch").get_default()
    print(string.format("IgnisLua Version : %s", M.VERSION))
    print(string.format("Lua Runtime      : %s", _VERSION))
    print(string.format("OS               : %s (%s)", fetch.os_pretty_name, fetch.os_id))
    print(string.format("Kernel           : %s", fetch.kernel))
    print(string.format("Hostname         : %s", fetch.hostname))
    print(string.format("Desktop          : %s (%s)", fetch.current_desktop, fetch.session_type))
    print(string.format("CPU              : %s (%d cores)", fetch.cpu, fetch.cpu_cores))
    print(string.format("Memory           : %d MiB / %d MiB (%.1f%%)",
        math.floor(fetch.mem_used / 1024),
        math.floor(fetch.mem_total / 1024),
        fetch.mem_percent
    ))
end

function M.cmd_init(args)
    local config_path = nil
    local debug_mode = false
    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "-c" or a == "--config" then
            config_path = args[i + 1]
            i = i + 2
        elseif a:sub(1, 9) == "--config=" then
            config_path = a:sub(10)
            i = i + 1
        elseif a == "--debug" or a == "-d" then
            debug_mode = true
            i = i + 1
        else
            i = i + 1
        end
    end

    if not config_path then
        local xdg_config = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or ".") .. "/.config")
        config_path = xdg_config .. "/ignis/config.lua"
    end
    config_path = file_utils.expand_path(config_path)

    local ignis = require("ignis")
    local app = ignis.App.get_default()
    local cfg_mgr = ignis.ConfigManager.get_default()

    app.on_activate = function(app_inst)
        app_inst:__activate()
        if debug_mode then
            app_inst:inspector()
        end
        cfg_mgr:_load_config(app_inst, config_path)
    end

    app:run({})
end

function M.run(argv)
    argv = argv or arg or {}
    local cmd = argv[1]

    if not cmd or cmd == "-h" or cmd == "--help" or cmd == "help" then
        M.print_help()
        return 0
    elseif cmd == "-v" or cmd == "--version" or cmd == "version" then
        M.print_version()
        return 0
    elseif cmd == "system-info" then
        M.print_system_info()
        return 0
    end

    local sub_args = {}
    for i = 2, #argv do
        sub_args[i - 1] = argv[i]
    end

    if cmd == "init" then
        M.cmd_init(sub_args)
        return 0
    end

    local proxy = get_ipc_proxy()

    if cmd == "open-window" then
        local name = sub_args[1]
        if not name then
            io.stderr:write("Usage: ignis open-window <WINDOW_NAME>\n")
            return 1
        end
        if not proxy:OpenWindow("(s)", name) then
            io.stderr:write("No such window: " .. name .. "\n")
            return 1
        end
    elseif cmd == "close-window" then
        local name = sub_args[1]
        if not name then
            io.stderr:write("Usage: ignis close-window <WINDOW_NAME>\n")
            return 1
        end
        if not proxy:CloseWindow("(s)", name) then
            io.stderr:write("No such window: " .. name .. "\n")
            return 1
        end
    elseif cmd == "toggle-window" then
        local name = sub_args[1]
        if not name then
            io.stderr:write("Usage: ignis toggle-window <WINDOW_NAME>\n")
            return 1
        end
        if not proxy:ToggleWindow("(s)", name) then
            io.stderr:write("No such window: " .. name .. "\n")
            return 1
        end
    elseif cmd == "list-windows" then
        local windows = proxy:ListWindows("") or {}
        for _, w in ipairs(windows) do
            print(w)
        end
    elseif cmd == "list-commands" then
        local commands = proxy:ListCommands("") or {}
        for _, c in ipairs(commands) do
            print(c)
        end
    elseif cmd == "run-command" then
        local cmd_name = sub_args[1]
        if not cmd_name then
            io.stderr:write("Usage: ignis run-command <COMMAND_NAME> [ARGS...]\n")
            return 1
        end
        local cmd_args = {}
        for i = 2, #sub_args do
            cmd_args[i - 1] = sub_args[i]
        end
        local res = proxy:RunCommand("(sas)", cmd_name, cmd_args)
        if type(res) == "table" then
            local err_str, out_str = res[1], res[2]
            if err_str and err_str ~= "" then
                io.stderr:write(err_str .. "\n")
                return 1
            end
            if out_str and out_str ~= "" then
                print(out_str)
            end
        end
    elseif cmd == "run-lua" or cmd == "run-python" then
        local code = table.concat(sub_args, " ")
        if code == "" then
            io.stderr:write("Usage: ignis run-lua <CODE>\n")
            return 1
        end
        proxy:RunLua("(s)", code)
    elseif cmd == "run-file" then
        local path = sub_args[1]
        if not path then
            io.stderr:write("Usage: ignis run-file <PATH>\n")
            return 1
        end
        proxy:RunFile("(s)", file_utils.expand_path(path))
    elseif cmd == "inspector" then
        proxy:Inspector("")
    elseif cmd == "reload" then
        proxy:Reload("")
    elseif cmd == "quit" then
        proxy:Quit("")
    else
        io.stderr:write("Unknown command: " .. tostring(cmd) .. "\n\n")
        M.print_help()
        return 1
    end

    return 0
end

return M
