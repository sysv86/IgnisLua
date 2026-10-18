local gobject = require("ignis.gobject")

local PROFILE_ICONS = {
    ["performance"] = "power-profile-performance-symbolic",
    ["balanced"] = "power-profile-balanced-symbolic",
    ["power-saver"] = "power-profile-power-saver-symbolic",
}

---@class Ignis.PowerProfilesService : Ignis.Object
local PowerProfilesService = gobject.class(gobject.Object, {
    init = function(self)
        self._active_profile = "balanced"
        self._profiles = { "power-saver", "balanced", "performance" }
        self._actions = {}
        self._performance_inhibited = ""
        self._performance_degraded = ""
        self._is_available = false
        self._proxy = nil

        local ok, dbus_mod = pcall(require, "ignis.dbus")
        local ok_misc, misc = pcall(require, "ignis.utils.misc")
        if ok and ok_misc then
            local info = misc.load_interface_xml("org.freedesktop.UPower.PowerProfiles")
            local ok_p, proxy = pcall(function()
                return dbus_mod.DBusProxy.new(
                    "org.freedesktop.UPower.PowerProfiles",
                    "/org/freedesktop/UPower/PowerProfiles",
                    "org.freedesktop.UPower.PowerProfiles",
                    info,
                    "system"
                )
            end)
            if ok_p and proxy and proxy.has_owner then
                self._proxy = proxy
                self._is_available = true
                self:__sync()
                self._proxy:watch_properties(function()
                    self:__sync()
                end)
            end
        end
    end,

    properties = {
        is_available = { get = function(self) return self._is_available end },
        active_profile = {
            get = function(self) return self._active_profile end,
            set = function(self, value)
                self._active_profile = value
                if self._proxy then
                    self._proxy.ActiveProfile = value
                end
                self:notify_list("active_profile", "icon_name")
            end
        },
        profiles = { get = function(self) return self._profiles end },
        actions = { get = function(self) return self._actions end },
        performance_inhibited = { get = function(self) return self._performance_inhibited end },
        performance_degraded = { get = function(self) return self._performance_degraded end },
        icon_name = {
            get = function(self)
                return PROFILE_ICONS[self._active_profile] or "power-profile-balanced-symbolic"
            end
        }
    },

    __sync = function(self)
        if not self._proxy then return end
        self._active_profile = self._proxy.ActiveProfile or "balanced"
        self._performance_inhibited = self._proxy.PerformanceInhibited or ""
        self._performance_degraded = self._proxy.PerformanceDegraded or ""
        self._actions = self._proxy.Actions or {}
        local raw_profiles = self._proxy.Profiles
        if type(raw_profiles) == "table" and #raw_profiles > 0 then
            local list = {}
            for _, p in ipairs(raw_profiles) do
                if type(p) == "table" and p.Profile then
                    table.insert(list, p.Profile)
                elseif type(p) == "string" then
                    table.insert(list, p)
                end
            end
            if #list > 0 then
                self._profiles = list
            end
        end
        self:notify_all()
    end,

    cycle_profile = function(self)
        local list = self._profiles
        if not list or #list == 0 then return end
        local idx = 1
        for i, p in ipairs(list) do
            if p == self._active_profile then
                idx = (i % #list) + 1
                break
            end
        end
        self.active_profile = list[idx]
    end,

    hold_profile = function(self, profile, reason, app_id)
        if not self._proxy then return nil end
        local ok, cookie = pcall(function()
            return self._proxy:HoldProfile("(sss)", profile, reason or "User request", app_id or "com.github.linkfrg.ignis")
        end)
        return ok and cookie or nil
    end,

    release_profile = function(self, cookie)
        if self._proxy and cookie then
            pcall(function() self._proxy:ReleaseProfile("(u)", cookie) end)
        end
    end
})

local default_instance = nil

function PowerProfilesService.get_default()
    if not default_instance then
        default_instance = PowerProfilesService()
    end
    return default_instance
end

return {
    PowerProfilesService = PowerProfilesService,
    get_default = PowerProfilesService.get_default
}
