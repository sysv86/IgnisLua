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

---@class Ignis.NiriWorkspace : Ignis.Object
local NiriWorkspace = gobject.class(gobject.Object, {
    init = function(self, data, service)
        self._service = service
        self._data = data or {}
    end,

    properties = {
        id = { get = function(self) return self._data.id or 0 end },
        idx = { get = function(self) return self._data.idx or 1 end },
        name = { get = function(self) return self._data.name or tostring(self._data.idx or 1) end },
        output = { get = function(self) return self._data.output or "" end },
        is_active = { get = function(self) return self._data.is_active or false end },
        is_focused = { get = function(self) return self._data.is_focused or false end },
        active_window_id = { get = function(self) return self._data.active_window_id end },
    },

    update = function(self, data)
        local old = self._data or {}
        local d = data or {}
        self._data = d
        if old.id ~= d.id then self:notify("id") end
        if old.idx ~= d.idx then self:notify("idx") end
        if old.name ~= d.name then self:notify("name") end
        if old.output ~= d.output then self:notify("output") end
        if old.is_active ~= d.is_active then self:notify("is_active") end
        if old.is_focused ~= d.is_focused then self:notify("is_focused") end
        if old.active_window_id ~= d.active_window_id then self:notify("active_window_id") end
    end,

    switch_to = function(self)
        if self._service then
            self._service:switch_to_workspace(self.idx)
        end
    end
})

---@class Ignis.NiriWindow : Ignis.Object
local NiriWindow = gobject.class(gobject.Object, {
    init = function(self, data, service)
        self._service = service
        self._data = data or {}
    end,

    properties = {
        id = { get = function(self) return self._data.id or 0 end },
        title = { get = function(self) return self._data.title or "" end },
        app_id = { get = function(self) return self._data.app_id or "" end },
        pid = { get = function(self) return self._data.pid or -1 end },
        workspace_id = { get = function(self) return self._data.workspace_id or -1 end },
        is_focused = { get = function(self) return self._data.is_focused or false end },
        is_floating = { get = function(self) return self._data.is_floating or false end },
    },

    update = function(self, data)
        local old = self._data or {}
        local d = data or {}
        self._data = d
        if old.id ~= d.id then self:notify("id") end
        if old.title ~= d.title then self:notify("title") end
        if old.app_id ~= d.app_id then self:notify("app_id") end
        if old.pid ~= d.pid then self:notify("pid") end
        if old.workspace_id ~= d.workspace_id then self:notify("workspace_id") end
        if old.is_focused ~= d.is_focused then self:notify("is_focused") end
        if old.is_floating ~= d.is_floating then self:notify("is_floating") end
    end,

    focus = function(self)
        if self._service and self._data.id then
            self._service:focus_window(self._data.id)
        end
    end,

    close = function(self)
        if self._service and self._data.id then
            self._service:close_window(self._data.id)
        end
    end
})

---@class Ignis.NiriOutput : Ignis.Object
local NiriOutput = gobject.class(gobject.Object, {
    init = function(self, data)
        self._data = data or {}
    end,

    properties = {
        name = { get = function(self) return self._data.name or "" end },
        make = { get = function(self) return self._data.make or "" end },
        model = { get = function(self) return self._data.model or "" end },
        serial = { get = function(self) return self._data.serial or "" end },
        logical = { get = function(self) return self._data.logical or {} end },
        modes = { get = function(self) return self._data.modes or {} end },
        current_mode = { get = function(self) return self._data.current_mode or 0 end },
        vrr_supported = { get = function(self) return self._data.vrr_supported or false end },
        vrr_enabled = { get = function(self) return self._data.vrr_enabled or false end },
    }
})

---@class Ignis.NiriKeyboardLayouts : Ignis.Object
local NiriKeyboardLayouts = gobject.class(gobject.Object, {
    init = function(self, names, current_idx, service)
        self._service = service
        self._names = names or { "English (US)" }
        self._current_idx = current_idx or 0
    end,

    properties = {
        names = { get = function(self) return self._names end },
        current_idx = { get = function(self) return self._current_idx end },
        current_name = {
            get = function(self)
                return self._names[(self._current_idx or 0) + 1] or self._names[1] or "English (US)"
            end
        }
    },

    switch_layout = function(self, action)
        if self._service then
            local target = action or "Next"
            if type(target) == "number" then
                self._service:send_command({ Action = { SwitchLayout = { action = { Index = target } } } })
            else
                self._service:send_command({ Action = { SwitchLayout = { action = target } } })
            end
        end
    end
})

---@class Ignis.NiriService : Ignis.Object
local NiriService = gobject.class(gobject.Object, {
    init = function(self)
        self._socket_path = os.getenv("NIRI_SOCKET")
        self._is_available = (self._socket_path ~= nil and self._socket_path ~= "" and file_utils.file_exists(self._socket_path))
        self._workspaces = {}
        self._ws_by_id = {}
        self._active_workspace = NiriWorkspace({ id = 1, idx = 1, is_active = true, is_focused = true }, self)
        self._windows = {}
        self._win_by_id = {}
        self._active_window = NiriWindow({}, self)
        self._outputs = {}
        self._active_output = ""
        self._kb_layouts = NiriKeyboardLayouts({ "English (US)" }, 0, self)
        self._overview_opened = false

        if self._is_available then
            self:sync()
            self:__start_event_stream()
        end
    end,

    properties = {
        is_available = { get = function(self) return self._is_available end },
        workspaces = { get = function(self) return self._workspaces end },
        active_workspace = { get = function(self) return self._active_workspace end },
        windows = { get = function(self) return self._windows end },
        active_window = { get = function(self) return self._active_window end },
        outputs = { get = function(self) return self._outputs end },
        active_output = { get = function(self) return self._active_output end },
        keyboard_layouts = { get = function(self) return self._kb_layouts end },
        kb_layout = { get = function(self) return self._kb_layouts.current_name end },
        active_kb_layout = { get = function(self) return format_kb_short(self._kb_layouts.current_name) end },
        overview_opened = { get = function(self) return self._overview_opened end },
    },

    send_command = function(self, cmd)
        if not self._is_available or not self._socket_path then return nil end
        local payload = type(cmd) == "table" and json.encode(cmd) or tostring(cmd)
        if not payload:match("\n$") then
            payload = payload .. "\n"
        end
        local resp = socket.send_socket(self._socket_path, payload)
        if resp and resp ~= "" then
            local ok, decoded = pcall(json.decode, resp)
            if ok then return decoded end
        end
        return resp
    end,

    switch_kb_layout = function(self)
        if self._kb_layouts then
            self._kb_layouts:switch_layout("Next")
        end
    end,

    sync = function(self)
        if not self._is_available then return end
        local ws_resp = self:send_command('"Workspaces"')
        if type(ws_resp) == "table" and ws_resp.Ok and type(ws_resp.Ok.Workspaces) == "table" then
            self:__apply_workspaces(ws_resp.Ok.Workspaces)
        end

        local win_resp = self:send_command('"Windows"')
        if type(win_resp) == "table" and win_resp.Ok and type(win_resp.Ok.Windows) == "table" then
            self:__apply_windows(win_resp.Ok.Windows)
        end

        local out_resp = self:send_command('"Outputs"')
        if type(out_resp) == "table" and out_resp.Ok and type(out_resp.Ok.Outputs) == "table" then
            local outs = {}
            for _, o in pairs(out_resp.Ok.Outputs) do
                table.insert(outs, NiriOutput(o))
            end
            self._outputs = outs
            self:notify("outputs")
        end

        local kb_resp = self:send_command('"KeyboardLayouts"')
        if type(kb_resp) == "table" and kb_resp.Ok and type(kb_resp.Ok.KeyboardLayouts) == "table" then
            local kl = kb_resp.Ok.KeyboardLayouts
            self._kb_layouts = NiriKeyboardLayouts(kl.names, kl.current_idx, self)
            self:notify_list("keyboard_layouts", "kb_layout", "active_kb_layout")
        end
    end,

    __apply_workspaces = function(self, raw_workspaces)
        local old_map = self._ws_by_id or {}
        local new_map = {}
        local list = {}
        for _, w in ipairs(raw_workspaces or {}) do
            local nw = old_map[w.id]
            if nw then
                nw:update(w)
            else
                nw = NiriWorkspace(w, self)
            end
            new_map[w.id] = nw
            table.insert(list, nw)
            if nw.is_focused then
                self._active_workspace = nw
                self._active_output = nw.output or ""
            end
        end
        table.sort(list, function(a, b) return a.idx < b.idx end)
        self._ws_by_id = new_map
        self._workspaces = list
        self:notify_list("workspaces", "active_workspace", "active_output")
    end,

    __apply_windows = function(self, raw_windows)
        local old_map = self._win_by_id or {}
        local new_map = {}
        local list = {}
        local found_focused = false
        for _, w in ipairs(raw_windows or {}) do
            local nw = old_map[w.id]
            if nw then
                nw:update(w)
            else
                nw = NiriWindow(w, self)
            end
            new_map[w.id] = nw
            table.insert(list, nw)
            if nw.is_focused then
                self._active_window = nw
                found_focused = true
            end
        end
        if not found_focused then
            self._active_window = NiriWindow({}, self)
        end
        self._win_by_id = new_map
        self._windows = list
        self:notify_list("windows", "active_window")
    end,

    __start_event_stream = function(self)
        if not self._socket_path then return end
        local conn = socket.connect_unix_socket(self._socket_path)
        if not conn then return end
        local ok, lgi = pcall(require, "lgi")
        if not ok or not lgi.Gio then return end
        local Gio = lgi.Gio
        local GLib = lgi.GLib

        local out_stream = conn:get_output_stream()
        local in_stream = conn:get_input_stream()
        pcall(function()
            out_stream:write_all('"EventStream"\n', nil)
            out_stream:flush(nil)
        end)

        local data_in = Gio.DataInputStream.new(in_stream)
        local function read_next()
            data_in:read_line_async(GLib.PRIORITY_DEFAULT, nil, function(stream, res)
                local ok_line, line = pcall(function() return stream:read_line_finish_utf8(res) end)
                if ok_line and line then
                    local ok_ev, ev = pcall(json.decode, line)
                    if ok_ev and type(ev) == "table" then
                        self:__handle_event(ev)
                    end
                    read_next()
                end
            end)
        end
        read_next()
    end,

    __handle_event = function(self, ev)
        if ev.WorkspacesChanged and ev.WorkspacesChanged.workspaces then
            self:__apply_workspaces(ev.WorkspacesChanged.workspaces)
        elseif ev.WorkspaceActivated then
            local act_id = ev.WorkspaceActivated.id
            local focused = ev.WorkspaceActivated.focused ~= false
            local target = self._ws_by_id[act_id]
            if target then
                local target_output = target.output
                for _, ws in ipairs(self._workspaces) do
                    local d = ws._data
                    if ws.output == target_output then
                        local new_act = (ws.id == act_id)
                        if d.is_active ~= new_act then
                            d.is_active = new_act
                            ws:notify("is_active")
                        end
                    end
                    if focused then
                        local new_foc = (ws.id == act_id)
                        if d.is_focused ~= new_foc then
                            d.is_focused = new_foc
                            ws:notify("is_focused")
                        end
                    end
                end
                if focused then
                    self._active_workspace = target
                    self._active_output = target_output or ""
                    self:notify_list("active_workspace", "active_output")
                end
                self:notify("workspaces")
            else
                self:sync()
            end
        elseif ev.WorkspaceActiveWindowChanged then
            local ws_id = ev.WorkspaceActiveWindowChanged.workspace_id
            local win_id = ev.WorkspaceActiveWindowChanged.active_window_id
            local ws = self._ws_by_id[ws_id]
            if ws and ws._data then
                ws._data.active_window_id = win_id
                ws:notify("active_window_id")
            end
        elseif ev.WindowsChanged and ev.WindowsChanged.windows then
            self:__apply_windows(ev.WindowsChanged.windows)
        elseif ev.WindowOpenedOrChanged and ev.WindowOpenedOrChanged.window then
            local wdata = ev.WindowOpenedOrChanged.window
            local id = wdata.id
            local win = self._win_by_id[id]
            if win then
                win:update(wdata)
            else
                win = NiriWindow(wdata, self)
                self._win_by_id[id] = win
                table.insert(self._windows, win)
            end
            if wdata.is_focused then
                for other_id, other_win in pairs(self._win_by_id) do
                    if other_id ~= id and other_win._data and other_win._data.is_focused then
                        other_win._data.is_focused = false
                        other_win:notify("is_focused")
                    end
                end
                self._active_window = win
                self:notify("active_window")
            elseif self._active_window and self._active_window.id == id then
                self:notify("active_window")
            end
            self:notify("windows")
        elseif ev.WindowClosed and ev.WindowClosed.id then
            local cid = ev.WindowClosed.id
            if self._win_by_id[cid] then
                self._win_by_id[cid] = nil
                local new_list = {}
                for _, w in ipairs(self._windows) do
                    if w.id ~= cid then
                        new_list[#new_list + 1] = w
                    end
                end
                self._windows = new_list
                if self._active_window and self._active_window.id == cid then
                    self._active_window = NiriWindow({}, self)
                    self:notify("active_window")
                end
                self:notify("windows")
            end
        elseif ev.WindowFocusChanged then
            local fid = ev.WindowFocusChanged.id
            local new_active = nil
            for id, win in pairs(self._win_by_id) do
                local foc = (fid ~= nil and id == fid)
                if win._data and win._data.is_focused ~= foc then
                    win._data.is_focused = foc
                    win:notify("is_focused")
                end
                if foc then new_active = win end
            end
            self._active_window = new_active or NiriWindow({}, self)
            self:notify("active_window")
        elseif ev.KeyboardLayoutsChanged and ev.KeyboardLayoutsChanged.keyboard_layouts then
            local kl = ev.KeyboardLayoutsChanged.keyboard_layouts
            self._kb_layouts = NiriKeyboardLayouts(kl.names, kl.current_idx, self)
            self:notify_list("keyboard_layouts", "kb_layout", "active_kb_layout")
        elseif ev.KeyboardLayoutSwitched and ev.KeyboardLayoutSwitched.idx ~= nil then
            self._kb_layouts._current_idx = ev.KeyboardLayoutSwitched.idx
            self._kb_layouts:notify_all()
            self:notify_list("kb_layout", "active_kb_layout")
        elseif ev.OverviewOpenedOrClosed then
            self._overview_opened = ev.OverviewOpenedOrClosed.is_open or false
            self:notify("overview_opened")
        end
    end,

    switch_to_workspace = function(self, idx)
        self:send_command({ Action = { FocusWorkspace = { reference = { Index = idx } } } })
    end,

    focus_window = function(self, id)
        self:send_command({ Action = { FocusWindow = { id = id } } })
    end,

    close_window = function(self, id)
        self:send_command({ Action = { CloseWindow = { id = id } } })
    end,

    toggle_overview = function(self)
        self:send_command({ Action = { ToggleOverview = {} } })
    end
})

local default_instance = nil

function NiriService.get_default()
    if not default_instance then
        default_instance = NiriService()
    end
    return default_instance
end

return {
    NiriService = NiriService,
    NiriWorkspace = NiriWorkspace,
    NiriWindow = NiriWindow,
    NiriOutput = NiriOutput,
    NiriKeyboardLayouts = NiriKeyboardLayouts,
    get_default = NiriService.get_default
}
