local gobject = require("ignis.gobject")
local shell = require("ignis.utils.shell")

local OBJECT_MANAGER_XML = [[
<node>
  <interface name="org.freedesktop.DBus.ObjectManager">
    <method name="GetManagedObjects">
      <arg name="object_paths_interfaces_and_properties" type="a{oa{sa{sv}}}" direction="out"/>
    </method>
    <signal name="InterfacesAdded">
      <arg name="object_path" type="o"/>
      <arg name="interfaces_and_properties" type="a{sa{sv}}"/>
    </signal>
    <signal name="InterfacesRemoved">
      <arg name="object_path" type="o"/>
      <arg name="interfaces" type="as"/>
    </signal>
  </interface>
</node>
]]

local ADAPTER1_XML = [[
<node>
  <interface name="org.bluez.Adapter1">
    <method name="StartDiscovery"/>
    <method name="StopDiscovery"/>
    <method name="RemoveDevice">
      <arg name="device" type="o" direction="in"/>
    </method>
    <property name="Address" type="s" access="read"/>
    <property name="Name" type="s" access="read"/>
    <property name="Alias" type="s" access="readwrite"/>
    <property name="Powered" type="b" access="readwrite"/>
    <property name="Discoverable" type="b" access="readwrite"/>
    <property name="Pairable" type="b" access="readwrite"/>
    <property name="Discovering" type="b" access="read"/>
  </interface>
</node>
]]

local DEVICE1_XML = [[
<node>
  <interface name="org.bluez.Device1">
    <method name="Connect"/>
    <method name="Disconnect"/>
    <method name="Pair"/>
    <method name="CancelPairing"/>
    <property name="Address" type="s" access="read"/>
    <property name="Name" type="s" access="read"/>
    <property name="Alias" type="s" access="readwrite"/>
    <property name="Icon" type="s" access="read"/>
    <property name="Paired" type="b" access="read"/>
    <property name="Trusted" type="b" access="readwrite"/>
    <property name="Blocked" type="b" access="readwrite"/>
    <property name="Connected" type="b" access="read"/>
    <property name="RSSI" type="n" access="read"/>
  </interface>
</node>
]]

---@class Ignis.BluetoothDevice : Ignis.Object
local BluetoothDevice = gobject.class(gobject.Object, {
    init = function(self, object_path, proxy, props)
        props = props or {}
        self._object_path = object_path or ""
        self._proxy = proxy
        self._address = props.Address or props.address or ""
        self._name = props.Name or props.name or self._address
        self._alias = props.Alias or props.alias or self._name
        self._connected = props.Connected or props.connected or false
        self._paired = props.Paired or props.paired or false
        self._trusted = props.Trusted or props.trusted or false
        self._blocked = props.Blocked or props.blocked or false
        self._icon_name = props.Icon or props.icon_name or "bluetooth-symbolic"
        self._battery_percentage = props.Percentage or props.battery_percentage or -1
        self._rssi = props.RSSI or props.rssi or 0

        if self._proxy then
            self._proxy:watch_properties(function(_, iface, changed)
                if iface == "org.bluez.Device1" then
                    if changed.Address ~= nil then self._address = changed.Address end
                    if changed.Name ~= nil then self._name = changed.Name end
                    if changed.Alias ~= nil then self._alias = changed.Alias end
                    if changed.Connected ~= nil then self._connected = changed.Connected end
                    if changed.Paired ~= nil then self._paired = changed.Paired end
                    if changed.Trusted ~= nil then self._trusted = changed.Trusted end
                    if changed.Blocked ~= nil then self._blocked = changed.Blocked end
                    if changed.Icon ~= nil then self._icon_name = changed.Icon end
                    if changed.RSSI ~= nil then self._rssi = changed.RSSI end
                    self:notify_all()
                elseif iface == "org.bluez.Battery1" then
                    if changed.Percentage ~= nil then
                        self._battery_percentage = changed.Percentage
                        self:notify("battery_percentage")
                    end
                end
            end)
        end
    end,

    properties = {
        object_path = { get = function(self) return self._object_path end },
        address = { get = function(self) return self._address end },
        name = { get = function(self) return self._name end },
        alias = { get = function(self) return self._alias end },
        connected = { get = function(self) return self._connected end },
        paired = { get = function(self) return self._paired end },
        trusted = {
            get = function(self) return self._trusted end,
            set = function(self, val)
                self._trusted = val and true or false
                if self._proxy then self._proxy.Trusted = self._trusted end
                self:notify("trusted")
            end
        },
        blocked = {
            get = function(self) return self._blocked end,
            set = function(self, val)
                self._blocked = val and true or false
                if self._proxy then self._proxy.Blocked = self._blocked end
                self:notify("blocked")
            end
        },
        icon_name = { get = function(self) return self._icon_name end },
        battery_percentage = { get = function(self) return self._battery_percentage end },
        rssi = { get = function(self) return self._rssi end },
    },

    connect_to = function(self, callback)
        if self._proxy then
            self._proxy:ConnectAsync("", function(_, err)
                if not err then
                    self._connected = true
                    self:notify("connected")
                end
                if callback then callback(err == nil, err) end
            end)
            return
        end
        shell.exec_sh_async("bluetoothctl connect " .. self._address, function(res)
            local ok = (res and res.returncode == 0)
            if ok then
                self._connected = true
                self:notify("connected")
            end
            if callback then callback(ok, res) end
        end)
    end,

    disconnect_from = function(self, callback)
        if self._proxy then
            self._proxy:DisconnectAsync("", function(_, err)
                if not err then
                    self._connected = false
                    self:notify("connected")
                end
                if callback then callback(err == nil, err) end
            end)
            return
        end
        shell.exec_sh_async("bluetoothctl disconnect " .. self._address, function(res)
            local ok = (res and res.returncode == 0)
            if ok then
                self._connected = false
                self:notify("connected")
            end
            if callback then callback(ok, res) end
        end)
    end,

    connect_device = function(self, callback) self:connect_to(callback) end,
    disconnect_device = function(self, callback) self:disconnect_from(callback) end,

    pair = function(self, callback)
        if self._proxy then
            self._proxy:PairAsync("", function(_, err)
                if callback then callback(err == nil, err) end
            end)
        else
            shell.exec_sh_async("bluetoothctl pair " .. self._address, function(res)
                if callback then callback(res and res.returncode == 0, res) end
            end)
        end
    end
})

---@class Ignis.BluetoothService : Ignis.Object
local BluetoothService = gobject.class(gobject.Object, {
    init = function(self)
        self._powered = false
        self._state = "absent"
        self._setup_mode = false
        self._devices = {}
        self._adapter_proxy = nil
        self._obj_mgr = nil

        local ok, dbus_mod = pcall(require, "ignis.dbus")
        local ok_misc, misc = pcall(require, "ignis.utils.misc")
        if ok and ok_misc then
            local ok_bluez = pcall(function()
                self:__setup_bluez(dbus_mod, misc)
            end)
            if ok_bluez and self._obj_mgr then
                return
            end
        end
    end,

    properties = {
        powered = {
            get = function(self) return self._powered end,
            set = function(self, val)
                self._powered = val and true or false
                self._state = self._powered and "on" or "off"
                if self._adapter_proxy then
                    self._adapter_proxy.Powered = self._powered
                else
                    shell.exec_sh_async("bluetoothctl power " .. (self._powered and "on" or "off"))
                end
                self:notify_list("powered", "state")
            end
        },
        state = { get = function(self) return self._state end },
        setup_mode = {
            get = function(self) return self._setup_mode end,
            set = function(self, val)
                self._setup_mode = val and true or false
                if self._adapter_proxy then
                    pcall(function()
                        if self._setup_mode then
                            self._adapter_proxy.Discoverable = true
                            self._adapter_proxy:StartDiscovery("")
                        else
                            self._adapter_proxy:StopDiscovery("")
                            self._adapter_proxy.Discoverable = false
                        end
                    end)
                end
                self:notify("setup_mode")
            end
        },
        devices = {
            get = function(self)
                local list = {}
                for _, d in pairs(self._devices) do table.insert(list, d) end
                return list
            end
        },
        connected_devices = {
            get = function(self)
                local list = {}
                for _, d in pairs(self._devices) do
                    if d.connected then table.insert(list, d) end
                end
                return list
            end
        }
    },

    __setup_bluez = function(self, dbus_mod, misc)
        local obj_info = misc.load_interface_xml(nil, nil, OBJECT_MANAGER_XML)
        local adapter_info = misc.load_interface_xml(nil, nil, ADAPTER1_XML)
        local device_info = misc.load_interface_xml(nil, nil, DEVICE1_XML)

        local mgr = dbus_mod.DBusProxy.new(
            "org.bluez",
            "/",
            "org.freedesktop.DBus.ObjectManager",
            obj_info,
            "system"
        )
        if not mgr or not mgr.has_owner then return end
        self._obj_mgr = mgr

        local function register_object(path, ifaces)
            if not ifaces then return end
            if ifaces["org.bluez.Adapter1"] and not self._adapter_proxy then
                local ok_a, aproxy = pcall(function()
                    return dbus_mod.DBusProxy.new("org.bluez", path, "org.bluez.Adapter1", adapter_info, "system")
                end)
                if ok_a and aproxy then
                    self._adapter_proxy = aproxy
                    self._powered = aproxy.Powered or false
                    self._state = self._powered and "on" or "off"
                    self._setup_mode = aproxy.Discovering or false
                    aproxy:watch_properties(function(_, _, changed)
                        if changed.Powered ~= nil then
                            self._powered = changed.Powered
                            self._state = self._powered and "on" or "off"
                        end
                        if changed.Discovering ~= nil then
                            self._setup_mode = changed.Discovering
                        end
                        self:notify_list("powered", "state", "setup_mode")
                    end)
                end
            end

            if ifaces["org.bluez.Device1"] then
                local dev_props = ifaces["org.bluez.Device1"]
                if ifaces["org.bluez.Battery1"] and ifaces["org.bluez.Battery1"].Percentage then
                    dev_props.Percentage = ifaces["org.bluez.Battery1"].Percentage
                end
                local ok_d, dproxy = pcall(function()
                    return dbus_mod.DBusProxy.new("org.bluez", path, "org.bluez.Device1", device_info, "system")
                end)
                local dev = BluetoothDevice(path, ok_d and dproxy or nil, dev_props)
                dev:connect("notify::connected", function()
                    self:notify("connected_devices")
                end)
                self._devices[path] = dev
                self:notify_list("devices", "connected_devices")
                self:emit("device-added", dev)
            end
        end

        local ok_objs, objects = pcall(function() return mgr:GetManagedObjects("") end)
        if ok_objs and type(objects) == "table" then
            for path, ifaces in pairs(objects) do
                register_object(path, ifaces)
            end
        end

        mgr:signal_subscribe("InterfacesAdded", function(_, params)
            if type(params) == "table" then
                register_object(params[1], params[2])
            end
        end)

        mgr:signal_subscribe("InterfacesRemoved", function(_, params)
            if type(params) == "table" then
                local path = params[1]
                if path and self._devices[path] then
                    local dev = self._devices[path]
                    self._devices[path] = nil
                    dev:emit("removed")
                    self:notify_list("devices", "connected_devices")
                end
            end
        end)
    end
})

local default_instance = nil

function BluetoothService.get_default()
    if not default_instance then
        default_instance = BluetoothService()
    end
    return default_instance
end

return {
    BluetoothService = BluetoothService,
    BluetoothDevice = BluetoothDevice,
    get_default = BluetoothService.get_default
}
