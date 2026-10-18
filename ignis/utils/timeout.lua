local gobject = require("ignis.gobject")
local unpack = table.unpack or unpack

local M = {}

local Timeout = gobject.class(gobject.Object, {
    init = function(self, ms, callback, ...)
        if type(ms) == "table" then
            local opts = ms
            ms = opts.ms or opts.timeout
            callback = opts.callback
            self._args = opts.args or {}
        else
            self._args = { ... }
        end

        self._ms = ms or 0
        self._callback = callback
        self._source_id = nil
        self._cancelled = false

        local ok, lgi = pcall(require, "lgi")
        if ok and lgi.GLib then
            local GLib = lgi.GLib
            self._source_id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, self._ms, function()
                self._source_id = nil
                if not self._cancelled and self._callback then
                    self._callback(unpack(self._args))
                end
                return false
            end)
        else
            if self._callback then
                self._callback(unpack(self._args))
            end
        end
    end,

    properties = {
        ms = { get = function(self) return self._ms end },
        is_active = { get = function(self) return self._source_id ~= nil and not self._cancelled end }
    },

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

local function Debounce(ms, callback)
    local timer = nil
    local last_args = nil

    local debounced = {}

    function debounced:cancel()
        if timer then
            timer:cancel()
            timer = nil
        end
        last_args = nil
    end

    function debounced:flush()
        if timer and last_args then
            local args = last_args
            self:cancel()
            return callback(unpack(args))
        end
    end

    setmetatable(debounced, {
        __call = function(_, ...)
            last_args = { ... }
            if timer then
                timer:cancel()
            end
            timer = Timeout(ms, function()
                timer = nil
                local args = last_args
                last_args = nil
                if args then
                    callback(unpack(args))
                end
            end)
        end
    })

    return debounced
end

local function Throttle(ms, callback)
    local cooling_down = false
    local pending_args = nil

    return function(...)
        if not cooling_down then
            cooling_down = true
            callback(...)
            Timeout(ms, function()
                cooling_down = false
                if pending_args then
                    local args = pending_args
                    pending_args = nil
                    callback(unpack(args))
                end
            end)
        else
            pending_args = { ... }
        end
    end
end

M.Timeout = Timeout
M.Debounce = Debounce
M.Throttle = Throttle

return M
