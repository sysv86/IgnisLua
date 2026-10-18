local gobject = require("ignis.gobject")

---@class Ignis.SystemdUnit : Ignis.Object
local SystemdUnit = gobject.class(gobject.Object, {
    init = function(self, name, object_path, proxy, mgr_proxy)
        self._name = name
        self._object_path = object_path
        self._proxy = proxy
        self._mgr_proxy = mgr_proxy
        self._active_state = "inactive"
        self._sub_state = "dead"
        self._load_state = "loaded"
        self._unit_file_state = "disabled"
        self._description = ""

        if self._proxy then
            self:__sync()
            self._proxy:watch_properties(function()
                self:__sync()
            end)
        end
    end,

    properties = {
        name = { get = function(self) return self._name end },
        object_path = { get = function(self) return self._object_path end },
        active_state = { get = function(self) return self._active_state end },
        sub_state = { get = function(self) return self._sub_state end },
        load_state = { get = function(self) return self._load_state end },
        unit_file_state = { get = function(self) return self._unit_file_state end },
        description = { get = function(self) return self._description end },
        is_active = { get = function(self) return self._active_state == "active" end },
        is_failed = { get = function(self) return self._active_state == "failed" end },
    },

    __sync = function(self)
        local p = self._proxy
        if not p then return end
        self._active_state = p.ActiveState or "inactive"
        self._sub_state = p.SubState or "dead"
        self._load_state = p.LoadState or "loaded"
        self._unit_file_state = p.UnitFileState or "disabled"
        self._description = p.Description or ""
        self:notify_all()
    end,

    start = function(self, mode)
        if self._proxy then
            pcall(function() self._proxy:Start("(s)", mode or "replace") end)
            self:__sync()
        end
    end,

    stop = function(self, mode)
        if self._proxy then
            pcall(function() self._proxy:Stop("(s)", mode or "replace") end)
            self:__sync()
        end
    end,

    restart = function(self, mode)
        if self._proxy then
            pcall(function() self._proxy:Restart("(s)", mode or "replace") end)
            self:__sync()
        end
    end,

    reload = function(self, mode)
        if self._proxy then
            pcall(function() self._proxy:Reload("(s)", mode or "replace") end)
            self:__sync()
        end
    end,

    enable = function(self, runtime, force)
        if self._mgr_proxy then
            pcall(function()
                self._mgr_proxy:EnableUnitFiles("(asbb)", { self._name }, runtime or false, force ~= false)
            end)
            self:__sync()
        end
    end,

    disable = function(self, runtime)
        if self._mgr_proxy then
            pcall(function()
                self._mgr_proxy:DisableUnitFiles("(asb)", { self._name }, runtime or false)
            end)
            self:__sync()
        end
    end
})

---@class Ignis.SystemdService : Ignis.Object
local SystemdService = gobject.class(gobject.Object, {
    init = function(self, bus_type)
        self._bus_type = bus_type or "session"
        self._proxy = nil
        self._unit_info = nil
        self._dbus_mod = nil
        self._is_available = false

        local ok, dbus_mod = pcall(require, "ignis.dbus")
        local ok_misc, misc = pcall(require, "ignis.utils.misc")
        if ok and ok_misc then
            self._dbus_mod = dbus_mod
            self._unit_info = misc.load_interface_xml("org.freedesktop.systemd1.Unit")
            local mgr_info = misc.load_interface_xml("org.freedesktop.systemd1.Manager")
            pcall(function()
                self._proxy = dbus_mod.DBusProxy.new(
                    "org.freedesktop.systemd1",
                    "/org/freedesktop/systemd1",
                    "org.freedesktop.systemd1.Manager",
                    mgr_info,
                    self._bus_type
                )
                if self._proxy and self._proxy.has_owner then
                    self._is_available = true
                    self._proxy:Subscribe("")
                end
            end)
        end
    end,

    properties = {
        is_available = { get = function(self) return self._is_available end },
        bus_type = { get = function(self) return self._bus_type end },
    },

    get_unit = function(self, unit_name)
        if not self._proxy or not self._dbus_mod then
            return SystemdUnit(unit_name, "", nil, nil)
        end
        local ok, obj_path = pcall(function()
            return self._proxy:LoadUnit("(s)", unit_name)
        end)
        if not ok or not obj_path then
            return SystemdUnit(unit_name, "", nil, self._proxy)
        end
        local ok_u, unit_proxy = pcall(function()
            return self._dbus_mod.DBusProxy.new(
                "org.freedesktop.systemd1",
                obj_path,
                "org.freedesktop.systemd1.Unit",
                self._unit_info,
                self._bus_type
            )
        end)
        return SystemdUnit(unit_name, obj_path, ok_u and unit_proxy or nil, self._proxy)
    end,

    list_units = function(self)
        if not self._proxy then return {} end
        local ok, raw_units = pcall(function() return self._proxy:ListUnits("") end)
        if not ok or type(raw_units) ~= "table" then return {} end
        local units = {}
        for _, u in ipairs(raw_units) do
            if type(u) == "table" and u[1] then
                table.insert(units, {
                    name = u[1],
                    description = u[2] or "",
                    load_state = u[3] or "",
                    active_state = u[4] or "",
                    sub_state = u[5] or "",
                    object_path = u[7] or "",
                })
            end
        end
        return units
    end,

    reload_daemon = function(self)
        if self._proxy then
            pcall(function() self._proxy:Reload("") end)
        end
    end
})

local session_instance = nil
local system_instance = nil

function SystemdService.get_default(bus_type)
    bus_type = bus_type or "session"
    if bus_type == "system" then
        if not system_instance then
            system_instance = SystemdService("system")
        end
        return system_instance
    else
        if not session_instance then
            session_instance = SystemdService("session")
        end
        return session_instance
    end
end

return {
    SystemdService = SystemdService,
    SystemdUnit = SystemdUnit,
    get_default = SystemdService.get_default
}
