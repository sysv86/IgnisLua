local gobject = require("ignis.gobject")
local timeout_mod = require("ignis.utils.timeout")
local file_utils = require("ignis.utils.file")

local URGENCY_MAP = {
    [0] = "low",
    [1] = "normal",
    [2] = "critical",
}

---@class Ignis.NotificationAction : Ignis.Object
local NotificationAction = gobject.class(gobject.Object, {
    init = function(self, id, label, notification, service)
        self._id = id
        self._label = label
        self._notification = notification
        self._service = service
    end,

    properties = {
        id = { get = function(self) return self._id end },
        label = { get = function(self) return self._label end },
    },

    invoke = function(self)
        if self._service then
            self._service:_invoke_action(self._notification.id, self._id)
        end
    end
})

---@class Ignis.Notification : Ignis.Object
local Notification = gobject.class(gobject.Object, {
    init = function(self, opts, service)
        opts = opts or {}
        self._service = service
        self._id = opts.id or 1
        self._app_name = opts.app_name or ""
        self._icon = opts.icon or ""
        self._summary = opts.summary or ""
        self._body = opts.body or ""
        self._timeout = opts.timeout or 5000
        self._time = opts.time or os.time()
        self._urgency = opts.urgency or "normal"
        self._desktop_entry = opts.desktop_entry or ""
        self._popup = opts.popup ~= false
        self._actions = {}

        local raw_actions = opts.actions or {}
        for i = 1, #raw_actions, 2 do
            local act_id = raw_actions[i]
            local act_label = raw_actions[i + 1] or act_id
            if act_id then
                table.insert(self._actions, NotificationAction(act_id, act_label, self, service))
            end
        end
    end,

    properties = {
        id = { get = function(self) return self._id end },
        app_name = { get = function(self) return self._app_name end },
        icon = { get = function(self) return self._icon end },
        summary = { get = function(self) return self._summary end },
        body = { get = function(self) return self._body end },
        timeout = { get = function(self) return self._timeout end },
        time = { get = function(self) return self._time end },
        urgency = { get = function(self) return self._urgency end },
        desktop_entry = { get = function(self) return self._desktop_entry end },
        actions = { get = function(self) return self._actions end },
        popup = { get = function(self) return self._popup end },
    },

    to_table = function(self)
        local raw_acts = {}
        for _, a in ipairs(self._actions) do
            table.insert(raw_acts, a.id)
            table.insert(raw_acts, a.label)
        end
        return {
            id = self._id,
            app_name = self._app_name,
            icon = self._icon,
            summary = self._summary,
            body = self._body,
            timeout = self._timeout,
            time = self._time,
            urgency = self._urgency,
            desktop_entry = self._desktop_entry,
            actions = raw_acts,
            popup = false,
        }
    end,

    dismiss = function(self)
        if self._popup then
            self._popup = false
            self:notify("popup")
            self:emit("dismissed")
            if self._service then
                self._service:_on_dismissed(self)
            end
        end
    end,

    close = function(self)
        self:dismiss()
        self:emit("closed")
        if self._service then
            self._service:_close_notification(self._id, 2)
        end
    end
})

---@class Ignis.NotificationService : Ignis.Object
local NotificationService = gobject.class(gobject.Object, {
    init = function(self)
        local ignis = package.loaded["ignis"]
        local cache_dir = (ignis and ignis.CACHE_DIR) or ((os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") or "/tmp") .. "/.cache") .. "/ignis")
        self._history_file = cache_dir .. "/notifications.json"

        self._notifications = {}
        self._by_id = {}
        self._next_id = 1
        self._dnd = false
        self._popup_timeout = 5000
        self._max_popups_count = 3
        self._dbus = nil

        self:__load_history()

        local ok, dbus_mod = pcall(require, "ignis.dbus")
        local ok_misc, misc = pcall(require, "ignis.utils.misc")
        if ok and ok_misc then
            pcall(function()
                self:__setup_dbus(dbus_mod, misc)
            end)
        end
    end,

    properties = {
        notifications = {
            get = function(self)
                return self._notifications
            end
        },
        popups = {
            get = function(self)
                local list = {}
                for _, n in ipairs(self._notifications) do
                    if n.popup then
                        table.insert(list, n)
                    end
                end
                return list
            end
        },
        dnd = {
            get = function(self) return self._dnd end,
            set = function(self, val)
                self._dnd = val and true or false
                self:__save_history()
                self:notify("dnd")
            end
        },
        popup_timeout = {
            get = function(self) return self._popup_timeout end,
            set = function(self, val)
                self._popup_timeout = tonumber(val) or 5000
                self:__save_history()
            end
        },
        max_popups_count = {
            get = function(self) return self._max_popups_count end,
            set = function(self, val)
                self._max_popups_count = tonumber(val) or 3
                self:__save_history()
            end
        }
    },

    __load_history = function(self)
        if not file_utils.file_exists(self._history_file) then return end
        local ok, data = pcall(file_utils.read_file, self._history_file, true)
        if not ok or type(data) ~= "table" then return end
        if data.dnd ~= nil then self._dnd = data.dnd end
        if data.popup_timeout then self._popup_timeout = data.popup_timeout end
        if data.max_popups_count then self._max_popups_count = data.max_popups_count end
        for _, raw in ipairs(data.notifications or {}) do
            raw.popup = false
            local n = Notification(raw, self)
            table.insert(self._notifications, n)
            self._by_id[n.id] = n
            if n.id >= self._next_id then
                self._next_id = n.id + 1
            end
        end
    end,

    __save_history = function(self)
        local serialized = {}
        for i = 1, math.min(#self._notifications, 100) do
            table.insert(serialized, self._notifications[i]:to_table())
        end
        pcall(file_utils.write_file, self._history_file, {
            dnd = self._dnd,
            popup_timeout = self._popup_timeout,
            max_popups_count = self._max_popups_count,
            notifications = serialized,
        }, true)
    end,

    __setup_dbus = function(self, dbus_mod, misc)
        local lgi = require("lgi")
        local GLib = lgi.GLib
        local info = misc.load_interface_xml("org.freedesktop.Notifications")

        self._dbus = dbus_mod.DBusService(
            "org.freedesktop.Notifications",
            "/org/freedesktop/Notifications",
            info
        )

        self._dbus:register_dbus_method("GetCapabilities", function()
            return GLib.Variant("(as)", { {
                "actions",
                "body",
                "body-hyperlinks",
                "body-markup",
                "icon-static",
                "persistence",
            } })
        end)

        self._dbus:register_dbus_method("GetServerInformation", function()
            return GLib.Variant("(ssss)", { "IgnisLua", "ignis-sh", "0.6.0", "1.2" })
        end)

        self._dbus:register_dbus_method("CloseNotification", function(_, id)
            self:_close_notification(id, 3)
        end)

        self._dbus:register_dbus_method("Notify", function(_, app_name, replaces_id, app_icon, summary, body, actions, hints, expire_timeout)
            local id = (replaces_id and replaces_id > 0) and replaces_id or self._next_id
            if id >= self._next_id then
                self._next_id = id + 1
            end

            hints = hints or {}
            local urgency = URGENCY_MAP[tonumber(hints.urgency) or 1] or "normal"
            local desktop_entry = hints["desktop-entry"] or ""
            local image_path = hints["image-path"] or hints["image_path"] or ""
            local resolved_icon = app_icon
            if (not resolved_icon or resolved_icon == "") and image_path ~= "" then
                resolved_icon = image_path
            elseif (not resolved_icon or resolved_icon == "") and desktop_entry ~= "" then
                resolved_icon = desktop_entry
            end

            local timeout_ms = (expire_timeout and expire_timeout >= 0) and expire_timeout or self._popup_timeout

            local notif = Notification({
                id = id,
                app_name = app_name,
                icon = resolved_icon,
                summary = summary,
                body = body,
                actions = actions,
                urgency = urgency,
                desktop_entry = desktop_entry,
                timeout = timeout_ms,
                popup = not self._dnd,
            }, self)

            self:_register_notification(notif)
            return GLib.Variant("(u)", { id })
        end)
    end,

    _register_notification = function(self, notif)
        if self._by_id[notif.id] then
            for i, existing in ipairs(self._notifications) do
                if existing.id == notif.id then
                    table.remove(self._notifications, i)
                    break
                end
            end
        end

        table.insert(self._notifications, 1, notif)
        self._by_id[notif.id] = notif

        if notif.popup and self._max_popups_count > 0 then
            local popup_count = 0
            for _, n in ipairs(self._notifications) do
                if n.popup then
                    popup_count = popup_count + 1
                    if popup_count > self._max_popups_count then
                        n:dismiss()
                    end
                end
            end
        end

        if notif.popup and notif.timeout > 0 then
            timeout_mod.Timeout(notif.timeout, function()
                notif:dismiss()
            end)
        end

        self:__save_history()
        self:notify("notifications")
        self:notify("popups")
        self:emit("notified", notif)
        if notif.popup then
            self:emit("new-popup", notif)
        end
    end,

    _on_dismissed = function(self, _)
        self:notify("popups")
    end,

    _close_notification = function(self, id, reason)
        local notif = self._by_id[id]
        if not notif then return end
        self._by_id[id] = nil
        for i, n in ipairs(self._notifications) do
            if n.id == id then
                table.remove(self._notifications, i)
                break
            end
        end
        self:__save_history()
        self:notify("notifications")
        self:notify("popups")

        if self._dbus then
            local ok, lgi = pcall(require, "lgi")
            if ok and lgi.GLib then
                self._dbus:emit_signal("NotificationClosed", lgi.GLib.Variant("(uu)", { id, reason or 2 }))
            end
        end
    end,

    _invoke_action = function(self, notif_id, action_id)
        if self._dbus then
            local ok, lgi = pcall(require, "lgi")
            if ok and lgi.GLib then
                self._dbus:emit_signal("ActionInvoked", lgi.GLib.Variant("(us)", { notif_id, action_id }))
            end
        end
    end,

    get_notification = function(self, id)
        return self._by_id[id]
    end,

    clear_all = function(self)
        local ids = {}
        for id, _ in pairs(self._by_id) do
            table.insert(ids, id)
        end
        for _, id in ipairs(ids) do
            local n = self._by_id[id]
            if n then n:close() end
        end
    end,

    dismiss_all = function(self)
        for _, n in ipairs(self._notifications) do
            if n.popup then n:dismiss() end
        end
    end
})

local default_instance = nil

function NotificationService.get_default()
    if not default_instance then
        default_instance = NotificationService()
    end
    return default_instance
end

return {
    NotificationService = NotificationService,
    Notification = Notification,
    NotificationAction = NotificationAction,
    get_default = NotificationService.get_default
}
