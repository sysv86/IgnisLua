local M = {}
local unpack = table.unpack or unpack

---@class Ignis.Binding
---@field target any
---@field source any
---@field source_properties string[]
---@field transform function|nil
---@field _is_binding boolean
local Binding = {}
Binding.__index = Binding

function Binding:new(source, source_properties, transform)
    if type(source_properties) == "string" then
        source_properties = { source_properties }
    end
    local self_obj = setmetatable({
        source = source,
        source_properties = source_properties or { "value" },
        transform = transform,
        _is_binding = true
    }, Binding)
    return self_obj
end

--- Fluent helper to chain an additional transformation onto an existing Binding
---@param fn function
---@return Ignis.Binding
function Binding:map(fn)
    local prev = self.transform
    if prev then
        self.transform = function(...)
            return fn(prev(...))
        end
    else
        self.transform = fn
    end
    return self
end

M.Binding = Binding

local function instance_index(inst, key)
    local klass = getmetatable(inst)
    if not klass then return nil end

    local prop = klass.properties and klass.properties[key]
    if prop then
        if prop.get then
            return prop.get(inst)
        else
            return inst._values[key]
        end
    end

    if type(key) == "string" then
        if key:sub(1, 4) == "set_" then
            local prop_name = key:sub(5)
            local explicit_setter = rawget(klass, key)
            if explicit_setter then return explicit_setter end
            if klass.properties and klass.properties[prop_name] then
                return function(self, val)
                    self[prop_name] = val
                end
            end
        elseif key:sub(1, 4) == "get_" then
            local prop_name = key:sub(5)
            local explicit_getter = rawget(klass, key)
            if explicit_getter then return explicit_getter end
            if klass.properties and klass.properties[prop_name] then
                return function(self)
                    return self[prop_name]
                end
            end
        end
    end

    local val = klass[key]
    if val ~= nil then
        return val
    end

    return inst._values and inst._values[key] or nil
end

local function instance_newindex(inst, key, val)
    local klass = getmetatable(inst)

    local prop = klass and klass.properties and klass.properties[key]
    if prop then
        if type(val) == "table" and val._is_binding then
            inst:bind_property2(key, val.source, val.source_properties, val.transform)
            return
        end

        local old_val
        if prop.get then
            old_val = prop.get(inst)
        else
            old_val = inst._values[key]
        end

        if prop.set then
            prop.set(inst, val)
        else
            inst._values[key] = val
        end

        if old_val ~= val or type(val) == "table" then
            inst:notify(key)
        end
    else
        if type(val) == "table" and val._is_binding then
            inst:bind_property2(key, val.source, val.source_properties, val.transform)
            return
        end
        rawset(inst, key, val)
    end
end

---@class Ignis.Object
local ObjectMethods = {}

function ObjectMethods:init()
end

--- Connects a callback to a named signal (e.g. "changed" or "notify::value")
---@param signal string
---@param callback function
---@return function callback_handle
function ObjectMethods:connect(signal, callback)
    if type(callback) ~= "function" then
        error("Object:connect() requires a function callback for signal '" .. tostring(signal) .. "'")
    end
    if not self._signals then
        self._signals = {}
    end
    local norm_sig = signal:gsub("^notify::([%w%-]+)$", function(p)
        return "notify::" .. p:gsub("-", "_")
    end)
    if not self._signals[norm_sig] then
        self._signals[norm_sig] = {}
    end
    table.insert(self._signals[norm_sig], callback)
    return callback
end

--- Connects a callback that automatically disconnects after firing once
---@param signal string
---@param callback function
---@return function callback_handle
function ObjectMethods:connect_once(signal, callback)
    local wrapper
    wrapper = function(self_obj, ...)
        self_obj:disconnect(wrapper, signal)
        return callback(self_obj, ...)
    end
    return self:connect(signal, wrapper)
end

--- Disconnects a previously connected callback
---@param callback_or_id function
---@param signal? string
function ObjectMethods:disconnect(callback_or_id, signal)
    if not self._signals then return end
    local function remove_from_list(list)
        if not list then return end
        for i = #list, 1, -1 do
            if list[i] == callback_or_id then
                table.remove(list, i)
            end
        end
    end
    if signal then
        local norm_sig = signal:gsub("^notify::([%w%-]+)$", function(p)
            return "notify::" .. p:gsub("-", "_")
        end)
        remove_from_list(self._signals[norm_sig])
        remove_from_list(self._signals[signal])
    else
        for _, list in pairs(self._signals) do
            remove_from_list(list)
        end
    end
end

--- Blocks a signal handler temporarily
---@param callback function
function ObjectMethods:block_signal(callback)
    if not self._blocked_signals then
        self._blocked_signals = {}
    end
    self._blocked_signals[callback] = true
end

--- Unblocks a previously blocked signal handler
---@param callback function
function ObjectMethods:unblock_signal(callback)
    if self._blocked_signals then
        self._blocked_signals[callback] = nil
    end
end

--- Emits a signal to all connected listeners
---@param signal string
---@param ... any
function ObjectMethods:emit(signal, ...)
    if not self._signals then return end
    local norm_sig = signal:gsub("^notify::([%w%-]+)$", function(p)
        return "notify::" .. p:gsub("-", "_")
    end)
    local list = self._signals[norm_sig] or self._signals[signal]
    if list and #list > 0 then
        local args = { ... }
        local callbacks = {}
        for i, cb in ipairs(list) do
            callbacks[i] = cb
        end
        local blocked = self._blocked_signals
        for _, cb in ipairs(callbacks) do
            if not (blocked and blocked[cb]) then
                cb(self, unpack(args))
            end
        end
    end
end

--- Emits "notify::<prop>" with the current property value
---@param prop string
function ObjectMethods:notify(prop)
    local norm_prop = prop:gsub("-", "_")
    local current_val = self[norm_prop]
    self:emit("notify::" .. norm_prop, current_val, norm_prop)
end

--- Notifies all registered properties except those in `without`
---@param without? string|string[]
function ObjectMethods:notify_all(without)
    local without_map = {}
    if type(without) == "string" then
        without_map[without] = true
    elseif type(without) == "table" then
        for _, v in ipairs(without) do
            without_map[v] = true
        end
    end

    local klass = getmetatable(self)
    if klass and klass.properties then
        for prop_name, _ in pairs(klass.properties) do
            if not without_map[prop_name] then
                self:notify(prop_name)
            end
        end
    end
end

--- Notifies a specific list of property names
---@param ... string
function ObjectMethods:notify_list(...)
    for _, prop in ipairs({ ... }) do
        self:notify(prop)
    end
end

function ObjectMethods:set_property(prop, val)
    self[prop] = val
end

function ObjectMethods:get_property(prop)
    return self[prop]
end

local Object = {}
Object.properties = {}
Object.__index = instance_index
Object.__newindex = instance_newindex
setmetatable(Object, { __index = ObjectMethods })

--- Creates a reactive Binding for a property on this object
---@param prop string
---@param transform? function
---@return Ignis.Binding
function Object:bind(prop, transform)
    return Binding:new(self, { prop }, transform)
end

--- Creates a multi-property reactive Binding
---@param props string[]
---@param transform function
---@return Ignis.Binding
function Object:bind_many(props, transform)
    return Binding:new(self, props, transform)
end

--- Unbinds an existing reactive binding on `prop_name`
---@param prop_name string
function Object:unbind_property(prop_name)
    if self._bindings and self._bindings[prop_name] then
        local b = self._bindings[prop_name]
        for _, conn in ipairs(b.connections) do
            if conn.source and conn.source.disconnect then
                pcall(conn.source.disconnect, conn.source, conn.cb, conn.signal)
            end
        end
        self._bindings[prop_name] = nil
    end
end

--- Internal implementation of reactive property binding
function Object:bind_property2(prop_name, source_obj, source_properties, transform)
    self:unbind_property(prop_name)

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

        local old_val
        if type(self) == "userdata" then
            old_val = self[prop_name]
            self[prop_name] = final_value
        else
            local klass = getmetatable(self)
            local prop = klass and klass.properties and klass.properties[prop_name]
            if prop and prop.get then
                old_val = prop.get(self)
            else
                old_val = self._values[prop_name]
            end

            if prop and prop.set then
                prop.set(self, final_value)
            else
                self._values[prop_name] = final_value
            end
        end

        if old_val ~= final_value then
            self:notify(prop_name)
        end
    end

    if not self._bindings then
        self._bindings = {}
    end
    local connections = {}
    for _, src_prop in ipairs(source_properties) do
        local sig = "notify::" .. src_prop
        local cb = source_obj:connect(sig, update_callback)
        table.insert(connections, { source = source_obj, signal = sig, cb = cb })
    end
    self._bindings[prop_name] = { connections = connections }

    update_callback()
end

--- Cleans up all signals and bindings attached to this object
function Object:dispose()
    if self._bindings then
        for prop_name, _ in pairs(self._bindings) do
            self:unbind_property(prop_name)
        end
        self._bindings = nil
    end
    self._signals = nil
    self._blocked_signals = nil
end

M.Object = Object

---@param parent? table
---@param spec table
---@return table
local function class(parent, spec)
    if spec == nil and type(parent) == "table" and parent ~= Object then
        spec = parent
        parent = Object
    end
    local klass = {}
    spec = spec or {}
    parent = parent or Object

    klass.properties = {}
    if parent and parent.properties then
        for k, v in pairs(parent.properties) do
            klass.properties[k] = v
        end
    end
    if spec.properties then
        for k, v in pairs(spec.properties) do
            klass.properties[k] = v
        end
    end

    for k, v in pairs(spec) do
        if k ~= "properties" then
            klass[k] = v
        end
    end

    klass._parent = parent

    setmetatable(klass, {
        __index = parent,
        __call = function(t, ...)
            return t:new(...)
        end
    })

    function klass:new(...)
        local inst = setmetatable({
            _signals = {},
            _values = {},
            _bindings = {}
        }, klass)

        if inst.init then
            inst:init(...)
        end
        return inst
    end

    klass.__index = instance_index
    klass.__newindex = instance_newindex

    return klass
end

M.class = class
M.ObjectMethods = ObjectMethods

return M
