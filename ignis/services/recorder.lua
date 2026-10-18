local gobject = require("ignis.gobject")
local exceptions = require("ignis.exceptions")

---@class Ignis.RecorderConfig : Ignis.Object
local RecorderConfig = gobject.class(gobject.Object, {
    init = function(self, opts)
        opts = opts or {}
        self.source = opts.source or "portal"
        self.path = opts.path or ((os.getenv("HOME") or "/tmp") .. "/Videos/recording_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".mp4")
        self.framerate = opts.framerate or 60
        self.quality = opts.quality or "very_high"
        self.cursor = opts.cursor ~= false
        self.audio_devices = opts.audio_devices or {}
        self.extra_args = opts.extra_args or {}
    end,

    new_from_options = function(opts)
        return RecorderConfig(opts)
    end
})

---@class Ignis.RecorderService : Ignis.Object
local RecorderService = gobject.class(gobject.Object, {
    init = function(self)
        self._active = false
        self._is_paused = false
        self._proc = nil
        self._is_available = false
        self._bin = nil
        self._current_path = nil

        local ok, lgi = pcall(require, "lgi")
        if ok and lgi.GLib and lgi.GLib.find_program_in_path then
            self._bin = lgi.GLib.find_program_in_path("gpu-screen-recorder")
            self._is_available = (self._bin ~= nil)
        end
    end,

    properties = {
        is_available = { get = function(self) return self._is_available end },
        active = { get = function(self) return self._active end },
        is_paused = { get = function(self) return self._is_paused end },
        current_path = { get = function(self) return self._current_path end },
    },

    start_recording = function(self, config)
        if not self._is_available then
            error(exceptions.GpuScreenRecorderNotFoundError())
        end
        if self._active then return end

        config = config or RecorderConfig()
        local lgi = require("lgi")
        local Gio = lgi.Gio

        local parent_dir = config.path:match("^(.*)/[^/]+$")
        if parent_dir and lgi.GLib then
            lgi.GLib.mkdir_with_parents(parent_dir, 493)
        end

        local argv = {
            self._bin,
            "-w", tostring(config.source or "portal"),
            "-f", tostring(config.framerate or 60),
            "-q", tostring(config.quality or "very_high"),
            "-cursor", config.cursor and "yes" or "no",
            "-o", tostring(config.path)
        }
        for _, aud in ipairs(config.audio_devices or {}) do
            table.insert(argv, "-a")
            table.insert(argv, tostring(aud))
        end
        for _, extra in ipairs(config.extra_args or {}) do
            table.insert(argv, tostring(extra))
        end

        local proc, err = Gio.Subprocess.new(
            argv,
            Gio.SubprocessFlags.STDERR_PIPE
        )
        if not proc then
            error("Failed to launch gpu-screen-recorder: " .. tostring(err))
        end

        self._proc = proc
        self._active = true
        self._is_paused = false
        self._current_path = config.path
        self:notify_list("active", "is_paused", "current_path")
        self:emit("recording-started", config.path)

        proc:wait_async(nil, function(p, res)
            pcall(function() p:wait_finish(res) end)
            local saved_path = self._current_path
            self._proc = nil
            self._active = false
            self._is_paused = false
            self._current_path = nil
            self:notify_list("active", "is_paused", "current_path")
            self:emit("recording-stopped", saved_path)
        end)
    end,

    stop_recording = function(self)
        if self._proc then
            pcall(function() self._proc:send_signal(2) end) -- SIGINT saves MP4 container cleanly
        end
    end,

    pause_recording = function(self)
        if self._proc and self._active and not self._is_paused then
            pcall(function() self._proc:send_signal(12) end) -- SIGUSR2 toggles pause in gpu-screen-recorder
            self._is_paused = true
            self:notify("is_paused")
        end
    end,

    continue_recording = function(self)
        if self._proc and self._active and self._is_paused then
            pcall(function() self._proc:send_signal(12) end)
            self._is_paused = false
            self:notify("is_paused")
        end
    end
})

local default_instance = nil

function RecorderService.get_default()
    if not default_instance then
        default_instance = RecorderService()
    end
    return default_instance
end

return {
    RecorderService = RecorderService,
    RecorderConfig = RecorderConfig,
    get_default = RecorderService.get_default
}
