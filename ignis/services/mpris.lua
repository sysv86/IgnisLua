local gobject = require("ignis.gobject")

---@class Ignis.MprisPlayer : Ignis.Object
local MprisPlayer = gobject.class(gobject.Object, {
    init = function(self, bus_name, root_proxy, player_proxy)
        self._bus_name = bus_name
        self._root_proxy = root_proxy
        self._player_proxy = player_proxy
        self._data = {
            playback_status = "Stopped",
            loop_status = "None",
            rate = 1.0,
            shuffle = false,
            metadata = {},
            volume = 1.0,
            position = 0,
            length = 0,
            track_id = "",
            title = "",
            artist = "",
            artists = {},
            album = "",
            art_url = "",
            url = "",
            identity = bus_name:gsub("^org%.mpris%.MediaPlayer2%.", ""),
            desktop_entry = "",
            can_control = true,
            can_go_next = false,
            can_go_previous = false,
            can_play = false,
            can_pause = false,
            can_seek = false,
            can_quit = false,
            can_raise = false,
        }

        if self._root_proxy and self._player_proxy then
            self:__sync()
            self._player_proxy:watch_properties(function(_, _, changed_props)
                if type(changed_props) == "table" and next(changed_props) ~= nil then
                    self:__apply_changed(changed_props)
                else
                    self:__sync()
                end
            end)
            self._player_proxy:signal_subscribe("Seeked", function(_, pos)
                local raw_pos = type(pos) == "table" and pos[1] or pos
                local new_pos = math.floor((tonumber(raw_pos) or 0) / 1000000)
                if self._data.position ~= new_pos then
                    self._data.position = new_pos
                    self:notify("position")
                end
            end)
        end
    end,

    properties = {
        bus_name = { get = function(self) return self._bus_name end },
        playback_status = { get = function(self) return self._data.playback_status end },
        loop_status = {
            get = function(self) return self._data.loop_status end,
            set = function(self, val)
                self._data.loop_status = val
                if self._player_proxy then self._player_proxy.LoopStatus = val end
            end
        },
        rate = {
            get = function(self) return self._data.rate end,
            set = function(self, val)
                self._data.rate = val
                if self._player_proxy then self._player_proxy.Rate = val end
            end
        },
        shuffle = {
            get = function(self) return self._data.shuffle end,
            set = function(self, val)
                self._data.shuffle = val
                if self._player_proxy then self._player_proxy.Shuffle = val end
            end
        },
        metadata = { get = function(self) return self._data.metadata end },
        volume = {
            get = function(self) return self._data.volume end,
            set = function(self, val)
                self._data.volume = val
                if self._player_proxy then self._player_proxy.Volume = val end
            end
        },
        position = {
            get = function(self) return self._data.position end,
            set = function(self, sec) self:set_position(sec) end
        },
        length = { get = function(self) return self._data.length end },
        track_id = { get = function(self) return self._data.track_id end },
        title = { get = function(self) return self._data.title end },
        artist = { get = function(self) return self._data.artist end },
        artists = { get = function(self) return self._data.artists end },
        album = { get = function(self) return self._data.album end },
        art_url = { get = function(self) return self._data.art_url end },
        url = { get = function(self) return self._data.url end },
        identity = { get = function(self) return self._data.identity end },
        desktop_entry = { get = function(self) return self._data.desktop_entry end },
        can_control = { get = function(self) return self._data.can_control end },
        can_go_next = { get = function(self) return self._data.can_go_next end },
        can_go_previous = { get = function(self) return self._data.can_go_previous end },
        can_play = { get = function(self) return self._data.can_play end },
        can_pause = { get = function(self) return self._data.can_pause end },
        can_seek = { get = function(self) return self._data.can_seek end },
        can_quit = { get = function(self) return self._data.can_quit end },
        can_raise = { get = function(self) return self._data.can_raise end },
    },

    __set_field = function(self, key, val, dirty)
        if self._data[key] ~= val then
            self._data[key] = val
            dirty[#dirty + 1] = key
        end
    end,

    __apply_metadata = function(self, meta, dirty)
        meta = meta or {}
        self._data.metadata = meta
        dirty[#dirty + 1] = "metadata"

        self:__set_field("track_id", meta["mpris:trackid"] or "", dirty)
        self:__set_field("length", math.floor((tonumber(meta["mpris:length"]) or 0) / 1000000), dirty)
        self:__set_field("art_url", meta["mpris:artUrl"] or "", dirty)
        self:__set_field("album", meta["xesam:album"] or "", dirty)
        self:__set_field("title", meta["xesam:title"] or "", dirty)
        self:__set_field("url", meta["xesam:url"] or "", dirty)

        local artists = meta["xesam:artist"]
        local artist_str = ""
        local artist_list = {}
        if type(artists) == "table" then
            artist_list = artists
            artist_str = table.concat(artists, ", ")
        elseif type(artists) == "string" then
            artist_list = { artists }
            artist_str = artists
        end
        self._data.artists = artist_list
        self:__set_field("artist", artist_str, dirty)
    end,

    __apply_changed = function(self, changed)
        local dirty = {}
        if changed.PlaybackStatus ~= nil then self:__set_field("playback_status", changed.PlaybackStatus, dirty) end
        if changed.LoopStatus ~= nil then self:__set_field("loop_status", changed.LoopStatus, dirty) end
        if changed.Rate ~= nil then self:__set_field("rate", changed.Rate, dirty) end
        if changed.Shuffle ~= nil then self:__set_field("shuffle", changed.Shuffle == true, dirty) end
        if changed.Volume ~= nil then self:__set_field("volume", changed.Volume, dirty) end
        if changed.Position ~= nil then
            self:__set_field("position", math.floor((tonumber(changed.Position) or 0) / 1000000), dirty)
        end
        if changed.CanControl ~= nil then self:__set_field("can_control", changed.CanControl ~= false, dirty) end
        if changed.CanGoNext ~= nil then self:__set_field("can_go_next", changed.CanGoNext == true, dirty) end
        if changed.CanGoPrevious ~= nil then self:__set_field("can_go_previous", changed.CanGoPrevious == true, dirty) end
        if changed.CanPlay ~= nil then self:__set_field("can_play", changed.CanPlay == true, dirty) end
        if changed.CanPause ~= nil then self:__set_field("can_pause", changed.CanPause == true, dirty) end
        if changed.CanSeek ~= nil then self:__set_field("can_seek", changed.CanSeek == true, dirty) end
        if changed.Metadata ~= nil then
            self:__apply_metadata(changed.Metadata, dirty)
        end

        for i = 1, #dirty do
            self:notify(dirty[i])
        end
    end,

    __sync = function(self)
        local rp = self._root_proxy
        local pp = self._player_proxy
        if not rp or not pp then return end
        local d = self._data
        local dirty = {}

        self:__set_field("identity", rp.Identity or d.identity, dirty)
        self:__set_field("desktop_entry", rp.DesktopEntry or "", dirty)
        self:__set_field("can_quit", rp.CanQuit or false, dirty)
        self:__set_field("can_raise", rp.CanRaise or false, dirty)

        self:__set_field("playback_status", pp.PlaybackStatus or "Stopped", dirty)
        self:__set_field("loop_status", pp.LoopStatus or "None", dirty)
        self:__set_field("rate", pp.Rate or 1.0, dirty)
        self:__set_field("shuffle", pp.Shuffle or false, dirty)
        self:__set_field("volume", pp.Volume or 1.0, dirty)
        self:__set_field("position", math.floor((pp.Position or 0) / 1000000), dirty)
        self:__set_field("can_control", pp.CanControl ~= false, dirty)
        self:__set_field("can_go_next", pp.CanGoNext or false, dirty)
        self:__set_field("can_go_previous", pp.CanGoPrevious or false, dirty)
        self:__set_field("can_play", pp.CanPlay or false, dirty)
        self:__set_field("can_pause", pp.CanPause or false, dirty)
        self:__set_field("can_seek", pp.CanSeek or false, dirty)

        self:__apply_metadata(pp.Metadata or {}, dirty)

        for i = 1, #dirty do
            self:notify(dirty[i])
        end
    end,

    play = function(self)
        if self._player_proxy then pcall(function() self._player_proxy:PlayAsync("") end) end
    end,

    pause = function(self)
        if self._player_proxy then pcall(function() self._player_proxy:PauseAsync("") end) end
    end,

    play_pause = function(self)
        if self._player_proxy then pcall(function() self._player_proxy:PlayPauseAsync("") end) end
    end,

    stop = function(self)
        if self._player_proxy then pcall(function() self._player_proxy:StopAsync("") end) end
    end,

    next = function(self)
        if self._player_proxy then pcall(function() self._player_proxy:NextAsync("") end) end
    end,

    previous = function(self)
        if self._player_proxy then pcall(function() self._player_proxy:PreviousAsync("") end) end
    end,

    seek = function(self, offset_sec)
        if self._player_proxy then
            pcall(function() self._player_proxy:SeekAsync("(x)", math.floor(offset_sec * 1000000)) end)
        end
    end,

    set_position = function(self, pos_sec)
        if self._player_proxy and self._data.track_id ~= "" then
            pcall(function()
                self._player_proxy:SetPositionAsync("(ox)", self._data.track_id, math.floor(pos_sec * 1000000))
            end)
        end
    end,

    quit = function(self)
        if self._root_proxy then pcall(function() self._root_proxy:QuitAsync("") end) end
    end,

    raise = function(self)
        if self._root_proxy then pcall(function() self._root_proxy:RaiseAsync("") end) end
    end
})

---@class Ignis.MprisService : Ignis.Object
local MprisService = gobject.class(gobject.Object, {
    init = function(self)
        self._players = {}
        self._dbus = nil

        local ok, dbus_mod = pcall(require, "ignis.dbus")
        local ok_misc, misc = pcall(require, "ignis.utils.misc")
        if ok and ok_misc then
            local ok_bus, bus = pcall(function()
                return dbus_mod.DBusProxy.new(
                    "org.freedesktop.DBus",
                    "/org/freedesktop/DBus",
                    "org.freedesktop.DBus",
                    misc.load_interface_xml("org.freedesktop.DBus"),
                    "session"
                )
            end)
            if ok_bus and bus then
                self._dbus = bus
                self:__setup(dbus_mod, misc)
            end
        end
    end,

    properties = {
        players = {
            get = function(self)
                local list = {}
                for _, p in pairs(self._players) do
                    table.insert(list, p)
                end
                return list
            end
        },
        active_player = {
            get = function(self)
                local first = nil
                for _, p in pairs(self._players) do
                    if not first then first = p end
                    if p.playback_status == "Playing" then
                        return p
                    end
                end
                return first
            end
        }
    },

    __setup = function(self, dbus_mod, misc)
        local root_info = misc.load_interface_xml("org.mpris.MediaPlayer2")
        local player_info = misc.load_interface_xml("org.mpris.MediaPlayer2.Player")

        local ok_names, names = pcall(function() return self._dbus:ListNames("") end)
        if ok_names and type(names) == "table" then
            for _, name in ipairs(names) do
                if type(name) == "string" and name:find("^org%.mpris%.MediaPlayer2%.") then
                    self:__add_player(name, dbus_mod, root_info, player_info)
                end
            end
        end

        self._dbus:signal_subscribe("NameOwnerChanged", function(_, params)
            if type(params) ~= "table" then return end
            local name, old_owner, new_owner = params[1], params[2], params[3]
            if type(name) == "string" and name:find("^org%.mpris%.MediaPlayer2%.") then
                if new_owner and new_owner ~= "" and (not old_owner or old_owner == "") then
                    self:__add_player(name, dbus_mod, root_info, player_info)
                elseif old_owner and old_owner ~= "" and (not new_owner or new_owner == "") then
                    self:__remove_player(name)
                end
            end
        end)
    end,

    __add_player = function(self, bus_name, dbus_mod, root_info, player_info)
        if self._players[bus_name] then return end
        local ok_r, root_proxy = pcall(function()
            return dbus_mod.DBusProxy.new(
                bus_name,
                "/org/mpris/MediaPlayer2",
                "org.mpris.MediaPlayer2",
                root_info,
                "session"
            )
        end)
        local ok_p, player_proxy = pcall(function()
            return dbus_mod.DBusProxy.new(
                bus_name,
                "/org/mpris/MediaPlayer2",
                "org.mpris.MediaPlayer2.Player",
                player_info,
                "session"
            )
        end)
        if ok_r and ok_p and root_proxy and player_proxy then
            local player = MprisPlayer(bus_name, root_proxy, player_proxy)
            player:connect("notify::playback_status", function()
                self:notify("active_player")
            end)
            self._players[bus_name] = player
            self:notify("players")
            self:notify("active_player")
            self:emit("player-added", player)
        end
    end,

    __remove_player = function(self, bus_name)
        local player = self._players[bus_name]
        if player then
            self._players[bus_name] = nil
            player:emit("closed")
            self:notify("players")
            self:notify("active_player")
            self:emit("player-closed", player)
        end
    end
})

local default_instance = nil

function MprisService.get_default()
    if not default_instance then
        default_instance = MprisService()
    end
    return default_instance
end

return {
    MprisService = MprisService,
    MprisPlayer = MprisPlayer,
    get_default = MprisService.get_default
}
