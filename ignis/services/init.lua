local M = {}

local service_loaders = {
    applications = function() return require("ignis.services.applications") end,
    audio = function() return require("ignis.services.audio") end,
    backlight = function() return require("ignis.services.backlight") end,
    bluetooth = function() return require("ignis.services.bluetooth") end,
    fetch = function() return require("ignis.services.fetch") end,
    hyprland = function() return require("ignis.services.hyprland") end,
    mpris = function() return require("ignis.services.mpris") end,
    network = function() return require("ignis.services.network") end,
    niri = function() return require("ignis.services.niri") end,
    notifications = function() return require("ignis.services.notifications") end,
    power_profiles = function() return require("ignis.services.power_profiles") end,
    recorder = function() return require("ignis.services.recorder") end,
    system_tray = function() return require("ignis.services.system_tray") end,
    systemd = function() return require("ignis.services.systemd") end,
    upower = function() return require("ignis.services.upower") end,
    wallpaper = function() return require("ignis.services.wallpaper") end,

    ApplicationsService = function() return require("ignis.services.applications").ApplicationsService end,
    AudioService = function() return require("ignis.services.audio").AudioService end,
    BacklightService = function() return require("ignis.services.backlight").BacklightService end,
    BluetoothService = function() return require("ignis.services.bluetooth").BluetoothService end,
    FetchService = function() return require("ignis.services.fetch").FetchService end,
    HyprlandService = function() return require("ignis.services.hyprland").HyprlandService end,
    MprisService = function() return require("ignis.services.mpris").MprisService end,
    NetworkService = function() return require("ignis.services.network").NetworkService end,
    NiriService = function() return require("ignis.services.niri").NiriService end,
    NotificationService = function() return require("ignis.services.notifications").NotificationService end,
    PowerProfilesService = function() return require("ignis.services.power_profiles").PowerProfilesService end,
    RecorderService = function() return require("ignis.services.recorder").RecorderService end,
    RecorderConfig = function() return require("ignis.services.recorder").RecorderConfig end,
    SystemTrayService = function() return require("ignis.services.system_tray").SystemTrayService end,
    SystemdService = function() return require("ignis.services.systemd").SystemdService end,
    UPowerService = function() return require("ignis.services.upower").UPowerService end,
    WallpaperService = function() return require("ignis.services.wallpaper").WallpaperService end,
}

setmetatable(M, {
    __index = function(t, key)
        local loader = service_loaders[key]
        if loader then
            local mod = loader()
            rawset(t, key, mod)
            return mod
        end
        return nil
    end
})

return M
