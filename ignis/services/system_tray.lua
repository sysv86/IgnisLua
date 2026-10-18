local gobject = require("ignis.gobject")

---@class Ignis.SystemTrayMenu : Ignis.Object
local SystemTrayMenu = gobject.class(gobject.Object, {
    init = function(self, bus_name, menu_path)
        self._bus_name = bus_name
        self._menu_path = menu_path
        self._proxy = nil
        self._items = {}

        local ok, dbus_mod = pcall(require, "ignis.dbus")
        local ok_misc, misc = pcall(require, "ignis.utils.misc")
        if ok and ok_misc and bus_name and menu_path and menu_path ~= "" and menu_path ~= "/" then
            local ok_p, proxy = pcall(function()
                return dbus_mod.DBusProxy.new(
                    bus_name,
                    menu_path,
                    "com.canonical.dbusmenu",
                    misc.load_interface_xml("com.canonical.dbusmenu"),
                    "session"
                )
            end)
            if ok_p and proxy then
                self._proxy = proxy
                self:__sync_layout()
                self._proxy:signal_subscribe("LayoutUpdated", function()
                    self:__sync_layout()
                end)
                self._proxy:signal_subscribe("ItemsPropertiesUpdated", function()
                    self:__sync_layout()
                end)
            end
        end
    end,

    properties = {
        items = { get = function(self) return self._items end },
    },

    __parse_node = function(self, node)
        if type(node) ~= "table" then return nil end
        local id = node[1]
        local props = node[2] or {}
        local children = node[3] or {}

        if props.visible == false then return nil end
        if props.type == "separator" then
            return { separator = true }
        end

        local label = (props.label or ""):gsub("_", "")
        local enabled = (props.enabled ~= false)

        if props["children-display"] == "submenu" or #children > 0 then
            local sub_items = {}
            for _, child_node in ipairs(children) do
                local parsed = self:__parse_node(child_node)
                if parsed then
                    table.insert(sub_items, parsed)
                end
            end
            return {
                label = label,
                enabled = enabled,
                submenu = sub_items,
            }
        end

        return {
            label = label,
            enabled = enabled,
            on_activate = function()
                self:send_event(id, "clicked")
            end
        }
    end,

    __sync_layout = function(self)
        if not self._proxy then return end
        local ok, res = pcall(function()
            return self._proxy:GetLayout("(iias)", 0, -1, {})
        end)
        if not ok or type(res) ~= "table" then return end
        local root_layout = res[2]
        if type(root_layout) ~= "table" then return end
        local children = root_layout[3] or {}
        local parsed_items = {}
        for _, child_node in ipairs(children) do
            local item = self:__parse_node(child_node)
            if item then
                table.insert(parsed_items, item)
            end
        end
        self._items = parsed_items
        self:notify("items")
    end,

    send_event = function(self, item_id, event_id)
        if not self._proxy then return end
        local ok, lgi = pcall(require, "lgi")
        if ok and lgi.GLib then
            local GLib = lgi.GLib
            pcall(function()
                self._proxy:Event("(isvu)", item_id, event_id or "clicked", GLib.Variant("i", 0), 0)
            end)
        end
    end,

    create_popover = function(self)
        local ok, widgets = pcall(require, "ignis.widgets")
        if not ok or not widgets then return nil end
        return widgets.PopoverMenu({
            items = self:bind("items")
        })
    end
})

---@class Ignis.SystemTrayItem : Ignis.Object
local SystemTrayItem = gobject.class(gobject.Object, {
    init = function(self, service_str, bus_name, obj_path, proxy)
        self._service_str = service_str
        self._bus_name = bus_name
        self._object_path = obj_path
        self._proxy = proxy
        self._menu = nil
        self._data = {
            id = service_str,
            title = "",
            status = "Active",
            category = "ApplicationStatus",
            icon_name = "application-x-executable-symbolic",
            attention_icon_name = "",
            icon_theme_path = "",
            item_is_menu = false,
            menu_path = "",
            tooltip = "",
            window_id = 0,
        }

        if self._proxy then
            self:__sync()
            self._proxy:watch_properties(function()
                self:__sync()
            end)
            for _, sig in ipairs({ "NewTitle", "NewIcon", "NewAttentionIcon", "NewOverlayIcon", "NewStatus", "NewToolTip" }) do
                self._proxy:signal_subscribe(sig, function()
                    self:__sync()
                end)
            end
        end
    end,

    properties = {
        id = { get = function(self) return self._data.id end },
        bus_name = { get = function(self) return self._bus_name end },
        object_path = { get = function(self) return self._object_path end },
        title = { get = function(self) return self._data.title end },
        status = { get = function(self) return self._data.status end },
        category = { get = function(self) return self._data.category end },
        icon = { get = function(self) return self._data.icon_name end },
        icon_name = { get = function(self) return self._data.icon_name end },
        attention_icon_name = { get = function(self) return self._data.attention_icon_name end },
        icon_theme_path = { get = function(self) return self._data.icon_theme_path end },
        item_is_menu = { get = function(self) return self._data.item_is_menu end },
        menu_path = { get = function(self) return self._data.menu_path end },
        menu = { get = function(self) return self._menu end },
        tooltip = { get = function(self) return self._data.tooltip end },
        window_id = { get = function(self) return self._data.window_id end },
    },

    __sync = function(self)
        local p = self._proxy
        if not p then return end
        local d = self._data
        d.id = p.Id or d.id
        d.title = p.Title or ""
        d.status = p.Status or "Active"
        d.category = p.Category or "ApplicationStatus"
        d.icon_name = p.IconName or d.icon_name
        d.attention_icon_name = p.AttentionIconName or ""
        d.icon_theme_path = p.IconThemePath or ""
        d.item_is_menu = p.ItemIsMenu or false
        d.menu_path = p.Menu or ""
        d.window_id = p.WindowId or 0

        if d.icon_theme_path ~= "" then
            pcall(function()
                require("ignis.icon_manager").get_default():add_icons(d.icon_theme_path)
            end)
        end

        if d.menu_path ~= "" and d.menu_path ~= "/" and not self._menu then
            self._menu = SystemTrayMenu(self._bus_name, d.menu_path)
        end

        local tt = p.ToolTip
        if type(tt) == "table" and tt[3] and tt[3] ~= "" then
            d.tooltip = tt[3]
        else
            d.tooltip = d.title
        end
        self:notify_all()
    end,

    activate = function(self, x, y)
        if self._data.item_is_menu then
            self:context_menu(x, y)
            return
        end
        if self._proxy then
            pcall(function() self._proxy:Activate("(ii)", x or 0, y or 0) end)
        end
    end,

    secondary_activate = function(self, x, y)
        if self._proxy then
            pcall(function() self._proxy:SecondaryActivate("(ii)", x or 0, y or 0) end)
        end
    end,

    context_menu = function(self, x, y)
        if self._proxy then
            pcall(function() self._proxy:ContextMenu("(ii)", x or 0, y or 0) end)
        end
    end,

    scroll = function(self, delta, orientation)
        if self._proxy then
            pcall(function() self._proxy:Scroll("(is)", delta or 0, orientation or "vertical") end)
        end
    end
})

---@class Ignis.SystemTrayService : Ignis.Object
local SystemTrayService = gobject.class(gobject.Object, {
    init = function(self)
        self._items = {}
        self._watcher = nil
        self._dbus = nil

        local ok, dbus_mod = pcall(require, "ignis.dbus")
        local ok_misc, misc = pcall(require, "ignis.utils.misc")
        if ok and ok_misc then
            pcall(function()
                self:__setup_watcher(dbus_mod, misc)
            end)
        end
    end,

    properties = {
        items = {
            get = function(self)
                local list = {}
                for _, item in pairs(self._items) do
                    table.insert(list, item)
                end
                return list
            end
        }
    },

    __setup_watcher = function(self, dbus_mod, misc)
        local lgi = require("lgi")
        local GLib = lgi.GLib
        local watcher_info = misc.load_interface_xml("org.kde.StatusNotifierWatcher")
        local item_info = misc.load_interface_xml("org.kde.StatusNotifierItem")

        self._dbus = dbus_mod.DBusProxy.new(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            misc.load_interface_xml("org.freedesktop.DBus"),
            "session"
        )

        self._watcher = dbus_mod.DBusService(
            "org.kde.StatusNotifierWatcher",
            "/StatusNotifierWatcher",
            watcher_info
        )

        self._watcher:register_dbus_property("RegisteredStatusNotifierItems", function()
            local keys = {}
            for k, _ in pairs(self._items) do
                table.insert(keys, k)
            end
            return GLib.Variant("as", keys)
        end)

        self._watcher:register_dbus_property("IsStatusNotifierHostRegistered", function()
            return GLib.Variant("b", true)
        end)

        self._watcher:register_dbus_property("ProtocolVersion", function()
            return GLib.Variant("i", 0)
        end)

        self._watcher:register_dbus_method("RegisterStatusNotifierHost", function()
            self._watcher:emit_signal("StatusNotifierHostRegistered", nil)
        end)

        self._watcher:register_dbus_method("RegisterStatusNotifierItem", function(invocation, service)
            local sender = invocation:get_sender()
            local bus_name, obj_path
            if service:sub(1, 1) == "/" then
                bus_name = sender
                obj_path = service
            else
                bus_name = service
                obj_path = "/StatusNotifierItem"
            end
            local full_key = bus_name .. obj_path
            local ok_item, item_proxy = pcall(function()
                return dbus_mod.DBusProxy.new(
                    bus_name,
                    obj_path,
                    "org.kde.StatusNotifierItem",
                    item_info,
                    "session"
                )
            end)
            if ok_item and item_proxy then
                local item = SystemTrayItem(full_key, bus_name, obj_path, item_proxy)
                self._items[full_key] = item
                self:notify("items")
                self:emit("added", item)
                self._watcher:emit_signal("StatusNotifierItemRegistered", GLib.Variant("(s)", { full_key }))
            end
        end)

        if self._dbus then
            self._dbus:signal_subscribe("NameOwnerChanged", function(_, params)
                if type(params) ~= "table" then return end
                local name, old_owner, new_owner = params[1], params[2], params[3]
                if old_owner and old_owner ~= "" and (not new_owner or new_owner == "") then
                    local removed_any = false
                    for k, item in pairs(self._items) do
                        if item.bus_name == name or item.bus_name == old_owner then
                            self._items[k] = nil
                            item:emit("removed")
                            self:emit("removed", item)
                            self._watcher:emit_signal("StatusNotifierItemUnregistered", GLib.Variant("(s)", { k }))
                            removed_any = true
                        end
                    end
                    if removed_any then
                        self:notify("items")
                    end
                end
            end)
        end
    end
})

local default_instance = nil

function SystemTrayService.get_default()
    if not default_instance then
        default_instance = SystemTrayService()
    end
    return default_instance
end

return {
    SystemTrayService = SystemTrayService,
    SystemTrayItem = SystemTrayItem,
    SystemTrayMenu = SystemTrayMenu,
    get_default = SystemTrayService.get_default
}
