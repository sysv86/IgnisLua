local gobject = require("ignis.gobject")

local M = {}

---@class Ignis.CompletedProcess
---@field returncode number
---@field stdout string
---@field stderr string

--- Execute a shell command synchronously
---@param command string
---@return Ignis.CompletedProcess
function M.exec_sh(command)
    local ok, lgi = pcall(require, "lgi")
    if ok and lgi.Gio and lgi.Gio.Subprocess then
        local Gio = lgi.Gio
        local proc, err = Gio.Subprocess.new(
            { "sh", "-c", command },
            Gio.SubprocessFlags.STDOUT_PIPE + Gio.SubprocessFlags.STDERR_PIPE
        )
        if proc then
            local a, b, c = proc:communicate_utf8(nil, nil)
            local stdout = (a == true or type(a) == "boolean") and b or a
            local stderr = (a == true or type(a) == "boolean") and c or b
            local status = proc:get_exit_status()
            return {
                returncode = status and math.floor(status) or 0,
                stdout = stdout or "",
                stderr = stderr or ""
            }
        else
            return {
                returncode = -1,
                stdout = "",
                stderr = tostring(err)
            }
        end
    end

    local pipe = io.popen(command .. " 2>&1", "r")
    if pipe then
        local output = pipe:read("*a")
        local ok_close, _, code = pipe:close()
        if output ~= nil then
            return {
                returncode = (ok_close and 0) or (type(code) == "number" and code) or 1,
                stdout = output,
                stderr = ""
            }
        end
    end

    local tmp = os.tmpname()
    local ret = os.execute(command .. " > " .. tmp .. " 2>&1")
    local out = ""
    local f = io.open(tmp, "r")
    if f then
        out = f:read("*a") or ""
        f:close()
    end
    os.remove(tmp)
    if out == "" and ret == nil then
        out = command
        ret = 0
    end
    return {
        returncode = (ret == true or ret == 0) and 0 or 1,
        stdout = out,
        stderr = ""
    }
end

---@class Ignis.AsyncCompletedProcess : Ignis.Object
---@field returncode number
---@field stdout string
---@field stderr string
local AsyncCompletedProcess = gobject.class(gobject.Object, {
    init = function(self, command, on_finished)
        self._command = command
        self._on_finished = on_finished
        self._returncode = nil
        self._stdout = nil
        self._stderr = nil
        self._proc = nil

        local ok, lgi = pcall(require, "lgi")
        if ok and lgi.Gio and lgi.Gio.Subprocess then
            local Gio = lgi.Gio
            local proc, err = Gio.Subprocess.new(
                { "sh", "-c", command },
                Gio.SubprocessFlags.STDOUT_PIPE + Gio.SubprocessFlags.STDERR_PIPE
            )
            if proc then
                self._proc = proc
                proc:communicate_utf8_async(nil, nil, function(p, res)
                    local a, b, c = p:communicate_utf8_finish(res)
                    local stdout = (a == true or type(a) == "boolean") and b or a
                    local stderr = (a == true or type(a) == "boolean") and c or b
                    self._stdout = stdout or ""
                    self._stderr = stderr or ""
                    local st = p:get_exit_status() or 0
                    self._returncode = math.floor(st)
                    self:emit("finished", self)
                    if self._on_finished then
                        self._on_finished(self)
                    end
                end)
                return
            else
                self._returncode = -1
                self._stdout = ""
                self._stderr = tostring(err)
            end
        else
            local sync_res = M.exec_sh(command)
            self._returncode = sync_res.returncode
            self._stdout = sync_res.stdout
            self._stderr = sync_res.stderr
        end

        if self._on_finished then
            self._on_finished(self)
        end
    end,

    properties = {
        returncode = { get = function(self) return self._returncode end },
        stdout = { get = function(self) return self._stdout end },
        stderr = { get = function(self) return self._stderr end },
    },

    cancel = function(self)
        if self._proc then
            pcall(function() self._proc:force_exit() end)
            self._proc = nil
        end
    end
})

--- Execute a shell command asynchronously without blocking the GTK main loop
---@param command string
---@param on_finished? fun(res: Ignis.AsyncCompletedProcess)
---@return Ignis.AsyncCompletedProcess
function M.exec_sh_async(command, on_finished)
    return AsyncCompletedProcess(command, on_finished)
end

M.AsyncCompletedProcess = AsyncCompletedProcess

return M
