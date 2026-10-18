local gobject = require("ignis.gobject")
local file_utils = require("ignis.utils.file")
local shell = require("ignis.utils.shell")

---@class Ignis.BacklightDevice : Ignis.Object
local BacklightDevice = gobject.class(gobject.Object, {
    init = function(self, name, sysfs_path, session_proxy)
        self._name = name
        self._path = sysfs_path
        self._session_proxy = session_proxy
        self._brightness = 0
        self._max_brightness = 100

        self:sync()

        local ok_fm, FileMonitor = pcall(require, "ignis.utils.file_monitor")
        if ok_fm and FileMonitor and file_utils.file_exists(sysfs_path .. "/brightness") then
            self._monitor = FileMonitor(sysfs_path .. "/brightness")
            self._monitor:connect("changed", function()
                self:sync()
            end)
        end
    end,

    properties = {
        device_name = { get = function(self) return self._name end },
        name = { get = function(self) return self._name end },
        brightness = {
            get = function(self) return self._brightness end,
            set = function(self, val) self:set_brightness(val) end
        },
        max_brightness = { get = function(self) return self._max_brightness end },
        percentage = {
            get = function(self)
                if self._max_brightness <= 0 then return 0 end
                return math.floor((self._brightness / self._max_brightness) * 100 + 0.5)
            end,
            set = function(self, pct) self:set_percentage(pct) end
        },
        icon_name = {
            get = function(self)
                local p = self.percentage
                if p <= 33 then return "display-brightness-low-symbolic"
                elseif p <= 67 then return "display-brightness-medium-symbolic"
                else return "display-brightness-high-symbolic"
                end
            end
        }
    },

    sync = function(self)
        local ok_max, max_str = pcall(file_utils.read_file, self._path .. "/max_brightness")
        if ok_max and max_str then
            self._max_brightness = tonumber(max_str:match("%d+")) or 100
        end
        local ok_cur, cur_str = pcall(file_utils.read_file, self._path .. "/brightness")
        if ok_cur and cur_str then
            self._brightness = tonumber(cur_str:match("%d+")) or 0
        end
        self:notify_list("brightness", "max_brightness", "percentage", "icon_name")
    end,

    set_brightness = function(self, value)
        self:set_brightness_async(value)
    end,

    set_brightness_async = function(self, value, callback)
        value = math.max(0, math.min(self._max_brightness, math.floor((tonumber(value) or 0) + 0.5)))
        self._brightness = value
        self:notify_list("brightness", "percentage", "icon_name")
        if self._session_proxy then
            self._session_proxy:SetBrightnessAsync("(ssu)", "backlight", self._name, value, function(_, err)
                if err then
                    shell.exec_sh_async(string.format("brightnessctl -d %q set %d 2>/dev/null", self._name, value))
                end
                if callback then callback(err == nil, err) end
            end)
            return
        end
        shell.exec_sh_async(string.format("brightnessctl -d %q set %d 2>/dev/null", self._name, value), function(res)
            if callback then callback(res and res.returncode == 0, res) end
        end)
    end,

    set_percentage = function(self, pct)
        pct = math.max(0, math.min(100, tonumber(pct) or 0))
        local raw = math.floor((pct / 100.0) * self._max_brightness + 0.5)
        self:set_brightness(raw)
    end
})

---@class Ignis.BacklightService : Ignis.Object
local BacklightService = gobject.class(gobject.Object, {
    init = function(self)
        self._devices = {}
        self._session_proxy = nil

        local ok, dbus_mod = pcall(require, "ignis.dbus")
        local ok_misc, misc = pcall(require, "ignis.utils.misc")
        if ok and ok_misc then
            pcall(function()
                local session_path = "/org/freedesktop/login1/session/auto"
                local mgr = dbus_mod.DBusProxy.new(
                    "org.freedesktop.login1",
                    "/org/freedesktop/login1",
                    "org.freedesktop.login1.Manager",
                    misc.load_interface_xml("org.freedesktop.login1.Manager"),
                    "system"
                )
                local xdg_session_id = os.getenv("XDG_SESSION_ID")
                if mgr and xdg_session_id and xdg_session_id ~= "" then
                    local ok_s, path = pcall(function() return mgr:GetSession("(s)", xdg_session_id) end)
                    if ok_s and path then session_path = path end
                end
                self._session_proxy = dbus_mod.DBusProxy.new(
                    "org.freedesktop.login1",
                    session_path,
                    "org.freedesktop.login1.Session",
                    misc.load_interface_xml("org.freedesktop.login1.Session"),
                    "system"
                )
            end)
        end

        self:__scan_devices()
    end,

    properties = {
        available = { get = function(self) return #self._devices > 0 end },
        devices = { get = function(self) return self._devices end },
        device = { get = function(self) return self._devices[1] end },
        brightness = {
            get = function(self) return self._devices[1] and self._devices[1].brightness or 0 end,
            set = function(self, val) if self._devices[1] then self._devices[1].brightness = val end end
        },
        max_brightness = {
            get = function(self) return self._devices[1] and self._devices[1].max_brightness or 100 end
        },
        percentage = {
            get = function(self) return self._devices[1] and self._devices[1].percentage or 0 end,
            set = function(self, pct) if self._devices[1] then self._devices[1].percentage = pct end end
        },
        icon_name = {
            get = function(self) return self._devices[1] and self._devices[1].icon_name or "display-brightness-high-symbolic" end
        }
    },

    __scan_devices = function(self)
        local base = "/sys/class/backlight"
        if not file_utils.is_dir(base) then return end
        local ok, lgi = pcall(require, "lgi")
        if ok and lgi.Gio then
            local Gio = lgi.Gio
            local dir = Gio.File.new_for_path(base)
            local ok_en, enum = pcall(function()
                return dir:enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, nil)
            end)
            if ok_en and enum then
                while true do
                    local info = enum:next_file(nil)
                    if not info then break end
                    local name = info:get_name()
                    local dev = BacklightDevice(name, base .. "/" .. name, self._session_proxy)
                    dev:connect("notify::brightness", function()
                        self:notify_list("brightness", "percentage", "icon_name")
                    end)
                    table.insert(self._devices, dev)
                end
                enum:close(nil)
            end
        end
    end,

    get_device_by_name = function(self, name)
        for _, d in ipairs(self._devices) do
            if d.name == name then return d end
        end
        return nil
    end
})

local default_instance = nil

function BacklightService.get_default()
    if not default_instance then
        default_instance = BacklightService()
    end
    return default_instance
end

return {
    BacklightService = BacklightService,
    BacklightDevice = BacklightDevice,
    get_default = BacklightService.get_default
}
