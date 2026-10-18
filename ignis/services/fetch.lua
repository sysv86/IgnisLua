local gobject = require("ignis.gobject")
local file_utils = require("ignis.utils.file")
local shell = require("ignis.utils.shell")

local function read_first_line(path)
    if not file_utils.file_exists(path) then return "" end
    local ok, content = pcall(file_utils.read_file, path)
    if not ok or not content then return "" end
    return (content:match("^([^\r\n]+)") or ""):gsub("%s+$", "")
end

local function parse_os_release()
    local info = {
        name = "Arch Linux",
        id = "arch",
        pretty_name = "Arch Linux",
        logo = "archlinux-logo",
        version_id = "rolling",
    }
    local path = "/etc/os-release"
    if not file_utils.file_exists(path) then
        path = "/usr/lib/os-release"
    end
    if not file_utils.file_exists(path) then return info end
    local ok, content = pcall(file_utils.read_file, path)
    if not ok or not content then return info end

    for line in content:gmatch("[^\r\n]+") do
        local k, v = line:match("^([%w_]+)=(.*)$")
        if k and v then
            v = v:gsub('^"', ""):gsub('"$', ""):gsub("^'", ""):gsub("'$", "")
            if k == "NAME" then info.name = v
            elseif k == "ID" then info.id = v
            elseif k == "PRETTY_NAME" then info.pretty_name = v
            elseif k == "LOGO" then info.logo = v
            elseif k == "VERSION_ID" then info.version_id = v
            end
        end
    end
    return info
end

local ok_native, native = pcall(require, "ignis.native")

local function count_pacman_packages()
    local pacman_local = "/var/lib/pacman/local"
    if ok_native and native and native.count_dir_entries and native.is_dir(pacman_local) then
        local n = native.count_dir_entries(pacman_local)
        if n and n > 0 then
            return n
        end
    end
    local ok, lgi = pcall(require, "lgi")
    if ok and lgi.Gio and file_utils.is_dir(pacman_local) then
        local Gio = lgi.Gio
        local dir = Gio.File.new_for_path(pacman_local)
        local ok_en, enum = pcall(function()
            return dir:enumerate_children("standard::name,standard::type", Gio.FileQueryInfoFlags.NONE, nil)
        end)
        if ok_en and enum then
            local count = 0
            while true do
                local info = enum:next_file(nil)
                if not info then break end
                if info:get_file_type() == Gio.FileType.DIRECTORY then
                    count = count + 1
                end
            end
            enum:close(nil)
            return count
        end
    end
    if file_utils.file_exists("/usr/bin/pacman") then
        local res = shell.exec_sh("pacman -Qq 2>/dev/null | wc -l")
        if res and res.returncode == 0 then
            return tonumber(res.stdout:match("%d+")) or 0
        end
    end
    return 0
end

local function parse_meminfo()
    local mem = { total = 0, available = 0, used = 0, percent = 0, swap_total = 0, swap_free = 0, swap_used = 0 }
    if not file_utils.file_exists("/proc/meminfo") then return mem end
    local ok, content = pcall(file_utils.read_file, "/proc/meminfo")
    if not ok or not content then return mem end

    local vals = {}
    for line in content:gmatch("[^\r\n]+") do
        local k, v = line:match("^([%w_%(%)]+):%s*(%d+)")
        if k and v then vals[k] = tonumber(v) or 0 end
    end

    mem.total = vals.MemTotal or 0
    mem.available = vals.MemAvailable or vals.MemFree or 0
    mem.used = math.max(0, mem.total - mem.available)
    if mem.total > 0 then mem.percent = math.floor((mem.used / mem.total) * 1000 + 0.5) / 10 end
    mem.swap_total = vals.SwapTotal or 0
    mem.swap_free = vals.SwapFree or 0
    mem.swap_used = math.max(0, mem.swap_total - mem.swap_free)
    return mem
end

local function parse_cpu_info()
    local model, cores = "Unknown CPU", 0
    if file_utils.file_exists("/proc/cpuinfo") then
        local ok, content = pcall(file_utils.read_file, "/proc/cpuinfo")
        if ok and content then
            for line in content:gmatch("[^\r\n]+") do
                local m = line:match("^model name%s*:%s*(.+)$")
                if m and model == "Unknown CPU" then model = m:gsub("%s+$", "") end
                if line:match("^processor%s*:") then cores = cores + 1 end
            end
        end
    end
    return model, math.max(1, cores)
end

local function read_cpu_temp()
    for i = 0, 9 do
        local p = "/sys/class/thermal/thermal_zone" .. tostring(i) .. "/temp"
        if file_utils.file_exists(p) then
            local raw = tonumber(read_first_line(p))
            if raw and raw > 0 then return raw / 1000.0 end
        end
    end
    return 0.0
end

local function parse_uptime()
    if not file_utils.file_exists("/proc/uptime") then
        return { days = 0, hours = 0, minutes = 0, seconds = 0, total_seconds = 0 }
    end
    local line = read_first_line("/proc/uptime")
    local sec = math.floor(tonumber(line:match("^([%d%.]+)")) or 0)
    return {
        days = math.floor(sec / 86400),
        hours = math.floor((sec % 86400) / 3600),
        minutes = math.floor((sec % 3600) / 60),
        seconds = sec % 60,
        total_seconds = sec
    }
end

---@class Ignis.FetchService : Ignis.Object
local FetchService = gobject.class(gobject.Object, {
    init = function(self)
        self._os = parse_os_release()
        self._cpu_model, self._cpu_cores = parse_cpu_info()
        self._hostname = read_first_line("/etc/hostname")
        if self._hostname == "" then self._hostname = os.getenv("HOSTNAME") or "localhost" end
        self._kernel = read_first_line("/proc/sys/kernel/osrelease")
        self._board_vendor = read_first_line("/sys/devices/virtual/dmi/id/board_vendor")
        self._board_name = read_first_line("/sys/devices/virtual/dmi/id/board_name")
        self._bios_version = read_first_line("/sys/devices/virtual/dmi/id/bios_version")
    end,

    properties = {
        os_name = { get = function(self) return self._os.name end },
        os_id = { get = function(self) return self._os.id end },
        os_pretty_name = { get = function(self) return self._os.pretty_name end },
        os_logo = { get = function(self) return self._os.logo end },
        os_version_id = { get = function(self) return self._os.version_id end },
        is_arch = { get = function(self) return self._os.id == "arch" or self._os.id == "cachyos" or self._os.id == "endeavouros" or self._os.id == "garuda" or self._os.id == "manjaro" or file_utils.file_exists("/etc/arch-release") end },
        packages_count = { get = function(_) return count_pacman_packages() end },
        hostname = { get = function(self) return self._hostname end },
        kernel = { get = function(self) return self._kernel end },
        cpu = { get = function(self) return self._cpu_model end },
        cpu_cores = { get = function(self) return self._cpu_cores end },
        cpu_temp = { get = function(_) return read_cpu_temp() end },
        uptime = { get = function(_) return parse_uptime() end },
        mem_info = { get = function(_) return parse_meminfo() end },
        mem_total = { get = function(_) return parse_meminfo().total end },
        mem_used = { get = function(_) return parse_meminfo().used end },
        mem_available = { get = function(_) return parse_meminfo().available end },
        mem_percent = { get = function(_) return parse_meminfo().percent end },
        swap_total = { get = function(_) return parse_meminfo().swap_total end },
        swap_used = { get = function(_) return parse_meminfo().swap_used end },
        current_desktop = { get = function(_) return os.getenv("XDG_CURRENT_DESKTOP") or "" end },
        session_type = { get = function(_) return os.getenv("XDG_SESSION_TYPE") or "" end },
        gtk_theme = {
            get = function(_)
                local ok, lgi = pcall(require, "lgi")
                if not ok or not lgi.Gio or not lgi.Gio.Settings then return "" end
                local settings = lgi.Gio.Settings.new("org.gnome.desktop.interface")
                if not settings then return "" end
                local value = settings:get_string("gtk-theme")
                return value or ""
            end
        },
        icon_theme = {
            get = function(_)
                local ok, lgi = pcall(require, "lgi")
                if not ok or not lgi.Gio or not lgi.Gio.Settings then return "" end
                local settings = lgi.Gio.Settings.new("org.gnome.desktop.interface")
                if not settings then return "" end
                local value = settings:get_string("icon-theme")
                return value or ""
            end
        },
        shell = { get = function(_) return (os.getenv("SHELL") or ""):match("([^/]+)$") or "" end },
        board_vendor = { get = function(self) return self._board_vendor end },
        board_name = { get = function(self) return self._board_name end },
        bios_version = { get = function(self) return self._bios_version end },
    }
})

local default_instance = nil

function FetchService.get_default()
    if not default_instance then
        default_instance = FetchService()
    end
    return default_instance
end

return {
    FetchService = FetchService,
    get_default = FetchService.get_default
}
