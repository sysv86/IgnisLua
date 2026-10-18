local gobject = require("ignis.gobject")
local shell = require("ignis.utils.shell")

---@class Ignis.AudioStream : Ignis.Object
---@field id number
---@field name string
---@field description string
---@field application_id string
---@field icon_name string
---@field volume number
---@field is_muted boolean
---@field is_default boolean
local Stream = gobject.class(gobject.Object, {
    init = function(self, gvc_stream, kind, control, service)
        self._gvc_stream = gvc_stream
        self._kind = kind or "speaker"
        self._control = control
        self._service = service
        self._id = (gvc_stream and gvc_stream.get_id and gvc_stream:get_id()) or 0
        self._card_index = (gvc_stream and gvc_stream.get_card_index and gvc_stream:get_card_index()) or -1
        self._name = (gvc_stream and gvc_stream.get_name and gvc_stream:get_name()) or ("default-" .. self._kind)
        self._description = (gvc_stream and gvc_stream.get_description and gvc_stream:get_description()) or ("Default " .. self._kind)
        self._application_id = (gvc_stream and gvc_stream.get_application_id and gvc_stream:get_application_id()) or ""
        self._custom_icon = (gvc_stream and gvc_stream.get_icon_name and gvc_stream:get_icon_name()) or nil
        self._volume = 50
        self._is_muted = false
        self._is_default = false
        self._signal_ids = {}

        if self._gvc_stream then
            self:__sync_gvc()
            if self._gvc_stream.on_notify then
                local id = require("ignis.gi").connect_signal(self._gvc_stream, "notify", function()
                    self:__sync_gvc()
                end)
                table.insert(self._signal_ids, id)
            end
        else
            self:sync()
        end
    end,

    properties = {
        stream = { get = function(self) return self._gvc_stream end },
        id = { get = function(self) return self._id end },
        card_index = { get = function(self) return self._card_index end },
        name = { get = function(self) return self._name end },
        description = { get = function(self) return self._description end },
        application_id = { get = function(self) return self._application_id end },
        volume = {
            get = function(self) return self._volume end,
            set = function(self, val) self:set_volume(val) end
        },
        is_muted = {
            get = function(self) return self._is_muted end,
            set = function(self, val) self:set_is_muted(val) end
        },
        is_default = {
            get = function(self) return self._is_default end,
            set = function(self, val)
                self._is_default = val and true or false
                self:notify("is_default")
            end
        },
        icon_name = {
            get = function(self)
                if self._kind == "app" or self._kind == "recorder" then
                    if self._custom_icon and self._custom_icon ~= "" then
                        return self._custom_icon
                    end
                    return "application-x-executable-symbolic"
                end
                local prefix = (self._kind == "microphone") and "microphone-sensitivity" or "audio-volume"
                if self._is_muted or self._volume <= 0 then
                    return prefix .. "-muted-symbolic"
                elseif self._volume < 33 then
                    return prefix .. "-low-symbolic"
                elseif self._volume < 67 then
                    return prefix .. "-medium-symbolic"
                elseif self._volume <= 100 then
                    return prefix .. "-high-symbolic"
                else
                    return (self._kind == "microphone") and (prefix .. "-high-symbolic") or "audio-volume-overamplified-symbolic"
                end
            end
        }
    },

    __sync_gvc = function(self)
        local s = self._gvc_stream
        if not s or not self._control then return end
        local norm = self._control:get_vol_max_norm()
        if norm and norm > 0 then
            self._volume = math.floor((s:get_volume() / norm) * 100 + 0.5)
        end
        self._is_muted = s:get_is_muted() or false
        self._name = s:get_name() or self._name
        self._description = s:get_description() or self._description
        if s.get_application_id then
            self._application_id = s:get_application_id() or ""
        end
        if s.get_icon_name then
            self._custom_icon = s:get_icon_name()
        end
        self:notify_all()
    end,

    set_volume = function(self, val)
        local max_vol = (self._service and self._service.max_volume) or 150
        val = math.max(0, math.min(max_vol, math.floor((tonumber(val) or 0) + 0.5)))
        self._volume = val
        if self._gvc_stream and self._control then
            local norm = self._control:get_vol_max_norm()
            self._gvc_stream:set_volume(math.floor((val / 100.0) * norm + 0.5))
            self._gvc_stream:push_volume()
        else
            local target = "@DEFAULT_AUDIO_SINK@"
            if self._kind == "microphone" then
                target = "@DEFAULT_AUDIO_SOURCE@"
            elseif self._id and self._id > 0 then
                target = tostring(self._id)
            end
            shell.exec_sh_async(string.format("wpctl set-volume %s %d%% 2>/dev/null || pactl set-sink-volume %s %d%% 2>/dev/null",
                target, val, target == "@DEFAULT_AUDIO_SINK@" and "@DEFAULT_SINK@" or target, val))
        end
        self:notify("volume")
        self:notify("icon_name")
    end,

    adjust_volume = function(self, delta)
        self:set_volume((self._volume or 0) + (tonumber(delta) or 0))
    end,

    set_is_muted = function(self, muted)
        muted = muted and true or false
        self._is_muted = muted
        if self._gvc_stream then
            self._gvc_stream:change_is_muted(muted)
        else
            local target = (self._kind == "microphone") and "@DEFAULT_AUDIO_SOURCE@" or "@DEFAULT_AUDIO_SINK@"
            if self._id and self._id > 0 then
                target = tostring(self._id)
            end
            shell.exec_sh_async(string.format("wpctl set-mute %s %s 2>/dev/null || pactl set-sink-mute %s %s 2>/dev/null",
                target, muted and "1" or "0",
                target == "@DEFAULT_AUDIO_SINK@" and "@DEFAULT_SINK@" or target, muted and "1" or "0"))
        end
        self:notify("is_muted")
        self:notify("icon_name")
    end,

    toggle_mute = function(self)
        self:set_is_muted(not self._is_muted)
    end,

    make_default = function(self)
        if self._gvc_stream and self._control then
            if self._kind == "speaker" then
                pcall(function() self._control:set_default_sink(self._gvc_stream) end)
            elseif self._kind == "microphone" then
                pcall(function() self._control:set_default_source(self._gvc_stream) end)
            end
        elseif self._id and self._id > 0 then
            shell.exec_sh_async("wpctl set-default " .. tostring(self._id))
        end
    end,

    sync = function(self)
        if self._gvc_stream then
            self:__sync_gvc()
            return
        end
        local target = (self._kind == "microphone") and "@DEFAULT_AUDIO_SOURCE@" or "@DEFAULT_AUDIO_SINK@"
        shell.exec_sh_async("wpctl get-volume " .. target .. " 2>/dev/null", function(res)
            if res and res.returncode == 0 and res.stdout and res.stdout ~= "" then
                local num = tonumber(res.stdout:match("Volume:%s*([%d%.]+)"))
                if num then
                    self._volume = math.floor(num * 100 + 0.5)
                end
                self._is_muted = res.stdout:find("[MUTED]", 1, true) ~= nil
                self:notify_list("volume", "is_muted", "icon_name")
            end
        end)
    end
})

---@class Ignis.AudioService : Ignis.Object
local AudioService = gobject.class(gobject.Object, {
    init = function(self)
        self._max_volume = 150
        self._speaker = Stream(nil, "speaker", nil, self)
        self._speaker._is_default = true
        self._microphone = Stream(nil, "microphone", nil, self)
        self._microphone._is_default = true

        self._streams = {}
        self._speakers = {}
        self._microphones = {}
        self._apps = {}
        self._recorders = {}

        self._is_available = false
        self._backend = "none"
        self._control = nil

        local ok, lgi = pcall(require, "lgi")
        if ok then
            pcall(function()
                local GIRepository = lgi.require("GIRepository", "2.0")
                for _, dir in ipairs({ "/usr/lib/ignis-gvc", "/usr/local/lib/ignis-gvc" }) do
                    GIRepository.Repository.prepend_search_path(dir)
                    GIRepository.Repository.prepend_library_path(dir)
                end
            end)

            local ok_gvc, Gvc = pcall(lgi.require, "Gvc", "1.0")
            if ok_gvc and Gvc then
                self._is_available = true
                self._backend = "gvc"
                self:__setup_gvc(Gvc)
                return
            end
        end

        if ok and lgi.GLib and lgi.GLib.find_program_in_path then
            if lgi.GLib.find_program_in_path("wpctl") or lgi.GLib.find_program_in_path("pactl") then
                self._is_available = true
                self._backend = "cli"
                self:__setup_cli_watcher()
            end
        end
    end,

    properties = {
        is_available = { get = function(self) return self._is_available end },
        backend = { get = function(self) return self._backend end },
        control = { get = function(self) return self._control end },
        max_volume = {
            get = function(self) return self._max_volume end,
            set = function(self, val) self._max_volume = tonumber(val) or 150 end
        },
        speaker = {
            get = function(self) return self._speaker end,
            set = function(self, stream)
                if stream and stream.make_default then stream:make_default() end
            end
        },
        microphone = {
            get = function(self) return self._microphone end,
            set = function(self, stream)
                if stream and stream.make_default then stream:make_default() end
            end
        },
        streams = {
            get = function(self)
                local list = {}
                for _, s in pairs(self._streams) do table.insert(list, s) end
                return list
            end
        },
        speakers = {
            get = function(self)
                local list = {}
                for _, s in pairs(self._speakers) do table.insert(list, s) end
                if #list == 0 then return { self._speaker } end
                return list
            end
        },
        microphones = {
            get = function(self)
                local list = {}
                for _, s in pairs(self._microphones) do table.insert(list, s) end
                if #list == 0 then return { self._microphone } end
                return list
            end
        },
        apps = {
            get = function(self)
                local list = {}
                for _, s in pairs(self._apps) do table.insert(list, s) end
                return list
            end
        },
        recorders = {
            get = function(self)
                local list = {}
                for _, s in pairs(self._recorders) do table.insert(list, s) end
                return list
            end
        },
    },

    __classify_gvc_stream = function(_, Gvc, gvc_stream)
        if Gvc.MixerSink and Gvc.MixerSink:is_type_of(gvc_stream) then
            return "speaker"
        elseif Gvc.MixerSource and Gvc.MixerSource:is_type_of(gvc_stream) then
            return "microphone"
        elseif Gvc.MixerSinkInput and Gvc.MixerSinkInput:is_type_of(gvc_stream) then
            return "app"
        elseif Gvc.MixerSourceOutput and Gvc.MixerSourceOutput:is_type_of(gvc_stream) then
            return "recorder"
        end
        local type_name = tostring(gvc_stream._type and gvc_stream._type.name or "")
        if type_name:find("SinkInput") then return "app"
        elseif type_name:find("SourceOutput") then return "recorder"
        elseif type_name:find("Sink") then return "speaker"
        elseif type_name:find("Source") then return "microphone"
        end
        return "stream"
    end,

    __setup_gvc = function(self, Gvc)
        local ctrl = Gvc.MixerControl.new("IgnisLua Audio Control")
        self._control = ctrl

        ctrl.on_stream_added = function(_, id)
            local gvc_stream = ctrl:lookup_stream_id(id)
            if not gvc_stream then return end
            local kind = self:__classify_gvc_stream(Gvc, gvc_stream)
            local stream = Stream(gvc_stream, kind, ctrl, self)
            self._streams[id] = stream
            self:notify("streams")

            if kind == "speaker" then
                self._speakers[id] = stream
                self:notify("speakers")
                self:emit("speaker-added", stream)
            elseif kind == "microphone" then
                self._microphones[id] = stream
                self:notify("microphones")
                self:emit("microphone-added", stream)
            elseif kind == "app" then
                self._apps[id] = stream
                self:notify("apps")
                self:emit("app-added", stream)
            elseif kind == "recorder" then
                self._recorders[id] = stream
                self:notify("recorders")
                self:emit("recorder-added", stream)
            end
        end

        ctrl.on_stream_removed = function(_, id)
            local stream = self._streams[id]
            if not stream then return end
            self._streams[id] = nil
            self._speakers[id] = nil
            self._microphones[id] = nil
            self._apps[id] = nil
            self._recorders[id] = nil
            stream:emit("removed")
            self:notify_list("streams", "speakers", "microphones", "apps", "recorders")
        end

        ctrl.on_default_sink_changed = function(_, id)
            for _, s in pairs(self._speakers) do
                s.is_default = (s.id == id)
            end
            local stream = self._speakers[id]
            if not stream then
                local gvc_s = ctrl:lookup_stream_id(id)
                if gvc_s then
                    stream = Stream(gvc_s, "speaker", ctrl, self)
                    stream.is_default = true
                    self._speakers[id] = stream
                    self._streams[id] = stream
                end
            end
            if stream then
                self._speaker = stream
                self:notify("speaker")
            end
        end

        ctrl.on_default_source_changed = function(_, id)
            for _, s in pairs(self._microphones) do
                s.is_default = (s.id == id)
            end
            local stream = self._microphones[id]
            if not stream then
                local gvc_s = ctrl:lookup_stream_id(id)
                if gvc_s then
                    stream = Stream(gvc_s, "microphone", ctrl, self)
                    stream.is_default = true
                    self._microphones[id] = stream
                    self._streams[id] = stream
                end
            end
            if stream then
                self._microphone = stream
                self:notify("microphone")
            end
        end

        ctrl:open()
    end,

    __setup_cli_watcher = function(self)
        self._speaker:sync()
        self._microphone:sync()
        local ok, Variable = pcall(require, "ignis.variable")
        if ok and Variable then
            self._pactl_watcher = Variable({
                value = "",
                watch = {
                    "pactl subscribe 2>/dev/null",
                    function(line)
                        if line:find("sink", 1, true) or line:find("server", 1, true) then
                            self._speaker:sync()
                        end
                        if line:find("source", 1, true) or line:find("server", 1, true) then
                            self._microphone:sync()
                        end
                        return line
                    end
                }
            })
        end
    end
})

local default_instance = nil

function AudioService.get_default()
    if not default_instance then
        default_instance = AudioService()
    end
    return default_instance
end

return {
    AudioService = AudioService,
    Stream = Stream,
    get_default = AudioService.get_default
}
