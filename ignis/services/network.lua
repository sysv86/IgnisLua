local gobject = require("ignis.gobject")
local shell = require("ignis.utils.shell")

local function ssid_bytes_to_string(ssid_bytes)
    if not ssid_bytes then return "" end
    local ok, lgi = pcall(require, "lgi")
    if ok and lgi.NM and lgi.NM.utils_ssid_to_utf8 then
        local data = ssid_bytes.get_data and ssid_bytes:get_data() or ssid_bytes
        local ok_u, str = pcall(lgi.NM.utils_ssid_to_utf8, data)
        if ok_u and str then return str end
    end
    if type(ssid_bytes) == "string" then return ssid_bytes end
    if ssid_bytes.get_data then
        local d = ssid_bytes:get_data()
        if type(d) == "string" then return d end
    end
    return ""
end

local function gobject_key(obj)
    if not obj then return nil end
    if obj.get_path then
        local ok, p = pcall(function() return obj:get_path() end)
        if ok and p and p ~= "" then return p end
    end
    return tostring(obj)
end

---@class Ignis.WifiAccessPoint : Ignis.Object
local WifiAccessPoint = gobject.class(gobject.Object, {
    init = function(self, opts, wifi)
        opts = opts or {}
        self._wifi = wifi
        self._nm_ap = opts.nm_ap
        self._ssid = opts.ssid or ""
        self._bssid = opts.bssid or ""
        self._strength = opts.strength or 0
        self._frequency = opts.frequency or 0
        self._bandwidth = opts.bandwidth or 0
        self._max_bitrate = opts.max_bitrate or 0
        self._security = opts.security or ""
        self._is_connected = opts.is_connected or false
        self._sync_pending = false

        if self._nm_ap then
            self:__sync_nm_ap()
            require("ignis.gi").connect_signal(self._nm_ap, "notify", function()
                if self._sync_pending then return end
                self._sync_pending = true
                require("ignis.utils").Timeout(50, function()
                    self._sync_pending = false
                    self:__sync_nm_ap()
                end)
            end)
        end
    end,

    properties = {
        point = { get = function(self) return self._nm_ap end },
        ssid = { get = function(self) return self._ssid end },
        bssid = { get = function(self) return self._bssid end },
        strength = { get = function(self) return self._strength end },
        frequency = { get = function(self) return self._frequency end },
        bandwidth = { get = function(self) return self._bandwidth end },
        max_bitrate = { get = function(self) return self._max_bitrate end },
        security = { get = function(self) return self._security end },
        requires_password = { get = function(self) return self._security ~= "" and self._security ~= "--" end },
        is_connected = {
            get = function(self) return self._is_connected end,
            set = function(self, val)
                local b = val and true or false
                if self._is_connected ~= b then
                    self._is_connected = b
                    self:notify("is_connected")
                end
            end
        },
        icon_name = {
            get = function(self)
                local s = self._strength or 0
                if s >= 80 then return "network-wireless-signal-excellent-symbolic"
                elseif s >= 60 then return "network-wireless-signal-good-symbolic"
                elseif s >= 40 then return "network-wireless-signal-ok-symbolic"
                elseif s >= 20 then return "network-wireless-signal-weak-symbolic"
                else return "network-wireless-signal-none-symbolic"
                end
            end
        }
    },

    __sync_nm_ap = function(self)
        local ap = self._nm_ap
        if not ap then return end
        self._ssid = ssid_bytes_to_string(ap:get_ssid())
        self._bssid = ap:get_bssid() or ""
        self._strength = ap:get_strength() or 0
        self._frequency = ap:get_frequency() or 0
        self._max_bitrate = ap:get_max_bitrate() or 0
        if ap.get_bandwidth then
            self._bandwidth = ap:get_bandwidth() or 0
        end
        local wpa = ap:get_wpa_flags()
        local rsn = ap:get_rsn_flags()
        if (rsn and rsn ~= 0 and next(rsn or {}) ~= nil) then
            self._security = "WPA2/WPA3"
        elseif (wpa and wpa ~= 0 and next(wpa or {}) ~= nil) then
            self._security = "WPA"
        else
            self._security = ""
        end
        self:notify_all()
    end,

    connect_to = function(self, password, callback)
        if not self._ssid or self._ssid == "" then
            if callback then callback(false, nil) end
            return
        end
        local cmd
        if password and password ~= "" then
            cmd = string.format("nmcli device wifi connect %q password %q", self._ssid, password)
        else
            cmd = string.format("nmcli device wifi connect %q", self._ssid)
        end
        shell.exec_sh_async(cmd, function(res)
            local ok = (res and res.returncode == 0)
            if ok then
                self._is_connected = true
                self:notify("is_connected")
                if self._wifi then self._wifi:sync() end
            end
            if callback then callback(ok, res) end
        end)
    end,

    disconnect_from = function(self, callback)
        if not self._ssid or self._ssid == "" then return end
        shell.exec_sh_async(string.format("nmcli connection down id %q", self._ssid), function(res)
            local ok = (res and res.returncode == 0)
            if ok then
                self._is_connected = false
                self:notify("is_connected")
                if self._wifi then self._wifi:sync() end
            end
            if callback then callback(ok, res) end
        end)
    end
})

---@class Ignis.WifiDevice : Ignis.Object
local WifiDevice = gobject.class(gobject.Object, {
    init = function(self, nm_dev, client, wifi)
        self._nm_dev = nm_dev
        self._client = client
        self._wifi = wifi
        self._access_points = {}
        self._ap_cache = {}
        self._active_ap = WifiAccessPoint({}, wifi)
        self._state = "disconnected"
        self._sync_pending = false

        if self._nm_dev then
            self:__sync()
            local function defer_sync()
                if self._sync_pending then return end
                self._sync_pending = true
                require("ignis.utils").Timeout(50, function()
                    self._sync_pending = false
                    self:__sync()
                end)
            end
            local gi = require("ignis.gi")
            gi.connect_signal(self._nm_dev, "notify", defer_sync)
            gi.connect_signal(self._nm_dev, "access_point_added", defer_sync)
            gi.connect_signal(self._nm_dev, "access_point_removed", defer_sync)
        end
    end,

    properties = {
        access_points = { get = function(self) return self._access_points end },
        ap = { get = function(self) return self._active_ap end },
        state = { get = function(self) return self._state end },
        is_connected = { get = function(self) return self._state == "activated" end },
    },

    __sync = function(self)
        local dev = self._nm_dev
        if not dev then return end
        self._state = tostring(dev:get_state() or "disconnected"):lower()
        local active_nm_ap = dev:get_active_access_point()
        local active_bssid = active_nm_ap and active_nm_ap:get_bssid() or nil

        local raw_aps = dev:get_access_points() or {}
        local list = {}
        local seen_ssids = {}
        local next_cache = {}
        for _, nm_ap in ipairs(raw_aps) do
            local key = gobject_key(nm_ap) or tostring(nm_ap)
            local ap_obj = self._ap_cache[key]
            if not ap_obj then
                ap_obj = WifiAccessPoint({ nm_ap = nm_ap }, self._wifi)
            else
                ap_obj:__sync_nm_ap()
            end
            next_cache[key] = ap_obj
            if active_bssid and ap_obj.bssid == active_bssid then
                ap_obj.is_connected = true
                self._active_ap = ap_obj
            else
                ap_obj.is_connected = false
            end
            if ap_obj.ssid ~= "" and not seen_ssids[ap_obj.ssid] then
                seen_ssids[ap_obj.ssid] = true
                table.insert(list, ap_obj)
            end
        end
        self._ap_cache = next_cache
        table.sort(list, function(a, b)
            if a.is_connected ~= b.is_connected then return a.is_connected end
            return (a.strength or 0) > (b.strength or 0)
        end)
        self._access_points = list
        self:notify_all()
        if self._wifi then self._wifi:notify_all() end
    end,

    scan = function(self, callback)
        if self._nm_dev and self._nm_dev.request_scan_async then
            self._nm_dev:request_scan_async(nil, function(dev, res)
                pcall(function() dev:request_scan_finish(res) end)
                self:__sync()
                if callback then callback(self._access_points) end
            end)
        elseif self._wifi then
            self._wifi:scan(callback)
        end
    end
})

---@class Ignis.Wifi : Ignis.Object
local Wifi = gobject.class(gobject.Object, {
    init = function(self, client)
        self._client = client
        self._devices = {}
        self._enabled = true
        self._is_connected = false
        self._ssid = ""
        self._bssid = ""
        self._strength = 0
        self._frequency = 0
        self._access_points = {}
    end,

    properties = {
        devices = { get = function(self) return self._devices end },
        enabled = {
            get = function(self)
                if self._client and self._client.wireless_get_enabled then
                    return self._client:wireless_get_enabled()
                end
                return self._enabled
            end,
            set = function(self, val)
                self._enabled = val and true or false
                if self._client and self._client.wireless_set_enabled then
                    pcall(function() self._client:wireless_set_enabled(self._enabled) end)
                else
                    shell.exec_sh_async("nmcli radio wifi " .. (self._enabled and "on" or "off"))
                end
                self:notify_list("enabled", "icon_name")
            end
        },
        is_connected = {
            get = function(self)
                for _, d in ipairs(self._devices) do
                    if d.is_connected then return true end
                end
                return self._is_connected
            end
        },
        ssid = {
            get = function(self)
                for _, d in ipairs(self._devices) do
                    if d.is_connected and d.ap then return d.ap.ssid end
                end
                return self._ssid
            end
        },
        bssid = {
            get = function(self)
                for _, d in ipairs(self._devices) do
                    if d.is_connected and d.ap then return d.ap.bssid end
                end
                return self._bssid
            end
        },
        strength = {
            get = function(self)
                for _, d in ipairs(self._devices) do
                    if d.is_connected and d.ap then return d.ap.strength end
                end
                return self._strength
            end
        },
        frequency = {
            get = function(self)
                for _, d in ipairs(self._devices) do
                    if d.is_connected and d.ap then return d.ap.frequency end
                end
                return self._frequency
            end
        },
        access_points = {
            get = function(self)
                if #self._devices > 0 then
                    local all = {}
                    for _, d in ipairs(self._devices) do
                        for _, ap in ipairs(d.access_points or {}) do
                            table.insert(all, ap)
                        end
                    end
                    return all
                end
                return self._access_points
            end
        },
        icon_name = {
            get = function(self)
                if not self.enabled then
                    return "network-wireless-disabled-symbolic"
                elseif not self.is_connected then
                    return "network-wireless-offline-symbolic"
                end
                local s = self.strength or 0
                if s >= 80 then return "network-wireless-signal-excellent-symbolic"
                elseif s >= 60 then return "network-wireless-signal-good-symbolic"
                elseif s >= 40 then return "network-wireless-signal-ok-symbolic"
                elseif s >= 20 then return "network-wireless-signal-weak-symbolic"
                else return "network-wireless-signal-none-symbolic"
                end
            end
        }
    },

    scan = function(self, callback)
        if #self._devices > 0 then
            self._devices[1]:scan(callback)
            return
        end
        shell.exec_sh_async("nmcli -t -f IN-USE,SSID,BSSID,SIGNAL,FREQ,SECURITY device wifi list --rescan auto 2>/dev/null", function(res)
            if res and res.returncode == 0 and res.stdout then
                local aps = {}
                self._is_connected = false
                for line in res.stdout:gmatch("[^\r\n]+") do
                    local in_use, ssid, bssid, sig, freq, sec = line:match("^([^:]*):([^:]*):(.+):(%d+):([^:]*):(.*)$")
                    if ssid and ssid ~= "" then
                        local connected = (in_use == "*")
                        local strength = tonumber(sig) or 0
                        local ap = WifiAccessPoint({
                            ssid = ssid,
                            bssid = (bssid or ""):gsub("\\:", ":"),
                            strength = strength,
                            frequency = tonumber((freq or ""):match("%d+")) or 0,
                            security = sec or "",
                            is_connected = connected
                        }, self)
                        table.insert(aps, ap)
                        if connected then
                            self._is_connected = true
                            self._ssid = ssid
                            self._bssid = ap.bssid
                            self._strength = strength
                            self._frequency = ap.frequency
                        end
                    end
                end
                self._access_points = aps
                self:notify_all()
                if callback then callback(aps) end
            end
        end)
    end,

    sync = function(self)
        self:scan()
    end
})

---@class Ignis.Ethernet : Ignis.Object
local Ethernet = gobject.class(gobject.Object, {
    init = function(self)
        self._devices = {}
        self._is_connected = false
        self._speed = 0
        self._perm_hw_address = ""
    end,

    properties = {
        devices = { get = function(self) return self._devices end },
        is_connected = { get = function(self) return self._is_connected end },
        speed = { get = function(self) return self._speed end },
        perm_hw_address = { get = function(self) return self._perm_hw_address end },
        icon_name = {
            get = function(self)
                return self._is_connected and "network-wired-symbolic" or "network-wired-disconnected-symbolic"
            end
        }
    }
})

---@class Ignis.VpnConnection : Ignis.Object
local VpnConnection = gobject.class(gobject.Object, {
    init = function(self, name, uuid, is_connected, vpn_mgr)
        self._name = name or ""
        self._uuid = uuid or ""
        self._is_connected = is_connected or false
        self._vpn_mgr = vpn_mgr
    end,

    properties = {
        name = { get = function(self) return self._name end },
        uuid = { get = function(self) return self._uuid end },
        is_connected = {
            get = function(self) return self._is_connected end,
            set = function(self, val)
                self._is_connected = val and true or false
                self:notify("is_connected")
            end
        }
    },

    toggle_connection = function(self, callback)
        local action = self._is_connected and "down" or "up"
        local target = (self._uuid ~= "" and self._uuid) or self._name
        shell.exec_sh_async(string.format("nmcli connection %s %q", action, target), function(res)
            local ok = (res and res.returncode == 0)
            if ok then
                self._is_connected = not self._is_connected
                self:notify("is_connected")
                if self._vpn_mgr then self._vpn_mgr:notify_all() end
            end
            if callback then callback(ok, res) end
        end)
    end
})

---@class Ignis.Vpn : Ignis.Object
local Vpn = gobject.class(gobject.Object, {
    init = function(self)
        self._is_connected = false
        self._active_vpn_id = nil
        self._connections = {}
    end,

    properties = {
        is_connected = { get = function(self) return self._is_connected end },
        active_vpn_id = { get = function(self) return self._active_vpn_id end },
        connections = { get = function(self) return self._connections end },
        icon_name = {
            get = function(self)
                return self._is_connected and "network-vpn-symbolic" or "network-vpn-disconnected-symbolic"
            end
        }
    }
})

---@class Ignis.NetworkService : Ignis.Object
local NetworkService = gobject.class(gobject.Object, {
    init = function(self)
        self._client = nil
        self._NM = nil
        self._is_available = false
        self._state = "disconnected"
        self._connectivity = "unknown"
        self._primary_connection_type = ""
        self._wifi_dev_cache = {}
        self._sync_pending = false

        local ok, lgi = pcall(require, "lgi")
        if ok then
            local ok_nm, NM = pcall(lgi.require, "NM", "1.0")
            if ok_nm and NM then
                local ok_c, client = pcall(NM.Client.new, nil)
                if ok_c and client then
                    self._NM = NM
                    self._client = client
                    self._is_available = true
                end
            end
        end

        self._wifi = Wifi(self._client)
        self._ethernet = Ethernet()
        self._vpn = Vpn()

        if self._client then
            self:__setup_nm()
        elseif ok and lgi.GLib and lgi.GLib.find_program_in_path and lgi.GLib.find_program_in_path("nmcli") then
            self._is_available = true
            self:__setup_nmcli_fallback()
        end
    end,

    properties = {
        is_available = { get = function(self) return self._is_available end },
        client = { get = function(self) return self._client end },
        wifi = { get = function(self) return self._wifi end },
        ethernet = { get = function(self) return self._ethernet end },
        vpn = { get = function(self) return self._vpn end },
        state = { get = function(self) return self._state end },
        connectivity = { get = function(self) return self._connectivity end },
        primary_connection_type = { get = function(self) return self._primary_connection_type end },
        is_connected = {
            get = function(self)
                return self._wifi.is_connected or self._ethernet.is_connected
            end
        }
    },

    __setup_nm = function(self)
        local c = self._client
        local NM = self._NM
        if not c or not NM then return end

        local function rebuild_devices()
            local wifi_devs = {}
            local next_wifi_cache = {}
            local eth_devs = {}
            local eth_connected = false
            local eth_speed = 0
            local eth_mac = ""

            for _, dev in ipairs(c:get_devices() or {}) do
                if NM.DeviceWifi and NM.DeviceWifi:is_type_of(dev) then
                    local key = gobject_key(dev) or tostring(dev)
                    local wdev = self._wifi_dev_cache[key]
                    if not wdev then
                        wdev = WifiDevice(dev, c, self._wifi)
                    else
                        wdev:__sync()
                    end
                    next_wifi_cache[key] = wdev
                    table.insert(wifi_devs, wdev)
                elseif NM.DeviceEthernet and NM.DeviceEthernet:is_type_of(dev) then
                    table.insert(eth_devs, dev)
                    if tostring(dev:get_state()):upper() == "ACTIVATED" then
                        eth_connected = true
                        eth_speed = dev:get_speed() or 0
                        eth_mac = dev:get_perm_hw_address() or ""
                    end
                end
            end

            self._wifi_dev_cache = next_wifi_cache
            self._wifi._devices = wifi_devs
            self._ethernet._devices = eth_devs
            self._ethernet._is_connected = eth_connected
            self._ethernet._speed = eth_speed
            self._ethernet._perm_hw_address = eth_mac
        end

        local function sync_state()
            rebuild_devices()
            self._state = tostring(c:get_state() or "disconnected"):lower()
            self._connectivity = tostring(c:get_connectivity() or "unknown"):lower()
            local primary = c:get_primary_connection()
            self._primary_connection_type = primary and (primary:get_connection_type() or "") or ""

            local vpn_conns = {}
            local vpn_active = false
            local active_vpn_id = nil
            local active_uuids = {}

            for _, ac in ipairs(c:get_active_connections() or {}) do
                local ctype = ac:get_connection_type() or ""
                if ac:get_vpn() or ctype == "vpn" or ctype == "wireguard" then
                    vpn_active = true
                    active_vpn_id = ac:get_id()
                    active_uuids[ac:get_uuid() or ""] = true
                end
            end

            for _, rc in ipairs(c:get_connections() or {}) do
                local ctype = rc:get_connection_type() or ""
                if ctype == "vpn" or ctype == "wireguard" then
                    local uuid = rc:get_uuid() or ""
                    table.insert(vpn_conns, VpnConnection(rc:get_id(), uuid, active_uuids[uuid] == true, self._vpn))
                end
            end

            self._vpn._is_connected = vpn_active
            self._vpn._active_vpn_id = active_vpn_id
            self._vpn._connections = vpn_conns

            self._wifi:notify_all()
            self._ethernet:notify_all()
            self._vpn:notify_all()
            self:notify_all()
        end

        sync_state()

        local function defer_sync()
            if self._sync_pending then return end
            self._sync_pending = true
            require("ignis.utils").Timeout(50, function()
                self._sync_pending = false
                sync_state()
            end)
        end
        local gi = require("ignis.gi")
        gi.connect_signal(c, "notify", defer_sync)
        gi.connect_signal(c, "device_added", defer_sync)
        gi.connect_signal(c, "device_removed", defer_sync)
    end,

    __setup_nmcli_fallback = function(self)
        local function sync_nmcli()
            shell.exec_sh_async("nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null", function(res)
                if not res or res.returncode ~= 0 or not res.stdout then return end
                local eth_conn = false
                local wifi_conn = false
                local wifi_ssid = ""
                for line in res.stdout:gmatch("[^\r\n]+") do
                    local dtype, dstate, dconn = line:match("^([^:]+):([^:]+):(.*)$")
                    if dtype == "ethernet" and dstate == "connected" then
                        eth_conn = true
                    elseif dtype == "wifi" and dstate == "connected" then
                        wifi_conn = true
                        wifi_ssid = dconn or ""
                    end
                end
                self._ethernet._is_connected = eth_conn
                self._wifi._is_connected = wifi_conn
                self._wifi._ssid = wifi_ssid
                self._ethernet:notify_all()
                self._wifi:notify_all()
                self:notify_all()
            end)
        end

        sync_nmcli()
        self._wifi:scan()
        local ok, Variable = pcall(require, "ignis.variable")
        if ok and Variable then
            self._nm_watcher = Variable({
                value = "",
                watch = {
                    "nmcli monitor 2>/dev/null",
                    function(line)
                        sync_nmcli()
                        return line
                    end
                }
            })
        end
    end
})

local default_instance = nil

function NetworkService.get_default()
    if not default_instance then
        default_instance = NetworkService()
    end
    return default_instance
end

return {
    NetworkService = NetworkService,
    Wifi = Wifi,
    WifiDevice = WifiDevice,
    WifiAccessPoint = WifiAccessPoint,
    Ethernet = Ethernet,
    Vpn = Vpn,
    VpnConnection = VpnConnection,
    get_default = NetworkService.get_default
}
