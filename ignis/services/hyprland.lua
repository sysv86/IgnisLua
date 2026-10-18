local gobject = require("ignis.gobject")
local json = require("ignis.utils.json")
local socket = require("ignis.utils.socket")
local file_utils = require("ignis.utils.file")

local function format_kb_short(name)
    if not name or name == "" then return "EN" end
    local lower = name:lower()
    if lower:find("russian") or lower == "ru" then return "RU" end
    if lower:find("english") or lower == "us" or lower == "en" then return "EN" end
    if lower:find("kazakh") or lower == "kz" then return "KZ" end
    if lower:find("ukrainian") or lower == "ua" then return "UA" end
    if lower:find("german") or lower == "de" then return "DE" end
    if lower:find("french") or lower == "fr" then return "FR" end
    return name:sub(1, 2):upper()
end

---@class Ignis.HyprlandWorkspace : Ignis.Object
local HyprlandWorkspace = gobject.class(gobject.Object, {
    init = function(self, data, service)
        self._service = service
        self._data = data or {}
    end,

    properties = {
        id = { get = function(self) return self._data.id or 1 end },
        name = { get = function(self) return self._data.name or tostring(self._data.id or 1) end },
        monitor = { get = function(self) return self._data.monitor or "" end },
        monitor_id = { get = function(self) return self._data.monitorID or 0 end },
        windows = { get = function(self) return self._data.windows or 0 end },
        has_fullscreen = { get = function(self) return self._data.hasfullscreen or false end },
        last_window = { get = function(self) return self._data.lastwindow or "" end },
        last_window_title = { get = function(self) return self._data.lastwindowtitle or "" end },
    },

    update = function(self, data)
        local old = self._data or {}
        local d = data or {}
        self._data = d
        if old.id ~= d.id then self:notify("id") end
        if old.name ~= d.name then self:notify("name") end
        if old.monitor ~= d.monitor then self:notify("monitor") end
        if old.monitorID ~= d.monitorID then self:notify("monitor_id") end
        if old.windows ~= d.windows then self:notify("windows") end
        if old.hasfullscreen ~= d.hasfullscreen then self:notify("has_fullscreen") end
        if old.lastwindow ~= d.lastwindow then self:notify("last_window") end
        if old.lastwindowtitle ~= d.lastwindowtitle then self:notify("last_window_title") end
    end,

    switch_to = function(self)
        if self._service and self._data.id then
            self._service:switch_to_workspace(self._data.id)
        end
    end
})

---@class Ignis.HyprlandWindow : Ignis.Object
local HyprlandWindow = gobject.class(gobject.Object, {
    init = function(self, data, service)
        self._service = service
        self._data = data or {}
    end,

    properties = {
        address = { get = function(self) return self._data.address or "" end },
        mapped = { get = function(self) return self._data.mapped or false end },
        hidden = { get = function(self) return self._data.hidden or false end },
        at = { get = function(self) return self._data.at or { 0, 0 } end },
        size = { get = function(self) return self._data.size or { 0, 0 } end },
        workspace_id = { get = function(self) return self._data.workspace and self._data.workspace.id or -1 end },
        workspace_name = { get = function(self) return self._data.workspace and self._data.workspace.name or "" end },
        floating = { get = function(self) return self._data.floating or false end },
        pseudo = { get = function(self) return self._data.pseudo or false end },
        monitor = { get = function(self) return self._data.monitor or -1 end },
        class = { get = function(self) return self._data.class or "" end },
        class_name = { get = function(self) return self._data.class or "" end },
        title = { get = function(self) return self._data.title or "" end },
        initial_class = { get = function(self) return self._data.initialClass or "" end },
        initial_title = { get = function(self) return self._data.initialTitle or "" end },
        pid = { get = function(self) return self._data.pid or -1 end },
        xwayland = { get = function(self) return self._data.xwayland or false end },
        pinned = { get = function(self) return self._data.pinned or false end },
        fullscreen = { get = function(self) return self._data.fullscreen or 0 end },
        fullscreen_client = { get = function(self) return self._data.fullscreenClient or 0 end },
        grouped = { get = function(self) return self._data.grouped or {} end },
        tags = { get = function(self) return self._data.tags or {} end },
        swallowing = { get = function(self) return self._data.swallowing or "" end },
        focus_history_id = { get = function(self) return self._data.focusHistoryID or -1 end },
    },

    update = function(self, data)
        local old = self._data or {}
        local d = data or {}
        self._data = d
        if old.address ~= d.address then self:notify("address") end
        if old.class ~= d.class then
            self:notify("class")
            self:notify("class_name")
        end
        if old.title ~= d.title then self:notify("title") end
        if old.floating ~= d.floating then self:notify("floating") end
        if old.fullscreen ~= d.fullscreen then self:notify("fullscreen") end
        local old_ws = old.workspace and old.workspace.id
        local new_ws = d.workspace and d.workspace.id
        if old_ws ~= new_ws then
            self:notify("workspace_id")
            self:notify("workspace_name")
        end
    end,

    focus = function(self)
        if self._service and self.address ~= "" then
            self._service:send_command("dispatch focuswindow address:" .. self.address)
        end
    end,

    close = function(self)
        if self._service and self.address ~= "" then
            self._service:send_command("dispatch closewindow address:" .. self.address)
        end
    end
})

---@class Ignis.HyprlandMonitor : Ignis.Object
local HyprlandMonitor = gobject.class(gobject.Object, {
    init = function(self, data)
        self._data = data or {}
    end,

    properties = {
        id = { get = function(self) return self._data.id or 0 end },
        name = { get = function(self) return self._data.name or "" end },
        description = { get = function(self) return self._data.description or "" end },
        make = { get = function(self) return self._data.make or "" end },
        model = { get = function(self) return self._data.model or "" end },
        serial = { get = function(self) return self._data.serial or "" end },
        width = { get = function(self) return self._data.width or 0 end },
        height = { get = function(self) return self._data.height or 0 end },
        refresh_rate = { get = function(self) return self._data.refreshRate or 60.0 end },
        x = { get = function(self) return self._data.x or 0 end },
        y = { get = function(self) return self._data.y or 0 end },
        active_workspace_id = { get = function(self) return self._data.activeWorkspace and self._data.activeWorkspace.id or 1 end },
        active_workspace_name = { get = function(self) return self._data.activeWorkspace and self._data.activeWorkspace.name or "1" end },
        special_workspace_id = { get = function(self) return self._data.specialWorkspace and self._data.specialWorkspace.id or 0 end },
        special_workspace_name = { get = function(self) return self._data.specialWorkspace and self._data.specialWorkspace.name or "" end },
        reserved = { get = function(self) return self._data.reserved or { 0, 0, 0, 0 } end },
        scale = { get = function(self) return self._data.scale or 1.0 end },
        transform = { get = function(self) return self._data.transform or 0 end },
        focused = { get = function(self) return self._data.focused or false end },
        dpms_status = { get = function(self) return self._data.dpmsStatus ~= false end },
        vrr = { get = function(self) return self._data.vrr or false end },
        disabled = { get = function(self) return self._data.disabled or false end },
    },

    update = function(self, data)
        self._data = data or {}
        self:notify_all()
    end
})

---@class Ignis.HyprlandKeyboard : Ignis.Object
local HyprlandKeyboard = gobject.class(gobject.Object, {
    init = function(self, data, service)
        self._service = service
        self._data = data or {}
    end,

    properties = {
        address = { get = function(self) return self._data.address or "" end },
        name = { get = function(self) return self._data.name or "" end },
        rules = { get = function(self) return self._data.rules or "" end },
        model = { get = function(self) return self._data.model or "" end },
        layout = { get = function(self) return self._data.layout or "us" end },
        variant = { get = function(self) return self._data.variant or "" end },
        options = { get = function(self) return self._data.options or "" end },
        active_keymap = { get = function(self) return self._data.active_keymap or "English (US)" end },
        caps_lock = { get = function(self) return self._data.capsLock or false end },
        num_lock = { get = function(self) return self._data.numLock or false end },
        main = { get = function(self) return self._data.main or false end },
    },

    switch_layout = function(self, param)
        if self._service and self.name ~= "" then
            self._service:send_command(string.format("switchxkblayout %s %s", self.name, tostring(param or "next")))
        end
    end
})

---@class Ignis.HyprlandService : Ignis.Object
local HyprlandService = gobject.class(gobject.Object, {
    init = function(self)
        self._workspaces = {}
        self._ws_by_id = {}
        self._active_workspace = HyprlandWorkspace({ id = 1, name = "1" }, self)
        self._windows = {}
        self._win_by_addr = {}
        self._active_window = HyprlandWindow({}, self)
        self._monitors = {}
        self._keyboards = {}
        self._main_keyboard = HyprlandKeyboard({ main = true }, self)
        self._kb_layout = "English (US)"
        self._submap = ""
        self._is_available = false
        self._cmd_socket = nil
        self._event_socket = nil

        local sig = os.getenv("HYPRLAND_INSTANCE_SIGNATURE")
        local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. (os.getenv("UID") or "1000"))
        if sig and sig ~= "" then
            local base = runtime_dir .. "/hypr/" .. sig
            if not file_utils.file_exists(base .. "/.socket.sock") then
                base = "/tmp/hypr/" .. sig
            end
            if file_utils.file_exists(base .. "/.socket.sock") then
                self._cmd_socket = base .. "/.socket.sock"
                self._event_socket = base .. "/.socket2.sock"
                self._is_available = true
                self:sync()
                self:__start_event_listener()
            end
        end
    end,

    properties = {
        is_available = { get = function(self) return self._is_available end },
        workspaces = { get = function(self) return self._workspaces end },
        active_workspace = { get = function(self) return self._active_workspace end },
        windows = { get = function(self) return self._windows end },
        active_window = { get = function(self) return self._active_window end },
        monitors = { get = function(self) return self._monitors end },
        keyboards = { get = function(self) return self._keyboards end },
        main_keyboard = { get = function(self) return self._main_keyboard end },
        kb_layout = { get = function(self) return self._kb_layout end },
        active_kb_layout = { get = function(self) return format_kb_short(self._kb_layout) end },
        submap = { get = function(self) return self._submap end },
    },

    send_command = function(self, cmd)
        if not self._is_available or not self._cmd_socket then
            return nil
        end
        return socket.send_socket(self._cmd_socket, cmd)
    end,

    switch_kb_layout = function(self)
        if self._main_keyboard and self._main_keyboard.name ~= "" then
            self._main_keyboard:switch_layout("next")
        else
            self:send_command("switchxkblayout all next")
        end
    end,

    __query_json = function(self, endpoint)
        local raw = self:send_command("j/" .. endpoint)
        if not raw or raw == "" then return nil end
        local ok, parsed = pcall(json.decode, raw)
        return ok and parsed or nil
    end,

    sync = function(self)
        if not self._is_available then return end
        self:__sync_workspaces()
        self:__sync_windows()
        self:__sync_monitors()
        self:__sync_devices()
    end,

    __sync_workspaces = function(self)
        local list = self:__query_json("workspaces")
        if type(list) == "table" then
            table.sort(list, function(a, b) return (a.id or 0) < (b.id or 0) end)
            local old_map = self._ws_by_id or {}
            local new_map = {}
            local ws_objs = {}
            for _, item in ipairs(list) do
                local ws = old_map[item.id]
                if ws then
                    ws:update(item)
                else
                    ws = HyprlandWorkspace(item, self)
                end
                new_map[item.id] = ws
                table.insert(ws_objs, ws)
            end
            self._ws_by_id = new_map
            self._workspaces = ws_objs
            self:notify("workspaces")
        end

        local act = self:__query_json("activeworkspace")
        if type(act) == "table" then
            self._active_workspace:update(act)
            self:notify("active_workspace")
        end
    end,

    __sync_windows = function(self)
        local list = self:__query_json("clients")
        if type(list) == "table" then
            local old_map = self._win_by_addr or {}
            local new_map = {}
            local win_objs = {}
            for _, item in ipairs(list) do
                local addr = item.address or ""
                local win = old_map[addr]
                if win then
                    win:update(item)
                else
                    win = HyprlandWindow(item, self)
                end
                new_map[addr] = win
                table.insert(win_objs, win)
            end
            self._win_by_addr = new_map
            self._windows = win_objs
            self:notify("windows")
        end

        self:__sync_active_window()
    end,

    __sync_active_window = function(self)
        local act = self:__query_json("activewindow")
        if type(act) == "table" then
            self._active_window:update(act)
            if act.address and self._win_by_addr[act.address] then
                self._win_by_addr[act.address]:update(act)
            end
            self:notify("active_window")
        end
    end,

    __sync_monitors = function(self)
        local list = self:__query_json("monitors")
        if type(list) == "table" then
            local mon_objs = {}
            for _, item in ipairs(list) do
                table.insert(mon_objs, HyprlandMonitor(item))
            end
            self._monitors = mon_objs
            self:notify("monitors")
        end
    end,

    __sync_devices = function(self)
        local devs = self:__query_json("devices")
        if type(devs) == "table" and type(devs.keyboards) == "table" then
            local kbs = {}
            for _, kb_data in ipairs(devs.keyboards) do
                local kb_obj = HyprlandKeyboard(kb_data, self)
                table.insert(kbs, kb_obj)
                if kb_data.main then
                    self._main_keyboard = kb_obj
                    self._kb_layout = kb_data.active_keymap or self._kb_layout
                end
            end
            self._keyboards = kbs
            self:notify_list("keyboards", "main_keyboard", "kb_layout", "active_kb_layout")
        end
    end,

    __start_event_listener = function(self)
        if not self._event_socket then return end
        self._listener = socket.listen_socket(self._event_socket, function(line)
            local ev, payload = line:match("^([^>]+)>>(.*)$")
            if not ev then return end
            self:emit("event", ev, payload)

            if ev == "workspace" or ev == "workspacev2" or ev == "createworkspace" or ev == "createworkspacev2"
                or ev == "destroyworkspace" or ev == "destroyworkspacev2" or ev == "moveworkspace"
                or ev == "moveworkspacev2" or ev == "renameworkspace" or ev == "focusedmon" or ev == "activespecial" then
                self:__sync_workspaces()
            elseif ev == "activewindow" or ev == "activewindowv2" or ev == "windowtitle" or ev == "windowtitlev2"
                or ev == "fullscreen" or ev == "changefloatingmode" or ev == "pin" or ev == "urgent" then
                self:__sync_active_window()
            elseif ev == "openwindow" or ev == "closewindow" or ev == "movewindow" or ev == "movewindowv2" then
                self:__sync_windows()
                self:__sync_workspaces()
            elseif ev == "activelayout" then
                local layout = payload:match(",(.+)$")
                if layout then
                    self._kb_layout = layout
                    self:notify_list("kb_layout", "active_kb_layout")
                end
            elseif ev == "submap" then
                self._submap = payload or ""
                self:notify("submap")
            elseif ev == "monitoradded" or ev == "monitoraddedv2" or ev == "monitorremoved" then
                self:__sync_monitors()
            end
        end)
    end,

    switch_to_workspace = function(self, id)
        self:send_command("dispatch workspace " .. tostring(id))
    end,

    get_workspace_by_id = function(self, id)
        if self._ws_by_id and self._ws_by_id[id] then
            return self._ws_by_id[id]
        end
        for _, ws in ipairs(self._workspaces) do
            if ws.id == id then return ws end
        end
        return nil
    end,

    get_window_by_address = function(self, address)
        if self._win_by_addr and self._win_by_addr[address] then
            return self._win_by_addr[address]
        end
        for _, w in ipairs(self._windows) do
            if w.address == address then return w end
        end
        return nil
    end,

    get_windows_on_workspace = function(self, workspace_id)
        local res = {}
        for _, w in ipairs(self._windows) do
            if w.workspace_id == workspace_id then
                table.insert(res, w)
            end
        end
        return res
    end,

    get_monitor_by_name = function(self, name)
        for _, m in ipairs(self._monitors) do
            if m.name == name then return m end
        end
        return nil
    end
})

local default_instance = nil

function HyprlandService.get_default()
    if not default_instance then
        default_instance = HyprlandService()
    end
    return default_instance
end

return {
    HyprlandService = HyprlandService,
    HyprlandWorkspace = HyprlandWorkspace,
    HyprlandWindow = HyprlandWindow,
    HyprlandMonitor = HyprlandMonitor,
    HyprlandKeyboard = HyprlandKeyboard,
    get_default = HyprlandService.get_default
}
