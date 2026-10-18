local lgi = require("lgi")
local Gio = lgi.Gio
local gobject = require("ignis.gobject")
local FileMonitor = require("ignis.utils.file_monitor")

local ConfigManager = gobject.class(gobject.Object, {
    init = function(self)
        self._autoreload_config = true
        self._config_parsed = false
        self._monitor = nil
    end,
    
    properties = {
        autoreload_config = {
            get = function(self)
                return self._autoreload_config
            end,
            set = function(self, value)
                self._autoreload_config = value
            end
        },
        is_config_parsed = {
            get = function(self)
                return self._config_parsed
            end
        }
    },
    
    __watch_config = function(self, changed_path, event_type, app)
        local ev = event_type:lower()
        if ev ~= "changes_done_hint" then
            return
        end
        
        local is_dir = false
        local file = Gio.File.new_for_path(changed_path)
        local success, info = pcall(function()
            return file:query_info("standard::type", Gio.FileQueryInfoFlags.NONE, nil)
        end)
        if success and info then
            if info:get_file_type() == Gio.FileType.DIRECTORY then
                is_dir = true
            end
        end
        
        if not is_dir then
            local extension = changed_path:match("%.([^%.]+)$")
            if extension == "lua" and self._autoreload_config then
                app:reload()
            end
        end
    end,
    
    _load_config = function(self, app, path)
        local file = Gio.File.new_for_path(path)
        if not file:query_exists(nil) then
            error("Provided config path doesn't exist: " .. path)
        end
        
        local parent = file:get_parent()
        local config_dir = parent and parent:get_path() or "."
        
        print(string.format("[INFO] Using configuration file: %s", path))
        
        self._monitor = FileMonitor(config_dir, { prevent_gc = true })
        self._monitor:connect("changed", function(monitor, changed_path, event_type)
            self:__watch_config(changed_path, event_type, app)
        end)
        
        package.path = table.concat({
            config_dir .. "/?.lua",
            config_dir .. "/?/init.lua",
            package.path,
        }, ";")
        
        local success, err = pcall(dofile, path)
        if not success then
            error("Failed to load config: " .. tostring(err))
        end
        
        self._config_parsed = true
        self:emit("config-parsed")
        print("[INFO] Configuration parsed.")
        
        app:emit("ready")
    end
})

local default_instance = nil

function ConfigManager.get_default()
    if not default_instance then
        default_instance = ConfigManager()
    end
    return default_instance
end

return ConfigManager
