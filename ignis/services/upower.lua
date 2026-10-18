local gobject = require("ignis.gobject")
local file_utils = require("ignis.utils.file")

local DEVICE_KIND = {
    [0] = "unknown", [1] = "line-power", [2] = "battery", [3] = "ups",
    [4] = "monitor", [5] = "mouse", [6] = "keyboard", [7] = "pda",
    [8] = "phone", [9] = "media-player", [10] = "tablet", [11] = "computer",
    [12] = "gaming-input", [13] = "pen", [14] = "touchpad", [15] = "modem",
    [16] = "network", [17] = "headset", [18] = "speakers", [19] = "headphones",
    [20] = "video", [21] = "other-audio", [22] = "remote-control", [23] = "printer",
    [24] = "scanner", [25] = "camera", [26] = "wearable", [27] = "toy",
    [28] = "bluetooth-generic",
}

local DEVICE_STATE = {
    [0] = "unknown", [1] = "charging", [2] = "discharging",
    [3] = "empty", [4] = "fully-charged", [5] = "pending-charge",
    [6] = "pending-discharge",
}

---@class Ignis.UPowerDevice : Ignis.Object
local UPowerDevice = gobject.class(gobject.Object, {
    init = function(self, object_path, proxy)
        self._object_path = object_path
        self._proxy = proxy
        self._data = {
            native_path = "", vendor = "", model = "", serial = "",
            kind = "battery", power_supply = true, online = false,
            energy = 0.0, energy_empty = 0.0, energy_full = 100.0,
            energy_full_design = 100.0, energy_rate = 0.0, voltage = 0.0,
            charge_cycles = -1, time_to_empty = 0, time_to_full = 0,
            percentage = 100.0, temperature = 0.0, is_present = true,
            state = "unknown", charging = false, charged = false,
            is_rechargeable = true, capacity = 100.0,
            icon_name = "battery-full-symbolic", available = true,
        }

        if self._proxy then
            self:__sync_from_proxy()
            self._watch_id = self._proxy:watch_properties(function()
                self:__sync_from_proxy()
            end)
        end
    end,

    properties = {
        object_path = { get = function(self) return self._object_path end },
        native_path = { get = function(self) return self._data.native_path end },
        vendor = { get = function(self) return self._data.vendor end },
        model = { get = function(self) return self._data.model end },
        serial = { get = function(self) return self._data.serial end },
        kind = { get = function(self) return self._data.kind end },
        power_supply = { get = function(self) return self._data.power_supply end },
        online = { get = function(self) return self._data.online end },
        energy = { get = function(self) return self._data.energy end },
        energy_empty = { get = function(self) return self._data.energy_empty end },
        energy_full = { get = function(self) return self._data.energy_full end },
        energy_full_design = { get = function(self) return self._data.energy_full_design end },
        energy_rate = { get = function(self) return self._data.energy_rate end },
        voltage = { get = function(self) return self._data.voltage end },
        charge_cycles = { get = function(self) return self._data.charge_cycles end },
        time_to_empty = { get = function(self) return self._data.time_to_empty end },
        time_to_full = { get = function(self) return self._data.time_to_full end },
        percentage = { get = function(self) return self._data.percentage end },
        temperature = { get = function(self) return self._data.temperature end },
        is_present = { get = function(self) return self._data.is_present end },
        state = { get = function(self) return self._data.state end },
        charging = { get = function(self) return self._data.charging end },
        charged = { get = function(self) return self._data.charged end },
        is_rechargeable = { get = function(self) return self._data.is_rechargeable end },
        capacity = { get = function(self) return self._data.capacity end },
        icon_name = { get = function(self) return self._data.icon_name end },
        available = { get = function(self) return self._data.available end },
    },

    __sync_from_proxy = function(self)
        local p = self._proxy
        if not p then return end
        local d = self._data
        d.native_path = p.NativePath or ""
        d.vendor = p.Vendor or ""
        d.model = p.Model or ""
        d.serial = p.Serial or ""
        d.kind = DEVICE_KIND[p.Type or 0] or "unknown"
        d.power_supply = p.PowerSupply or false
        d.online = p.Online or false
        d.energy = p.Energy or 0.0
        d.energy_empty = p.EnergyEmpty or 0.0
        d.energy_full = p.EnergyFull or 0.0
        d.energy_full_design = p.EnergyFullDesign or 0.0
        d.energy_rate = p.EnergyRate or 0.0
        d.voltage = p.Voltage or 0.0
        d.charge_cycles = p.ChargeCycles or -1
        d.time_to_empty = p.TimeToEmpty or 0
        d.time_to_full = p.TimeToFull or 0
        d.percentage = p.Percentage or 0.0
        d.temperature = p.Temperature or 0.0
        d.is_present = p.IsPresent ~= false
        local st_num = p.State or 0
        d.state = DEVICE_STATE[st_num] or "unknown"
        d.charging = (st_num == 1 or st_num == 5)
        d.charged = (st_num == 4)
        d.is_rechargeable = p.IsRechargeable or false
        d.capacity = p.Capacity or 100.0
        d.icon_name = p.IconName or "battery-symbolic"
        self:notify_all()
    end,

    refresh = function(self)
        if self._proxy then
            pcall(function() self._proxy:Refresh("") end)
            self:__sync_from_proxy()
        end
    end
})

---@class Ignis.UPowerService : Ignis.Object
local UPowerService = gobject.class(gobject.Object, {
    init = function(self)
        self._devices = {}
        self._batteries = {}
        self._display_device = UPowerDevice("/org/freedesktop/UPower/devices/DisplayDevice", nil)
        self._on_battery = false
        self._lid_is_closed = false
        self._lid_is_present = false
        self._is_available = false
        self._proxy = nil

        local ok, dbus_mod = pcall(require, "ignis.dbus")
        local ok_misc, misc = pcall(require, "ignis.utils.misc")
        if ok and ok_misc then
            local ok_proxy, proxy = pcall(function()
                return dbus_mod.DBusProxy.new(
                    "org.freedesktop.UPower",
                    "/org/freedesktop/UPower",
                    "org.freedesktop.UPower",
                    misc.load_interface_xml("org.freedesktop.UPower"),
                    "system"
                )
            end)
            if ok_proxy and proxy and proxy.has_owner then
                self._proxy = proxy
                self._is_available = true
                self:__setup_dbus(dbus_mod, misc)
                return
            end
        end

        self:__setup_sysfs_fallback()
    end,

    properties = {
        is_available = { get = function(self) return self._is_available end },
        devices = {
            get = function(self)
                local list = {}
                for _, dev in pairs(self._devices) do table.insert(list, dev) end
                return list
            end
        },
        batteries = {
            get = function(self)
                local list = {}
                for _, dev in pairs(self._batteries) do table.insert(list, dev) end
                return list
            end
        },
        display_device = { get = function(self) return self._display_device end },
        on_battery = { get = function(self) return self._on_battery end },
        lid_is_closed = { get = function(self) return self._lid_is_closed end },
        lid_is_present = { get = function(self) return self._lid_is_present end },
    },

    __setup_dbus = function(self, dbus_mod, misc)
        local dev_info = misc.load_interface_xml("org.freedesktop.UPower.Device")

        local ok_disp, disp_path = pcall(function() return self._proxy:GetDisplayDevice("") end)
        if ok_disp and disp_path then
            local ok_dp, dp_proxy = pcall(function()
                return dbus_mod.DBusProxy.new(
                    "org.freedesktop.UPower",
                    disp_path,
                    "org.freedesktop.UPower.Device",
                    dev_info,
                    "system"
                )
            end)
            if ok_dp and dp_proxy then
                self._display_device = UPowerDevice(disp_path, dp_proxy)
            end
        end

        local ok_enum, paths = pcall(function() return self._proxy:EnumerateDevices("") end)
        if ok_enum and type(paths) == "table" then
            for _, p in ipairs(paths) do
                self:__add_device(p, dbus_mod, dev_info)
            end
        end

        self:__sync_props()
        self._proxy:watch_properties(function()
            self:__sync_props()
        end)

        self._proxy:signal_subscribe("DeviceAdded", function(_, params)
            local path = type(params) == "table" and params[1] or params
            if path then
                self:__add_device(path, dbus_mod, dev_info)
            end
        end)

        self._proxy:signal_subscribe("DeviceRemoved", function(_, params)
            local path = type(params) == "table" and params[1] or params
            if path and self._devices[path] then
                local dev = self._devices[path]
                self._devices[path] = nil
                self._batteries[path] = nil
                dev:emit("removed")
                self:notify("devices")
                self:notify("batteries")
                self:emit("device-removed", dev)
            end
        end)
    end,

    __add_device = function(self, object_path, dbus_mod, dev_info)
        local ok_dp, dp_proxy = pcall(function()
            return dbus_mod.DBusProxy.new(
                "org.freedesktop.UPower",
                object_path,
                "org.freedesktop.UPower.Device",
                dev_info,
                "system"
            )
        end)
        if not ok_dp or not dp_proxy then return end
        local dev = UPowerDevice(object_path, dp_proxy)
        self._devices[object_path] = dev
        self:notify("devices")
        self:emit("device-added", dev)
        if dev.kind == "battery" then
            self._batteries[object_path] = dev
            self:notify("batteries")
            self:emit("battery-added", dev)
        end
    end,

    __sync_props = function(self)
        if not self._proxy then return end
        self._on_battery = self._proxy.OnBattery or false
        self._lid_is_closed = self._proxy.LidIsClosed or false
        self._lid_is_present = self._proxy.LidIsPresent or false
        self:notify_list("on_battery", "lid_is_closed", "lid_is_present")
    end,

    __setup_sysfs_fallback = function(self)
        local bat_dir = "/sys/class/power_supply/BAT0"
        if not file_utils.file_exists(bat_dir) then
            bat_dir = "/sys/class/power_supply/BAT1"
        end
        if file_utils.file_exists(bat_dir) then
            self._is_available = true
            local cap = tonumber((pcall(file_utils.read_file, bat_dir .. "/capacity") and file_utils.read_file(bat_dir .. "/capacity")) or "100") or 100
            local status = "unknown"
            local ok_st, raw_st = pcall(file_utils.read_file, bat_dir .. "/status")
            if ok_st and raw_st then
                status = raw_st:gsub("%s+$", ""):lower()
            end
            local d = self._display_device._data
            d.percentage = cap
            d.state = status
            d.charging = (status == "charging")
            d.charged = (status == "full")
            self._devices[bat_dir] = self._display_device
            self._batteries[bat_dir] = self._display_device
        end
    end
})

local default_instance = nil

function UPowerService.get_default()
    if not default_instance then
        default_instance = UPowerService()
    end
    return default_instance
end

return {
    UPowerService = UPowerService,
    UPowerDevice = UPowerDevice,
    get_default = UPowerService.get_default
}
