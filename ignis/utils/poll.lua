local gobject = require("ignis.gobject")
local unpack = table.unpack or unpack

local Poll = gobject.class(gobject.Object, {
    init = function(self, timeout, callback, ...)
        if type(timeout) == "table" then
            local opts = timeout
            timeout = opts.timeout
            callback = opts.callback
            self._args = opts.args or {}
        else
            self._args = { ... }
        end

        self._timeout = timeout or 1000
        self._callback = callback
        self._output = nil
        self._source_id = nil
        self._cancelled = false

        self:__start()
    end,

    properties = {
        timeout = {
            get = function(self) return self._timeout end,
            set = function(self, val)
                self._timeout = val
                if not self._cancelled then
                    self:cancel()
                    self._cancelled = false
                    self:__start()
                end
            end
        },
        callback = {
            get = function(self) return self._callback end,
            set = function(self, val) self._callback = val end
        },
        output = {
            get = function(self) return self._output end
        },
        is_running = {
            get = function(self) return self._source_id ~= nil and not self._cancelled end
        }
    },

    __tick = function(self)
        if self._cancelled then
            self._source_id = nil
            return false
        end
        if self._callback then
            local new_out = self._callback(self, unpack(self._args))
            self._output = new_out
            self:notify("output")
            self:emit("changed", new_out)
        end
        return not self._cancelled
    end,

    __start = function(self)
        self:__tick()

        local ok, lgi = pcall(require, "lgi")
        if ok and lgi.GLib and not self._cancelled then
            local GLib = lgi.GLib
            self._source_id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, self._timeout, function()
                return self:__tick()
            end)
        end
    end,

    bind = function(self, prop_or_transform, transform)
        if type(prop_or_transform) == "function" or prop_or_transform == nil then
            return gobject.Object.bind(self, "output", prop_or_transform)
        end
        return gobject.Object.bind(self, prop_or_transform, transform)
    end,

    cancel = function(self)
        self._cancelled = true
        if self._source_id then
            local ok, lgi = pcall(require, "lgi")
            if ok and lgi.GLib then
                pcall(lgi.GLib.Source.remove, self._source_id)
            end
            self._source_id = nil
        end
        self:notify("is_running")
    end
})

return Poll
