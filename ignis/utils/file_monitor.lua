local lgi = require("lgi")
local Gio = lgi.Gio
local gobject = require("ignis.gobject")

local global_monitors = {}

local FileMonitor = gobject.class(gobject.Object, {
    init = function(self, path, opts)
        opts = opts or {}
        self.path = path
        self.prevent_gc = opts.prevent_gc or false
        self.flags = opts.flags or Gio.FileMonitorFlags.NONE
        
        self.monitors = {}        -- path -> GIO monitor
        self.monitored_paths = {}  -- path -> true

        if self.prevent_gc then
            global_monitors[self] = true
        end

        local file = Gio.File.new_for_path(path)
        local is_dir = false
        local success, info = pcall(function()
            return file:query_info("standard::type", Gio.FileQueryInfoFlags.NONE, nil)
        end)
        
        if success and info then
            local file_type = info:get_file_type()
            if file_type == Gio.FileType.DIRECTORY then
                is_dir = true
            end
        end

        if is_dir then
            self:add_monitor_recursive(file)
        else
            local success_mon, monitor = pcall(function()
                return file:monitor(self.flags, nil)
            end)
            if success_mon and monitor then
                self.monitors[path] = monitor
                self.monitored_paths[path] = true
                require("ignis.gi").connect_signal(monitor, "changed", function(_, f, other_f, event_type)
                    self:on_changed(f, other_f, event_type)
                end)
            end
        end
    end,

    add_monitor_recursive = function(self, directory_file)
        local path = directory_file:get_path()
        if self.monitored_paths[path] then
            return
        end

        local success, monitor = pcall(function()
            return directory_file:monitor(self.flags, nil)
        end)

        if success and monitor then
            self.monitors[path] = monitor
            self.monitored_paths[path] = true

            require("ignis.gi").connect_signal(monitor, "changed", function(_, f, other_f, event_type)
                self:on_changed(f, other_f, event_type)
            end)
        end

        local success_enum, enumerator = pcall(function()
            return directory_file:enumerate_children(
                "standard::name,standard::type",
                Gio.FileQueryInfoFlags.NONE,
                nil
            )
        end)

        if success_enum and enumerator then
            while true do
                local info = enumerator:next_file(nil)
                if not info then break end

                local file_type = info:get_file_type()
                if file_type == Gio.FileType.DIRECTORY then
                    local child = directory_file:get_child(info:get_name())
                    self:add_monitor_recursive(child)
                end
            end
            enumerator:close(nil)
        end
    end,

    on_changed = function(self, file, other_file, event_type)
        local path = file:get_path()
        local event_str = tostring(event_type)

        if event_str == "CREATED" or event_str == "CHANGES_DONE_HINT" then
            local success, info = pcall(function()
                return file:query_info("standard::type", Gio.FileQueryInfoFlags.NONE, nil)
            end)
            if success and info then
                local file_type = info:get_file_type()
                if file_type == Gio.FileType.DIRECTORY then
                    self:add_monitor_recursive(file)
                end
            end
        end

        self:emit("changed", path, event_str)
    end,

    cancel = function(self)
        for _, monitor in pairs(self.monitors) do
            pcall(function()
                monitor:cancel()
            end)
        end
        self.monitors = {}
        self.monitored_paths = {}
        global_monitors[self] = nil
    end
})

return FileMonitor
