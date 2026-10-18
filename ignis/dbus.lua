local lgi = require("lgi")
local Gio = lgi.Gio
local GLib = lgi.GLib
local gobject = require("ignis.gobject")
local unpack = table.unpack or unpack

local DBUS_TRACE = os.getenv("IGNIS_DBUS_TRACE") ~= nil

local function dbus_trace(fmt, ...)
    if not DBUS_TRACE then return end
    local caller = ""
    local info = debug.getinfo(3, "Sl")
    if info then
        caller = " [" .. tostring(info.short_src) .. ":" .. tostring(info.currentline) .. "]"
    end
    io.stderr:write(string.format("[DBUS %s] ", os.date("%H:%M:%S")) .. string.format(fmt, ...) .. caller .. "\n")
    io.stderr:flush()
end

local BUS_TYPE = {
    session = Gio.BusType.SESSION,
    system = Gio.BusType.SYSTEM
}

local function unpack_variant(v)
    if not v then return nil end
    local ok, type_char = pcall(function() return v:get_type_string() end)
    if not ok or not type_char then return v end

    if type_char == "v" then
        local inner = v:get_variant()
        if inner == nil then return nil end
        return unpack_variant(inner)
    elseif type_char == "m" then
        local inner = v:get_maybe()
        if inner == nil then return nil end
        return unpack_variant(inner)
    end

    if v:is_container() then
        local n = v:n_children()
        if type_char:sub(1, 2) == "a{" then
            local t = {}
            for i = 0, n - 1 do
                local entry = v:get_child_value(i)
                local key = unpack_variant(entry:get_child_value(0))
                local val = unpack_variant(entry:get_child_value(1))
                if key ~= nil then
                    t[key] = val
                end
            end
            return t
        elseif type_char:sub(1, 1) == "{" then
            local key = unpack_variant(v:get_child_value(0))
            local val = unpack_variant(v:get_child_value(1))
            return key, val
        elseif type_char == "ay" then
            local bytes = {}
            for i = 0, n - 1 do
                bytes[i + 1] = v:get_child_value(i):get_byte()
            end
            return bytes
        else
            local t = {}
            for i = 0, n - 1 do
                t[i + 1] = unpack_variant(v:get_child_value(i))
            end
            return t
        end
    end

    local tc = type_char:sub(1, 1)
    if tc == "s" or tc == "o" or tc == "g" then
        return v:get_string()
    elseif tc == "b" then
        return v:get_boolean()
    elseif tc == "y" then
        return v:get_byte()
    elseif tc == "n" then
        return v:get_int16()
    elseif tc == "q" then
        return v:get_uint16()
    elseif tc == "i" or tc == "h" then
        return v:get_int32()
    elseif tc == "u" then
        return v:get_uint32()
    elseif tc == "x" then
        return v:get_int64()
    elseif tc == "t" then
        return v:get_uint64()
    elseif tc == "d" then
        return v:get_double()
    elseif tc == "v" then
        return unpack_variant(v:get_variant())
    elseif tc == "m" then
        local val = v:get_maybe()
        if val then
            return unpack_variant(val)
        else
            return nil
        end
    else
        return nil
    end
end

local function pack_variant(signature, value)
    if not signature or signature == "" then
        return nil
    end
    if type(value) == "userdata" then
        return value
    end
    return GLib.Variant(signature, value)
end

local DBusService = gobject.class(gobject.Object, {
    init = function(self, name, object_path, info, on_name_acquired, on_name_lost)
        if type(name) == "table" then
            local opts = name
            name = opts.name
            object_path = opts.object_path
            info = opts.info
            on_name_acquired = opts.on_name_acquired
            on_name_lost = opts.on_name_lost
        end

        self._name = name
        self._object_path = object_path
        self._info = info
        self._on_name_acquired = on_name_acquired
        self._on_name_lost = on_name_lost

        self._methods = {}
        self._properties = {}
        self._connection = nil

        self._id = Gio.bus_own_name(
            Gio.BusType.SESSION,
            name,
            Gio.BusNameOwnerFlags.NONE,
            require("ignis.gi").callback(function(connection, name_owned)
                self:__export_object(connection, name_owned)
            end),
            require("ignis.gi").callback(function(connection, name_owned)
                if self._on_name_acquired then
                    self._on_name_acquired(self, connection, name_owned)
                end
            end),
            require("ignis.gi").callback(function(connection, name_owned)
                if self._on_name_lost then
                    self._on_name_lost(self, connection, name_owned)
                end
            end)
        )
    end,

    properties = {
        name = {
            get = function(self) return self._name end
        },
        object_path = {
            get = function(self) return self._object_path end
        },
        info = {
            get = function(self) return self._info end
        },
        connection = {
            get = function(self) return self._connection end
        },
        methods = {
            get = function(self) return self._methods end
        },
        dbus_properties = {
            get = function(self) return self._properties end
        }
    },

    __export_object = function(self, connection, _)
        self._connection = connection

        local function method_call(_, _, _, _, method_name, parameters, invocation)
            local func = self._methods[method_name]
            if not func then
                invocation:return_dbus_error(
                    "com.github.linkfrg.ignis.Error",
                    "No such registered D-Bus method: " .. tostring(method_name)
                )
                return
            end

            local args = unpack_variant(parameters) or {}
            local success, res = pcall(func, invocation, unpack(args))
            if not success then
                invocation:return_dbus_error(
                    "com.github.linkfrg.ignis.Error", tostring(res))
            else
                if res then
                    pcall(function() invocation:return_value(res) end)
                else
                    pcall(function() invocation:return_value(nil) end)
                end
            end
        end

        local handlers = {
            method_call = method_call,

            get_property = function(_, _, _, _, property_name)
                local func = self._properties[property_name]
                if not func then
                    return nil
                end
                return func()
            end,

            set_property = function()
                return false
            end
        }

        local gi = require("ignis.gi")
        local vtable
        if gi.backend_name == "LuaGObject" then
            vtable = gi.callback(method_call)
        else
            vtable = handlers
        end

        self._vtable = vtable

        local ok, reg_id, err = pcall(function()
            return connection:register_object(self._object_path, self._info, vtable)
        end)
        if not ok then
            self._reg_error = reg_id
            io.stderr:write("[WARN] D-Bus object export failed: " .. tostring(reg_id) .. "\n")
            return
        end
        if not reg_id then
            error("Failed to register D-Bus object: " .. tostring(err))
        end
        self._reg_id = reg_id
    end,

    register_dbus_method = function(self, name, method_fn)
        self._methods[name] = method_fn
    end,

    register_dbus_property = function(self, name, property_fn)
        self._properties[name] = property_fn
    end,

    emit_signal = function(self, signal_name, parameters, destination)
        if self._connection then
            local iface_name = (self._info and self._info.name) or self._name
            self._connection:emit_signal(
                destination,
                self._object_path,
                iface_name,
                signal_name,
                parameters
            )
        end
    end,

    unown_name = function(self)
        if self._id then
            Gio.bus_unown_name(self._id)
            self._id = nil
        end
    end
})

local DBusProxy = gobject.class(gobject.Object, {
    init = function(self, bus_type, gproxy)
        self._bus_type = bus_type or "session"
        self._gproxy = gproxy
        self._methods = {}
        self._method_set = {}
        self._method_fn_cache = {}
        self._properties = {}
        self._property_set = {}
        self._property_signatures = {}

        local info = gproxy.g_interface_info
        if info then
            if info.methods then
                for _, method in ipairs(info.methods) do
                    table.insert(self._methods, method.name)
                    self._method_set[method.name] = true
                end
            end
            if info.properties then
                for _, prop in ipairs(info.properties) do
                    table.insert(self._properties, prop.name)
                    self._property_set[prop.name] = true
                    self._property_signatures[prop.name] = prop.signature
                end
            end
        end
    end
})

local construct_instance = DBusProxy.new

local function get_variant(signature, ...)
    local args = { ... }
    if not signature or signature == "" then
        return nil
    end
    if signature:sub(1, 1) == "(" then
        return GLib.Variant(signature, args)
    else
        return GLib.Variant(signature, args[1])
    end
end

local base_index = DBusProxy.__index
local base_newindex = DBusProxy.__newindex

DBusProxy.__index = function(self, key)
    local gproxy = rawget(self, "_gproxy")
    if key == "name" then
        return gproxy.g_name
    elseif key == "object_path" then
        return gproxy.g_object_path
    elseif key == "interface_name" then
        return gproxy.g_interface_name
    elseif key == "info" then
        return gproxy.g_interface_info
    elseif key == "bus_type" then
        return rawget(self, "_bus_type")
    elseif key == "gproxy" then
        return gproxy
    elseif key == "connection" then
        return gproxy:get_connection()
    elseif key == "methods" then
        return rawget(self, "_methods")
    elseif key == "properties" then
        return rawget(self, "_properties")
    elseif key == "has_owner" then
        return self:get_has_owner()
    end

    if type(key) == "string" then
        local fn_cache = rawget(self, "_method_fn_cache")
        if fn_cache and fn_cache[key] then
            return fn_cache[key]
        end

        local is_async = false
        local method_name = key
        local method_set = rawget(self, "_method_set")
        if key:sub(-5) == "Async" then
            local base_method = key:sub(1, -6)
            if method_set and method_set[base_method] then
                is_async = true
                method_name = base_method
            end
        end

        local is_sync_method = method_set and method_set[key] or false

        if is_sync_method or is_async then
            local fn
            if is_async then
                fn = function(self_ptr, signature, ...)
                    local args = { ... }
                    local callback = type(args[#args]) == "function" and table.remove(args) or nil
                    local var_params = get_variant(signature, unpack(args))
                    self_ptr._gproxy:call(
                        method_name,
                        var_params,
                        Gio.DBusCallFlags.NONE,
                        -1,
                        nil,
                        function(obj, res)
                            local reply, err = obj:call_finish(res)
                            if not reply then
                                if callback then callback(nil, err) end
                            else
                                local unpacked = unpack_variant(reply)
                                if type(unpacked) == "table" and #unpacked == 1 then
                                    unpacked = unpacked[1]
                                end
                                if callback then callback(unpacked, nil) end
                            end
                        end
                    )
                end
            else
                fn = function(self_ptr, signature, ...)
                    local var_params = get_variant(signature, ...)
                    dbus_trace("call %s.%s on %s", self_ptr.interface_name, method_name, self_ptr.name)
                    local res, err = self_ptr._gproxy:call_sync(
                        method_name,
                        var_params,
                        Gio.DBusCallFlags.NONE,
                        -1,
                        nil
                    )
                    dbus_trace("done %s.%s", self_ptr.interface_name, method_name)
                    if not res then
                        error("D-Bus call '" .. method_name .. "' failed: " .. tostring(err))
                    end
                    local unpacked = unpack_variant(res)
                    if type(unpacked) == "table" and #unpacked == 1 then
                        return unpacked[1]
                    end
                    return unpacked
                end
            end
            if fn_cache then
                fn_cache[key] = fn
            end
            return fn
        end

        local property_set = rawget(self, "_property_set")
        if property_set and property_set[key] then
            return self:get_dbus_property(key)
        end
    end

    return base_index(self, key)
end

DBusProxy.__newindex = function(self, key, val)
    local property_set = rawget(self, "_property_set")
    if property_set and property_set[key] then
        self:set_dbus_property(key, val)
    else
        base_newindex(self, key, val)
    end
end

function DBusProxy.new(name, object_path, interface_name, info, bus_type)
    if DBUS_TRACE then
        dbus_trace("new proxy %s %s", tostring(interface_name), tostring(object_path))
    end
    if type(name) == "table" then
        local opts = name
        name = opts.name
        object_path = opts.object_path
        interface_name = opts.interface_name
        info = opts.info
        bus_type = opts.bus_type
    end
    bus_type = bus_type or "session"
    local gbus = BUS_TYPE[bus_type]
    local gproxy, err = Gio.DBusProxy.new_for_bus_sync(
        gbus,
        Gio.DBusProxyFlags.NONE,
        info,
        name,
        object_path,
        interface_name,
        nil
    )
    if not gproxy then
        error("Failed to create DBusProxy: " .. tostring(err))
    end
    return construct_instance(DBusProxy, bus_type, gproxy)
end

function DBusProxy.new_async(name, object_path, interface_name, info, bus_type, callback)
    if type(name) == "table" then
        local opts = name
        name = opts.name
        object_path = opts.object_path
        interface_name = opts.interface_name
        info = opts.info
        bus_type = opts.bus_type
        callback = opts.callback or callback
    end
    bus_type = bus_type or "session"
    local gbus = BUS_TYPE[bus_type]

    Gio.DBusProxy.new_for_bus(
        gbus,
        Gio.DBusProxyFlags.NONE,
        info,
        name,
        object_path,
        interface_name,
        nil,
        function(_, res)
            local gproxy, err = Gio.DBusProxy.new_for_bus_finish(res)
            if not gproxy then
                if callback then callback(nil, err) end
            else
                local proxy = construct_instance(DBusProxy, bus_type, gproxy)
                if callback then callback(proxy, nil) end
            end
        end
    )
end

function DBusProxy:get_dbus_property(property_name)
    local variant = self._gproxy:get_cached_property(property_name)
    if variant then
        return unpack_variant(variant)
    end

    dbus_trace("get %s.%s on %s", self.interface_name, property_name, self.name)
    local success, res = pcall(function()
        return self._gproxy:get_connection():call_sync(
            self.name,
            self.object_path,
            "org.freedesktop.DBus.Properties",
            "Get",
            GLib.Variant("(ss)", { self.interface_name, property_name }),
            nil,
            Gio.DBusCallFlags.NONE,
            -1,
            nil
        )
    end)
    if success and res then
        local val = unpack_variant(res)
        if type(val) == "table" and #val == 1 then
            return val[1]
        end
        return val
    end
    return nil
end

function DBusProxy:set_dbus_property(property_name, value)
    local gval = value
    if type(value) ~= "userdata" then
        local sig = self._property_signatures and self._property_signatures[property_name]
        if sig then
            gval = pack_variant(sig, value)
        elseif type(value) == "string" then
            gval = GLib.Variant("s", value)
        elseif type(value) == "boolean" then
            gval = GLib.Variant("b", value)
        elseif type(value) == "number" then
            gval = GLib.Variant("d", value)
        end
    end

    self._gproxy:set_cached_property(property_name, gval)

    dbus_trace("set %s.%s on %s", self.interface_name, property_name, self.name)
    pcall(function()
        self._gproxy:get_connection():call_sync(
            self.name,
            self.object_path,
            "org.freedesktop.DBus.Properties",
            "Set",
            GLib.Variant("(ssv)", { self.interface_name, property_name, gval }),
            nil,
            Gio.DBusCallFlags.NONE,
            -1,
            nil
        )
    end)
end

local function defer(callback)
    if GLib and GLib.idle_add then
        return function()
            GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, function()
                callback()
                return false
            end)
        end
    end
    return callback
end

function DBusProxy:signal_subscribe(signal_name, callback)
    local wrapper = function(_, _, _, _, _, parameters)
        if callback then
            local unpacked = unpack_variant(parameters)
            defer(function()
                callback(self, unpacked)
            end)()
        end
    end
    self._signal_callbacks = self._signal_callbacks or {}
    table.insert(self._signal_callbacks, { callback = callback, wrapper = wrapper })

    return self._gproxy:get_connection():signal_subscribe(
        self.name,
        self.interface_name,
        signal_name,
        self.object_path,
        nil,
        Gio.DBusSignalFlags.NONE,
        wrapper
    )
end

function DBusProxy:signal_unsubscribe(id)
    if id then
        self._gproxy:get_connection():signal_unsubscribe(id)
    end
end

function DBusProxy:watch_properties(callback)
    local wrapper = function(_, _, _, _, _, parameters)
        local unpacked = unpack_variant(parameters)
        if unpacked and callback then
            local values = { unpacked[1], unpacked[2] or {}, unpacked[3] or {} }
            defer(function()
                callback(self, values[1], values[2], values[3])
            end)()
        end
    end
    self._signal_callbacks = self._signal_callbacks or {}
    table.insert(self._signal_callbacks, { callback = callback, wrapper = wrapper })

    return self._gproxy:get_connection():signal_subscribe(
        self.name,
        "org.freedesktop.DBus.Properties",
        "PropertiesChanged",
        self.object_path,
        nil,
        Gio.DBusSignalFlags.NONE,
        wrapper
    )
end

local _shared_fdo_dbus = {}

function DBusProxy:get_has_owner()
    local gproxy = rawget(self, "_gproxy")
    if gproxy and gproxy.get_name_owner then
        local ok, owner = pcall(function() return gproxy:get_name_owner() end)
        if ok and owner and owner ~= "" then
            return true
        end
    end
    local btype = self._bus_type or "session"
    local dbus_proxy = _shared_fdo_dbus[btype]
    if not dbus_proxy then
        local success, p = pcall(function()
            local misc = require("ignis.utils.misc")
            return DBusProxy.new(
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                "org.freedesktop.DBus",
                misc.load_interface_xml("org.freedesktop.DBus"),
                btype
            )
        end)
        if success and p then
            _shared_fdo_dbus[btype] = p
            dbus_proxy = p
        end
    end
    if not dbus_proxy then
        return false
    end
    local has_owner_success, has_owner = pcall(function()
        return dbus_proxy:NameHasOwner("(s)", self.name)
    end)
    return has_owner_success and has_owner or false
end

return {
    DBusService = DBusService,
    DBusProxy = DBusProxy,
    unpack_variant = unpack_variant,
    pack_variant = pack_variant
}
