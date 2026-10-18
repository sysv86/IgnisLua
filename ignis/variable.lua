local gobject = require("ignis.gobject")
local unpack = table.unpack or unpack

---@class Ignis.Variable : Ignis.Object
---@field value any
local Variable = gobject.class(gobject.Object, {
    init = function(self, value)
        self._poll_id = nil
        self._watch_proc = nil
        self._disposed = false

        if type(value) == "table" and (value.value ~= nil or value.poll ~= nil or value.watch ~= nil) then
            self._value = value.value
            if value.poll then
                self:poll(unpack(value.poll))
            end
            if value.watch then
                self:watch(unpack(value.watch))
            end
        else
            self._value = value
        end
    end,

    properties = {
        value = {
            get = function(self)
                return self._value
            end,
            set = function(self, value)
                self._value = value
            end
        },
        is_polling = {
            get = function(self)
                return self._poll_id ~= nil
            end
        },
        is_watching = {
            get = function(self)
                return self._watch_proc ~= nil
            end
        }
    },

    --- Shorthand getter
    ---@return any
    get = function(self)
        return self.value
    end,

    --- Shorthand setter
    ---@param val any
    set = function(self, val)
        self.value = val
    end,

    --- Supports both `var:bind("value", transform)` and shorthand `var:bind(transform)`
    ---@param prop_or_transform? string|function
    ---@param transform? function
    ---@return Ignis.Binding
    bind = function(self, prop_or_transform, transform)
        if type(prop_or_transform) == "function" or prop_or_transform == nil then
            return gobject.Object.bind(self, "value", prop_or_transform)
        end
        return gobject.Object.bind(self, prop_or_transform, transform)
    end,

    --- Subscribes a callback to value changes and returns an unsubscribe function
    ---@param callback fun(val: any, self: Ignis.Variable)
    ---@return function unsubscribe
    subscribe = function(self, callback)
        local handle = self:connect("notify::value", function(v_self, val)
            callback(val, v_self)
        end)
        return function()
            self:disconnect(handle, "notify::value")
        end
    end,

    --- Periodically polls a function or shell command every `interval_ms` milliseconds
    ---@param interval_ms number
    ---@param cmd_or_fn string|function
    ---@param transform? fun(out: any): any
    ---@return Ignis.Variable
    poll = function(self, interval_ms, cmd_or_fn, transform)
        self:stop_poll()
        local ok, lgi = pcall(require, "lgi")
        if not ok or not lgi.GLib then
            if type(cmd_or_fn) == "function" then
                local res = cmd_or_fn(self)
                self.value = transform and transform(res) or res
            end
            return self
        end

        local GLib = lgi.GLib
        local function tick()
            if self._disposed then
                self._poll_id = nil
                return false
            end
            if type(cmd_or_fn) == "function" then
                local res = cmd_or_fn(self)
                self.value = transform and transform(res) or res
            elseif type(cmd_or_fn) == "string" then
                local shell = require("ignis.utils.shell")
                shell.exec_sh_async(cmd_or_fn, function(task)
                    if not self._disposed and task then
                        local out = (task.stdout or ""):gsub("%s+$", "")
                        self.value = transform and transform(out) or out
                    end
                end)
            end
            return true
        end

        tick()
        self._poll_id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, interval_ms, tick)
        self:notify("is_polling")
        return self
    end,

    --- Watches stdout lines from a long-running shell command
    ---@param cmd string
    ---@param transform? fun(line: string): any
    ---@return Ignis.Variable
    watch = function(self, cmd, transform)
        self:stop_watch()
        local ok, lgi = pcall(require, "lgi")
        if not ok or not lgi.Gio then
            return self
        end
        local Gio = lgi.Gio
        local GLib = lgi.GLib

        local proc, err = Gio.Subprocess.new(
            { "sh", "-c", cmd },
            Gio.SubprocessFlags.STDOUT_PIPE + Gio.SubprocessFlags.STDERR_SILENCE
        )
        if not proc then
            print("[WARN] Variable:watch failed to spawn process: " .. tostring(err))
            return self
        end
        self._watch_proc = proc
        self:notify("is_watching")

        local stdout_pipe = proc:get_stdout_pipe()
        local data_stream = Gio.DataInputStream.new(stdout_pipe)

        local function read_next_line()
            if self._disposed or not self._watch_proc then return end
            data_stream:read_line_async(GLib.PRIORITY_DEFAULT, nil, function(stream, res)
                local line = stream:read_line_finish_utf8(res)
                if line then
                    self.value = transform and transform(line) or line
                    read_next_line()
                else
                    self._watch_proc = nil
                    self:notify("is_watching")
                end
            end)
        end

        read_next_line()
        return self
    end,

    stop_poll = function(self)
        if self._poll_id then
            local ok, lgi = pcall(require, "lgi")
            if ok and lgi.GLib then
                pcall(lgi.GLib.Source.remove, self._poll_id)
            end
            self._poll_id = nil
            self:notify("is_polling")
        end
    end,

    stop_watch = function(self)
        if self._watch_proc then
            pcall(function()
                self._watch_proc:force_exit()
            end)
            self._watch_proc = nil
            self:notify("is_watching")
        end
    end,

    stop = function(self)
        self:stop_poll()
        self:stop_watch()
    end,

    dispose = function(self)
        self._disposed = true
        self:stop()
        gobject.Object.dispose(self)
    end
})

--- Creates a reactive Variable whose value is automatically derived from a list of source Variables/Objects
---@param sources Ignis.Variable[]
---@param transform function
---@return Ignis.Variable
function Variable.derive(sources, transform)
    local function compute()
        local vals = {}
        for i, src in ipairs(sources) do
            vals[i] = src.value
        end
        return transform(unpack(vals))
    end

    local derived = Variable({ value = compute() })
    for _, src in ipairs(sources) do
        src:connect("notify::value", function()
            derived.value = compute()
        end)
    end
    return derived
end

return Variable
