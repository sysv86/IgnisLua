local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local Gdk = lgi.require("Gdk", "4.0")
local GObject = lgi.require("GObject")
local CssManager = require("ignis.css_manager")
local unpack = table.unpack or unpack

---@class Ignis.BaseWidget
local BaseWidget = {}

local registry = setmetatable({}, { __mode = "k" })

---@param self any
---@return table
local function get_env(self)
    local env = registry[self]
    if not env then
        env = {
            overrided_enums = {},
            lua_signals = {},
            bindings = {}
        }
        registry[self] = env
    end
    return env
end

local GTK_STYLE_PRIORITIES = {
    fallback = Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK,
    theme = Gtk.STYLE_PROVIDER_PRIORITY_THEME,
    settings = Gtk.STYLE_PROVIDER_PRIORITY_SETTINGS,
    application = Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    user = Gtk.STYLE_PROVIDER_PRIORITY_USER
}

local function resolve_enum_value(env, key, val)
    if type(val) ~= "string" then
        return val
    end
    local enum_tbl = env.overrided_enums and env.overrided_enums[key]
    if enum_tbl then
        local upper_key = val:upper():gsub("-", "_")
        if enum_tbl[upper_key] ~= nil then
            return enum_tbl[upper_key]
        end
        return upper_key
    end
    return val
end

local function index_lookup(orig_index, self_ptr, key)
    if type(orig_index) == "function" then
        return orig_index(self_ptr, key)
    elseif type(orig_index) == "table" then
        return orig_index[key]
    end
    return rawget(self_ptr, key)
end

local function newindex_assign(orig_newindex, self_ptr, key, val)
    if type(orig_newindex) == "function" then
        orig_newindex(self_ptr, key, val)
    elseif type(orig_newindex) == "table" then
        orig_newindex[key] = val
    else
        rawset(self_ptr, key, val)
    end
end

local lua_accessor_cache = setmetatable({}, { __mode = "k" })

local function find_lua_accessor(env, method_name)
    local root_cls = env and env._ignis_class
    if type(root_cls) ~= "table" then
        return nil
    end
    local cache = lua_accessor_cache[root_cls]
    if not cache then
        cache = {}
        lua_accessor_cache[root_cls] = cache
    end
    local cached = cache[method_name]
    if cached ~= nil then
        return cached or nil
    end

    local cls = root_cls
    while type(cls) == "table" do
        local fn = rawget(cls, method_name)
        if type(fn) == "function" then
            cache[method_name] = fn
            return fn
        end
        local methods = rawget(cls, "_method")
        if type(methods) == "table" then
            local mfn = rawget(methods, method_name)
            if type(mfn) == "function" then
                cache[method_name] = mfn
                return mfn
            end
        end
        cls = rawget(cls, "_parent")
    end
    cache[method_name] = false
    return nil
end

local gobject_prop_cache = setmetatable({}, { __mode = "k" })

local function has_gobject_property(self_ptr, prop)
    local ok_t, repo_type = pcall(function() return self_ptr._type end)
    if not ok_t or type(repo_type) ~= "table" then
        return false
    end
    local cache = gobject_prop_cache[repo_type]
    if not cache then
        cache = {}
        gobject_prop_cache[repo_type] = cache
    end
    local norm = prop:gsub("-", "_")
    if cache[norm] ~= nil then
        return cache[norm]
    end

    local dash = prop:gsub("_", "-")
    local found = false
    local cur = repo_type
    while type(cur) == "table" do
        local props = rawget(cur, "_property")
        if type(props) == "table" and (props[norm] ~= nil or props[dash] ~= nil) then
            found = true
            break
        end
        local impls = rawget(cur, "_implements")
        if type(impls) == "table" then
            for _, iface in pairs(impls) do
                local iprops = type(iface) == "table" and rawget(iface, "_property")
                if type(iprops) == "table" and (iprops[norm] ~= nil or iprops[dash] ~= nil) then
                    found = true
                    break
                end
            end
            if found then break end
        end
        cur = rawget(cur, "_parent")
    end

    cache[norm] = found
    cache[dash] = found
    return found
end

local function set_width_request_fn(self_ptr, value)
    self_ptr.width_request = value
end

local function set_height_request_fn(self_ptr, value)
    self_ptr.height_request = value
end

local function patch_instance_metatable(self)
    local mt = getmetatable(self)
    if mt and not mt._patched then
        mt._patched = true

        local orig_index = mt.__index
        mt.__index = function(self_ptr, key)
            if key == "_widget" then
                return self_ptr
            end

            if key == "set_width_request" then
                return set_width_request_fn
            elseif key == "set_height_request" then
                return set_height_request_fn
            end

            local env = get_env(self_ptr)

            if type(key) == "string" then
                local lua_method = find_lua_accessor(env, key)
                if lua_method then
                    if key:sub(1, 4) == "set_" then
                        local prop = key:sub(5)
                        if env.overrided_enums and env.overrided_enums[prop] then
                            return function(_, value)
                                return lua_method(self_ptr, resolve_enum_value(env, prop, value))
                            end
                        end
                    end
                    return lua_method
                end

                if key:sub(1, 4) == "set_" then
                    local prop = key:sub(5)
                    local enum_tbl = env.overrided_enums and env.overrided_enums[prop]
                    if enum_tbl then
                        local raw = index_lookup(orig_index, self_ptr, key)
                        if type(raw) == "function" or type(raw) == "userdata" then
                            return function(_, value)
                                return raw(self_ptr, resolve_enum_value(env, prop, value))
                            end
                        end
                    end
                end

                if key:sub(1, 1) ~= "_" and env.in_getter ~= key then
                    local getter = find_lua_accessor(env, "get_" .. key)
                    if getter then
                        local prev_getter = env.in_getter
                        env.in_getter = key
                        local ok_call, val = pcall(getter, self_ptr)
                        env.in_getter = prev_getter
                        if ok_call then
                            return val
                        end
                        error(val)
                    end
                end

                if env.custom_props and env.custom_props[key] ~= nil then
                    return env.custom_props[key]
                end
            end

            local ok, res = pcall(index_lookup, orig_index, self_ptr, key)
            if ok and res ~= nil then
                return res
            end
            return env.custom_props and env.custom_props[key] or nil
        end

        local orig_newindex = mt.__newindex
        mt.__newindex = function(self_ptr, key, val)
            local env = get_env(self_ptr)

            if type(key) == "string" and key:sub(1, 3) == "on_" and type(val) == "function" then
                if not env.pad_connections then
                    env.pad_connections = {}
                end
                table.insert(env.pad_connections, { callback = val, signal = key })
            end

            if type(val) == "table" and val._is_binding then
                self_ptr:bind_property2(key, val.source, val.source_properties, val.transform)
                return
            end

            if type(key) == "string" and env.overrided_enums and env.overrided_enums[key] then
                val = resolve_enum_value(env, key, val)
            end

            if type(key) == "string" and key:sub(1, 1) ~= "_" and env.in_setter ~= key then
                local setter = find_lua_accessor(env, "set_" .. key)
                if setter then
                    local prev_setter = env.in_setter
                    env.in_setter = key
                    local ok_call, err = pcall(setter, self_ptr, val)
                    env.in_setter = prev_setter
                    if not ok_call then
                        error(err)
                    end
                    return
                end
            end

            local ok = pcall(newindex_assign, orig_newindex, self_ptr, key, val)
            if not ok then
                if not env.custom_props then env.custom_props = {} end
                env.custom_props[key] = val
            end
        end
    end
end

local RESERVED_BASE_KEYS = {
    vexpand = true,
    hexpand = true,
    visible = true,
    tooltip_text = true,
    tooltip_markup = true,
    cursor = true,
    css_classes = true,
    halign = true,
    valign = true,
    style = true,
    style_priority = true,
    margin = true,
    margin_top = true,
    margin_bottom = true,
    margin_start = true,
    margin_end = true,
    margin_left = true,
    margin_right = true,
    width_request = true,
    height_request = true,
    opacity = true,
    sensitive = true,
    can_focus = true,
    can_target = true,
    focusable = true,
    name = true,
    setup = true,
}

function BaseWidget.apply_to_class(klass)

    function klass:connect(signal, callback)
        local env = get_env(self)
        if not env.lua_signals then
            env.lua_signals = {}
        end
        if not env.pad_connections then
            env.pad_connections = {}
        end

        if signal:sub(1, 8) == "notify::" then
            local raw_prop = signal:sub(9)
            local norm_prop = raw_prop:gsub("-", "_")
            local dash_prop = raw_prop:gsub("_", "-")
            local norm_sig = "notify::" .. norm_prop
            if not env.lua_signals[norm_sig] then
                env.lua_signals[norm_sig] = {}
            end
            table.insert(env.lua_signals[norm_sig], callback)

            if has_gobject_property(self, raw_prop) then
                local ok_pad, pad = pcall(function() return self.on_notify end)
                if ok_pad and pad then
                    local wrapped = function(obj, pspec)
                        if env._in_lua_notify == norm_prop then
                            return
                        end
                        callback(obj, pspec)
                    end
                    local ok_conn, id = pcall(function()
                        return pad:connect(wrapped, dash_prop)
                    end)
                    if ok_conn and id then
                        table.insert(env.pad_connections, { pad = pad, callback = wrapped, id = id })
                        return id
                    end
                end
            end
            return callback
        else
            local normalized_signal = signal:gsub("-", "_")
            local ok, signal_obj = pcall(function() return self["on_" .. normalized_signal] end)
            if ok and signal_obj then
                local id = signal_obj:connect(callback)
                table.insert(env.pad_connections, { pad = signal_obj, callback = callback, id = id })
                return id
            else
                if not env.lua_signals[signal] then
                    env.lua_signals[signal] = {}
                end
                table.insert(env.lua_signals[signal], callback)
                return callback
            end
        end
    end

    klass.connect_signal = klass.connect

    function klass:emit(signal, ...)
        local env = get_env(self)
        local list = env.lua_signals and env.lua_signals[signal]
        if list and #list > 0 then
            if #list == 1 then
                list[1](self, ...)
                return
            end
            local args = { ... }
            local callbacks = {}
            for i, cb in ipairs(list) do
                callbacks[i] = cb
            end
            for _, cb in ipairs(callbacks) do
                cb(self, unpack(args))
            end
        end
    end

    klass.emit_signal = klass.emit

    function klass:notify(prop)
        local env = get_env(self)
        local norm_prop = prop:gsub("-", "_")
        local dash_prop = prop:gsub("_", "-")
        local signal = "notify::" .. norm_prop

        local list = env.lua_signals and env.lua_signals[signal]
        if list and #list > 0 then
            local val = self[norm_prop]
            if #list == 1 then
                list[1](self, val)
            else
                local callbacks = {}
                for i, cb in ipairs(list) do
                    callbacks[i] = cb
                end
                for _, cb in ipairs(callbacks) do
                    cb(self, val)
                end
            end
        end

        if has_gobject_property(self, prop) then
            local prev = env._in_lua_notify
            env._in_lua_notify = norm_prop
            pcall(GObject.Object.notify, self, dash_prop)
            env._in_lua_notify = prev
        end
    end

    function klass:bind(prop, transform)
        local gobject = require("ignis.gobject")
        return gobject.Binding:new(self, { prop }, transform)
    end

    function klass:bind_many(props, transform)
        local gobject = require("ignis.gobject")
        return gobject.Binding:new(self, props, transform)
    end

    function klass:bind_property2(prop_name, source_obj, source_properties, transform)
        local function update_callback()
            local values = {}
            for i, src_prop in ipairs(source_properties) do
                values[i] = source_obj[src_prop]
            end

            local final_value
            if transform then
                final_value = transform(unpack(values))
            else
                if #values ~= 1 then
                    error("No transform function on multiple binding")
                end
                final_value = values[1]
            end

            self[prop_name] = final_value
        end

        for _, src_prop in ipairs(source_properties) do
            source_obj:connect("notify::" .. src_prop, update_callback)
        end

        update_callback()
    end

    function klass:get_style()
        return get_env(self).style
    end

    function klass:set_style(value)
        if not value then return end

        local env = get_env(self)
        if env.style == value and env.css_provider then
            return
        end

        local parsed_value = value
        if not value:find("{", 1, true) and not value:find("}", 1, true) then
            parsed_value = "* {" .. value .. "}"
        end

        local css_provider = env.css_provider
        if not css_provider then
            css_provider = Gtk.CssProvider()
            env.css_provider = css_provider
            local context = self:get_style_context()
            if context then
                local priority_str = env.style_priority or "application"
                local priority = GTK_STYLE_PRIORITIES[priority_str] or Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                context:add_provider(css_provider, priority)
            end
        end

        css_provider:load_from_string(parsed_value)
        env.style = value
        self:notify("style")
    end

    function klass:get_style_priority()
        return get_env(self).style_priority or "application"
    end

    function klass:set_style_priority(value)
        local env = get_env(self)
        if env.style_priority == value then return end
        env.style_priority = value
        if env.css_provider then
            local context = self:get_style_context()
            if context then
                context:remove_provider(env.css_provider)
                local priority = GTK_STYLE_PRIORITIES[value] or Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                context:add_provider(env.css_provider, priority)
            end
        end
    end

    function klass:toggle_css_class(class_name, active)
        if active == nil then
            active = not self:has_css_class(class_name)
        end
        if active then
            if not self:has_css_class(class_name) then
                self:add_css_class(class_name)
            end
        else
            if self:has_css_class(class_name) then
                self:remove_css_class(class_name)
            end
        end
    end

    function klass:override_enum(property_name, enum)
        local env = get_env(self)
        if not env.overrided_enums then
            env.overrided_enums = {}
        end
        env.overrided_enums[property_name] = enum
    end

    function klass:init_base_widget(props)
        props = props or {}

        local env = get_env(self)
        if not env._ignis_class then
            env._ignis_class = klass
        end

        patch_instance_metatable(self)

        if not env.overrided_enums then
            env.overrided_enums = {}
        end

        local css_manager = CssManager.get_default()
        env.style_priority = props.style_priority or css_manager.widgets_style_priority or "application"

        self:override_enum("halign", Gtk.Align)
        self:override_enum("valign", Gtk.Align)
        self:override_enum("overflow", Gtk.Overflow)

        if props.vexpand ~= nil then self.vexpand = props.vexpand end
        if props.hexpand ~= nil then self.hexpand = props.hexpand end
        if type(props.visible) == "table" and props.visible._is_binding then
            self.visible = props.visible
        else
            self.visible = props.visible ~= false
        end
        if props.tooltip_text ~= nil then self.tooltip_text = props.tooltip_text end
        if props.tooltip_markup ~= nil then self.tooltip_markup = props.tooltip_markup end
        if props.width_request ~= nil then self.width_request = props.width_request end
        if props.height_request ~= nil then self.height_request = props.height_request end
        if props.opacity ~= nil then self.opacity = props.opacity end
        if props.sensitive ~= nil then self.sensitive = props.sensitive end
        if props.can_focus ~= nil then self.can_focus = props.can_focus end
        if props.can_target ~= nil then self.can_target = props.can_target end
        if props.focusable ~= nil then self.focusable = props.focusable end
        if props.name ~= nil then self.name = props.name end

        if type(props.margin) == "number" then
            self.margin_top = props.margin
            self.margin_bottom = props.margin
            self.margin_start = props.margin
            self.margin_end = props.margin
        elseif type(props.margin) == "table" then
            if props.margin.top then self.margin_top = props.margin.top end
            if props.margin.bottom then self.margin_bottom = props.margin.bottom end
            if props.margin.left or props.margin.start then self.margin_start = props.margin.left or props.margin.start end
            if props.margin.right or props.margin["end"] then self.margin_end = props.margin.right or props.margin["end"] end
        end
        if props.margin_top ~= nil then self.margin_top = props.margin_top end
        if props.margin_bottom ~= nil then self.margin_bottom = props.margin_bottom end
        if props.margin_start ~= nil then self.margin_start = props.margin_start end
        if props.margin_end ~= nil then self.margin_end = props.margin_end end
        if props.margin_left ~= nil and props.margin_start == nil then self.margin_start = props.margin_left end
        if props.margin_right ~= nil and props.margin_end == nil then self.margin_end = props.margin_right end

        if props.cursor then
            if type(props.cursor) == "string" then
                self.cursor = Gdk.Cursor.new_from_name(props.cursor, nil)
            else
                self.cursor = props.cursor
            end
        end

        if props.css_classes then
            if type(props.css_classes) == "string" then
                local classes = {}
                for cls in props.css_classes:gmatch("%S+") do
                    table.insert(classes, cls)
                end
                self:set_css_classes(classes)
            elseif type(props.css_classes) == "table" and props.css_classes._is_binding then
                self.css_classes = props.css_classes
            else
                local clean_classes = {}
                for _, cls in ipairs(props.css_classes) do
                    if type(cls) == "string" and cls ~= "" then
                        table.insert(clean_classes, cls)
                    end
                end
                self:set_css_classes(clean_classes)
            end
        end

        if props.halign ~= nil then
            self.halign = props.halign
        end
        if props.valign ~= nil then
            self.valign = props.valign
        end

        if props.style ~= nil then
            self.style = props.style
        end

        if props.setup then
            props.setup(self)
        end
    end
end

BaseWidget.get_env = get_env
BaseWidget.patch_instance_metatable = patch_instance_metatable
BaseWidget.RESERVED_BASE_KEYS = RESERVED_BASE_KEYS
BaseWidget.resolve_enum_value = resolve_enum_value

return BaseWidget
