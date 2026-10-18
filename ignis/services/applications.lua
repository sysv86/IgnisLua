local gobject = require("ignis.gobject")
local shell = require("ignis.utils.shell")
local file_utils = require("ignis.utils.file")

---@class Ignis.ApplicationAction : Ignis.Object
local ApplicationAction = gobject.class(gobject.Object, {
    init = function(self, action_id, name, app_info)
        self._action_id = action_id
        self._name = name or action_id
        self._app_info = app_info
    end,

    properties = {
        action = { get = function(self) return self._action_id end },
        name = { get = function(self) return self._name end },
    },

    launch = function(self)
        if self._app_info and self._app_info.launch_action then
            pcall(function()
                self._app_info:launch_action(self._action_id, nil)
            end)
        end
    end
})

---@class Ignis.Application : Ignis.Object
local Application = gobject.class(gobject.Object, {
    init = function(self, app_info, service)
        self._app = app_info
        self._service = service
        self._id = (app_info and app_info.get_id and app_info:get_id()) or ""
        self._name = (app_info and (app_info:get_display_name() or app_info:get_name())) or ""
        self._description = (app_info and app_info:get_description()) or ""
        self._executable = (app_info and app_info:get_executable()) or ""
        self._command_line = (app_info and app_info.get_commandline and app_info:get_commandline()) or self._executable
        self._nodisplay = (app_info and app_info.get_nodisplay and app_info:get_nodisplay()) or false

        local icon_obj = app_info and app_info:get_icon()
        self._icon = (icon_obj and icon_obj.to_string and icon_obj:to_string()) or "application-x-executable-symbolic"

        local kw = {}
        if app_info and app_info.get_keywords then
            local ok_kw, raw_kw = pcall(function() return app_info:get_keywords() end)
            if ok_kw and type(raw_kw) == "table" then kw = raw_kw end
        end
        self._keywords = kw

        local categories = {}
        if app_info and app_info.get_categories then
            local ok_cat, raw_cat = pcall(function() return app_info:get_categories() end)
            if ok_cat and type(raw_cat) == "string" then
                for c in raw_cat:gmatch("([^;]+)") do
                    table.insert(categories, c)
                end
            end
        end
        self._categories = categories

        local is_term = false
        if app_info and app_info.get_boolean then
            local ok_t, val_t = pcall(function() return app_info:get_boolean("Terminal") end)
            if ok_t and val_t then is_term = true end
        end
        self._is_terminal = is_term

        local actions = {}
        if app_info and app_info.list_actions then
            local ok_act, raw_acts = pcall(function() return app_info:list_actions() end)
            if ok_act and type(raw_acts) == "table" then
                for _, act_id in ipairs(raw_acts) do
                    local act_name = act_id
                    if app_info.get_action_name then
                        local ok_n, n = pcall(function() return app_info:get_action_name(act_id) end)
                        if ok_n and n then act_name = n end
                    end
                    table.insert(actions, ApplicationAction(act_id, act_name, app_info))
                end
            end
        end
        self._actions = actions
    end,

    properties = {
        app = { get = function(self) return self._app end },
        id = { get = function(self) return self._id end },
        name = { get = function(self) return self._name end },
        description = { get = function(self) return self._description end },
        icon = { get = function(self) return self._icon end },
        executable = { get = function(self) return self._executable end },
        command_line = { get = function(self) return self._command_line end },
        keywords = { get = function(self) return self._keywords end },
        categories = { get = function(self) return self._categories end },
        is_terminal = { get = function(self) return self._is_terminal end },
        actions = { get = function(self) return self._actions end },
        is_pinned = {
            get = function(self)
                return self._service and self._service:_is_pinned(self._id) or false
            end,
            set = function(self, val)
                if val then self:pin() else self:unpin() end
            end
        }
    },

    launch = function(self, opts)
        opts = opts or {}
        if self._is_terminal and opts.terminal_format then
            local clean_cmd = (self._command_line or self._executable):gsub("%%%a", "")
            local cmd = opts.terminal_format:gsub("%%command%%", clean_cmd)
            shell.exec_sh_async(cmd)
            return
        elseif opts.command_format then
            local clean_cmd = (self._command_line or self._executable):gsub("%%%a", "")
            local cmd = opts.command_format:gsub("%%command%%", clean_cmd)
            shell.exec_sh_async(cmd)
            return
        end
        if self._app then
            pcall(function() self._app:launch(nil, nil) end)
        end
    end,

    pin = function(self)
        if self._service then
            self._service:_pin_app(self._id)
            self:notify("is_pinned")
        end
    end,

    unpin = function(self)
        if self._service then
            self._service:_unpin_app(self._id)
            self:notify("is_pinned")
        end
    end,

    toggle_pin = function(self)
        if self.is_pinned then self:unpin() else self:pin() end
    end
})

---@class Ignis.ApplicationsService : Ignis.Object
local ApplicationsService = gobject.class(gobject.Object, {
    init = function(self)
        local ignis = package.loaded["ignis"]
        local cache_dir = (ignis and ignis.CACHE_DIR) or ((os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") or "/tmp") .. "/.cache") .. "/ignis")
        self._pinned_file = cache_dir .. "/pinned_apps.json"
        self._apps = {}
        self._by_id = {}
        self._pinned_ids = {}
        self._pinned_order = {}

        self:__load_pinned()
        self:reload()

        local ok, lgi = pcall(require, "lgi")
        if ok and lgi.Gio and lgi.Gio.AppInfoMonitor then
            local ok_m, mon = pcall(lgi.Gio.AppInfoMonitor.get)
            if ok_m and mon and mon.on_changed then
                self._monitor = mon
                require("ignis.gi").connect_signal(mon, "changed", function()
                    self:reload()
                end)
            end
        end
    end,

    properties = {
        apps = { get = function(self) return self._apps end },
        pinned = {
            get = function(self)
                local list = {}
                for _, id in ipairs(self._pinned_order) do
                    if self._pinned_ids[id] and self._by_id[id] then
                        table.insert(list, self._by_id[id])
                    end
                end
                return list
            end
        }
    },

    __load_pinned = function(self)
        if file_utils.file_exists(self._pinned_file) then
            local ok, list = pcall(file_utils.read_file, self._pinned_file, true)
            if ok and type(list) == "table" then
                for _, id in ipairs(list) do
                    if type(id) == "string" and not self._pinned_ids[id] then
                        self._pinned_ids[id] = true
                        table.insert(self._pinned_order, id)
                    end
                end
            end
        end
    end,

    __save_pinned = function(self)
        local active = {}
        for _, id in ipairs(self._pinned_order) do
            if self._pinned_ids[id] then
                table.insert(active, id)
            end
        end
        pcall(file_utils.write_file, self._pinned_file, active, true)
    end,

    reload = function(self)
        self._apps = {}
        self._by_id = {}
        local ok, lgi = pcall(require, "lgi")
        if ok and lgi.Gio and lgi.Gio.AppInfo and lgi.Gio.AppInfo.get_all then
            local ok_all, all_apps = pcall(lgi.Gio.AppInfo.get_all)
            if ok_all and type(all_apps) == "table" then
                for _, info in ipairs(all_apps) do
                    if info:should_show() then
                        local app = Application(info, self)
                        table.insert(self._apps, app)
                        if app.id ~= "" then
                            self._by_id[app.id] = app
                        end
                    end
                end
                table.sort(self._apps, function(a, b)
                    return a.name:lower() < b.name:lower()
                end)
            end
        end
        self:notify_list("apps", "pinned")
    end,

    _is_pinned = function(self, id)
        return self._pinned_ids[id] == true
    end,

    _pin_app = function(self, id)
        if not self._pinned_ids[id] then
            self._pinned_ids[id] = true
            table.insert(self._pinned_order, id)
            self:__save_pinned()
            self:notify("pinned")
        end
    end,

    _unpin_app = function(self, id)
        if self._pinned_ids[id] then
            self._pinned_ids[id] = nil
            for i = #self._pinned_order, 1, -1 do
                if self._pinned_order[i] == id then
                    table.remove(self._pinned_order, i)
                end
            end
            self:__save_pinned()
            self:notify("pinned")
        end
    end,

    --- Ranked search across Application objects (prefix match > name substring > keyword > description)
    ---@param apps Ignis.Application[]
    ---@param query string
    ---@return Ignis.Application[]
    search = function(apps, query)
        if not query or query == "" then
            return apps or {}
        end
        local q = query:lower()
        local scored = {}
        for _, app in ipairs(apps or {}) do
            local score = 0
            local name_l = (app.name or ""):lower()
            local id_l = (app.id or ""):lower()
            local desc_l = (app.description or ""):lower()

            if name_l == q then
                score = 100
            elseif name_l:sub(1, #q) == q then
                score = 80
            elseif name_l:find(q, 1, true) then
                score = 60
            elseif id_l:find(q, 1, true) then
                score = 45
            else
                for _, kw in ipairs(app.keywords or {}) do
                    if kw:lower():find(q, 1, true) then
                        score = 40
                        break
                    end
                end
                if score == 0 and desc_l:find(q, 1, true) then
                    score = 20
                end
            end

            if score > 0 then
                table.insert(scored, { app = app, score = score })
            end
        end

        table.sort(scored, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return (a.app.name or ""):lower() < (b.app.name or ""):lower()
        end)

        local results = {}
        for i, item in ipairs(scored) do
            results[i] = item.app
        end
        return results
    end
})

local default_instance = nil

function ApplicationsService.get_default()
    if not default_instance then
        default_instance = ApplicationsService()
    end
    return default_instance
end

return {
    ApplicationsService = ApplicationsService,
    Application = Application,
    ApplicationAction = ApplicationAction,
    get_default = ApplicationsService.get_default
}
