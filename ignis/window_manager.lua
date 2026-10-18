local gobject = require("ignis.gobject")
local exceptions = require("ignis.exceptions")

local WindowManager = gobject.class(gobject.Object, {
    init = function(self)
        self._windows = {}
        self._suppress_osd = false
    end,
    
    properties = {
        windows = {
            get = function(self)
                local list = {}
                for _, win in pairs(self._windows) do
                    table.insert(list, win)
                end
                return list
            end
        },
        suppress_osd = {
            get = function(self)
                return self._suppress_osd
            end,
            set = function(self, value)
                self._suppress_osd = value and true or false
            end
        }
    },
    
    get_window = function(self, window_name)
        local window = self._windows[window_name]
        if window then
            return window
        end
        if type(window_name) == "string" then
            local target_lower = window_name:lower()
            for name, win in pairs(self._windows) do
                if type(name) == "string" and name:lower() == target_lower then
                    return win
                end
            end
        end
        error(exceptions.WindowNotFoundError(window_name))
    end,
    
    add_window = function(self, window_name, window)
        if self._windows[window_name] then
            error(exceptions.WindowAddedError(window_name))
        end
        self._windows[window_name] = window
        self:notify("windows")
    end,
    
    remove_window = function(self, window_name)
        local window = self._windows[window_name]
        if not window then
            error(exceptions.WindowNotFoundError(window_name))
        end
        self._windows[window_name] = nil
        self:notify("windows")
    end,
    
    open_window = function(self, window_name)
        local window = self:get_window(window_name)
        window:set_visible(true)
        if window.present then
            pcall(function() window:present() end)
        end
    end,
    
    close_window = function(self, window_name)
        local window = self:get_window(window_name)
        window:set_visible(false)
    end,
    
    toggle_window = function(self, window_name)
        local window = self:get_window(window_name)
        local target = not window:get_visible()
        window:set_visible(target)
        if target and window.present then
            pcall(function() window:present() end)
        end
    end,
    
    list_window_names = function(self)
        local names = {}
        for name, _ in pairs(self._windows) do
            table.insert(names, name)
        end
        return names
    end
})

local default_instance = nil

function WindowManager.get_default()
    if not default_instance then
        default_instance = WindowManager()
    end
    return default_instance
end

return WindowManager
