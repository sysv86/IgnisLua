local gobject = require("ignis.gobject")
local unpack = table.unpack or unpack

local ThreadTask = gobject.class(gobject.Object, {
    init = function(self, target, callback, ...)
        if type(target) == "table" then
            local opts = target
            target = opts.target
            callback = opts.callback
            self._args = opts.args or {}
        else
            self._args = { ... }
        end

        self._target = target
        self._callback = callback
        self._source_id = nil
        self._cancelled = false
    end,

    run = function(self)
        self._cancelled = false
        local ok, lgi = pcall(require, "lgi")
        if ok and lgi.GLib then
            local GLib = lgi.GLib
            self._source_id = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, function()
                self._source_id = nil
                if not self._cancelled and self._target then
                    local result = self._target(unpack(self._args))
                    if not self._cancelled then
                        self:emit("finished", result)
                        if self._callback then
                            self._callback(result)
                        end
                    end
                end
                return false
            end)
        else
            if self._target then
                local result = self._target(unpack(self._args))
                self:emit("finished", result)
                if self._callback then
                    self._callback(result)
                end
            end
        end
        return self
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
    end
})

return ThreadTask
