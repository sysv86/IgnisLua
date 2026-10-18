local gobject = require("ignis.gobject")
local file_utils = require("ignis.utils.file")

---@class Ignis.WallpaperService : Ignis.Object
local WallpaperService = gobject.class(gobject.Object, {
    init = function(self)
        local ignis = package.loaded["ignis"]
        local cache_dir = (ignis and ignis.CACHE_DIR) or ((os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") or "/tmp") .. "/.cache") .. "/ignis")
        self._cache_path = cache_dir .. "/wallpaper_path.txt"
        self._wallpaper = nil
        self._windows = {}

        if file_utils.file_exists(self._cache_path) then
            local ok, saved = pcall(file_utils.read_file, self._cache_path)
            if ok and saved then
                saved = saved:gsub("%s+$", "")
                if file_utils.file_exists(saved) then
                    self._wallpaper = saved
                end
            end
        end
    end,

    properties = {
        wallpaper = {
            get = function(self) return self._wallpaper end,
            set = function(self, path) self:set_wallpaper(path) end
        },
        windows = {
            get = function(self) return self._windows end
        }
    },

    set_wallpaper = function(self, path)
        if not path then return end
        path = file_utils.expand_path(path)
        if not file_utils.file_exists(path) then
            error("Wallpaper file does not exist: " .. tostring(path))
        end

        self._wallpaper = path
        pcall(file_utils.write_file, self._cache_path, path)
        self:__rebuild_windows()
        self:notify_list("wallpaper", "windows")
        self:emit("changed", path)
    end,

    __rebuild_windows = function(self)
        for _, w in ipairs(self._windows) do
            pcall(function() w:destroy() end)
        end
        self._windows = {}

        if not self._wallpaper then return end
        local ok_w, widgets = pcall(require, "ignis.widgets")
        local ok_m, monitor_util = pcall(require, "ignis.utils.monitor")
        if not ok_w or not ok_m then return end

        local ok_n, n_monitors = pcall(monitor_util.get_n_monitors)
        if not ok_n or not n_monitors or n_monitors <= 0 then return end

        for i = 0, n_monitors - 1 do
            local gdkmon = monitor_util.get_monitor(i)
            local geom = gdkmon and gdkmon:get_geometry()
            local w = (geom and geom.width) or 1920
            local h = (geom and geom.height) or 1080
            local ok_win, win = pcall(function()
                return widgets.Window({
                    namespace = "ignis-wallpaper-" .. tostring(i),
                    monitor = i,
                    layer = "background",
                    exclusivity = "ignore",
                    kb_mode = "none",
                    anchor = { "top", "bottom", "left", "right" },
                    child = widgets.Picture({
                        image = self._wallpaper,
                        content_fit = "cover",
                        width = w,
                        height = h,
                    })
                })
            end)
            if ok_win and win then
                table.insert(self._windows, win)
            end
        end
    end
})

local default_instance = nil

function WallpaperService.get_default()
    if not default_instance then
        default_instance = WallpaperService()
    end
    return default_instance
end

return {
    WallpaperService = WallpaperService,
    get_default = WallpaperService.get_default
}
