local json = require("ignis.utils.json")
local file_utils = require("ignis.utils.file")

local M = {}


--- Marks a default value as a list option.
---@param values table
---@return table
function M.list(values)
    return { __ignis_list = true, values = values or {} }
end

--- Builds an OptionsGroup specification from a table of defaults.
---@param spec table
---@return table
function M.Group(spec)
    return setmetatable({}, {
        __ignis_group_spec = true,
        __spec = spec,
    })
end

--- Returns the raw spec table behind a `Group` marker.
---@param group table
---@return table
local function spec_of(group)
    local mt = getmetatable(group)
    return (mt and mt.__spec) or group
end

--- True when `value` is a `Group` marker (the marker flag lives in its
--- metatable, so a plain field lookup would not see it).
---@param value any
---@return boolean
local function is_group_spec(value)
    if type(value) ~= "table" then return false end
    local mt = getmetatable(value)
    return mt ~= nil and mt.__ignis_group_spec == true
end


local function clone_list(values)
    local copy = {}
    for i, v in ipairs(values or {}) do copy[i] = v end
    return copy
end

local function coerce(field, value)
    local dt = field.type
    if dt == "boolean" then
        if type(value) == "string" then
            return value == "true" or value == "1"
        end
        return value and true or false
    elseif dt == "number" then
        local n = tonumber(value)
        return n or field.default
    elseif dt == "string" then
        if value == nil then return field.default end
        return tostring(value)
    elseif dt == "list" then
        if type(value) ~= "table" then return clone_list(field.default) end
        return clone_list(value)
    end
    return value
end

local function type_of_default(value)
    if type(value) == "table" and value.__ignis_list then
        return "list"
    end
    local t = type(value)
    if t == "table" then return "list" end
    return t
end


local OptionsGroup = {}
local group_index, group_newindex

--- Returns the current value of a leaf, a nested group, a generated
--- `get_<name>()`/`set_<name>()` accessor, or a method.
group_index = function(self, key)
    local fields = rawget(self, "_fields")
    local field = fields and fields[key]
    if field then
        return field.value
    end

    local groups = rawget(self, "_groups")
    local sub = groups and groups[key]
    if sub then
        return sub
    end

    if type(key) == "string" then
        if key:sub(1, 4) == "set_" then
            local name = key:sub(5)
            if (fields and fields[name]) or (groups and groups[name]) then
                return function(first, second)
                    if groups and groups[name] then
                        error("Cannot assign to option group '" .. name .. "'")
                    end
                    if second == nil and first ~= self then
                        self:_set(name, first)
                    else
                        self:_set(name, second)
                    end
                end
            end
        elseif key:sub(1, 4) == "get_" then
            local name = key:sub(5)
            if (fields and fields[name]) or (groups and groups[name]) then
                return function(_)
                    return group_index(self, name)
                end
            end
        end
    end

    local method = OptionsGroup[key]
    if method then
        return method
    end

    return nil
end

group_newindex = function(self, key, value)
    if type(key) ~= "string" or key:sub(1, 1) == "_" then
        rawset(self, key, value)
        return
    end

    local fields = rawget(self, "_fields")
    if fields and fields[key] then
        self:_set(key, value)
        return
    end

    local groups = rawget(self, "_groups")
    if groups and groups[key] then
        error("Cannot replace option group '" .. tostring(key) .. "'")
    end

    rawset(self, key, value)
end

OptionsGroup.__index = group_index
OptionsGroup.__newindex = group_newindex

function OptionsGroup:_emit_notify(name, value)
    local signals = rawget(self, "_signals")
    local list = signals and signals["notify::" .. name]
    if not list then return end
    local copy = {}
    for i, cb in ipairs(list) do copy[i] = cb end
    for _, cb in ipairs(copy) do
        cb(self, value, name)
    end
end

--- Connects a callback to `notify::<prop>` or a custom signal name.
---@param signal string
---@param callback function
function OptionsGroup:connect(signal, callback)
    local signals = rawget(self, "_signals")
    if not signals then
        signals = {}
        rawset(self, "_signals", signals)
    end
    local norm = signal:gsub("^notify::([%w%-]+)$", function(p)
        return "notify::" .. p:gsub("-", "_")
    end)
    signals[norm] = signals[norm] or {}
    table.insert(signals[norm], callback)
    return callback
end

--- Disconnects a previously connected callback.
function OptionsGroup:disconnect(callback)
    local signals = rawget(self, "_signals")
    if not signals then return end
    for _, list in pairs(signals) do
        for i = #list, 1, -1 do
            if list[i] == callback then
                table.remove(list, i)
            end
        end
    end
end

--- Subscribes to a single option's changes.
---@param name string
---@param callback fun(value: any)
---@return function disconnect
function OptionsGroup:connect_option(name, callback)
    local handle = self:connect("notify::" .. name, function(_, value)
        callback(value)
    end)
    return function()
        self:disconnect(handle)
    end
end

--- Creates a reactive binding to one option.
---@param name string
---@param transform? function
---@return Ignis.Binding
function OptionsGroup:bind(name, transform)
    local gobject = require("ignis.gobject")
    return gobject.Binding:new(self, { name }, transform)
end

--- Returns a plain Lua table of current values (for serialisation).
---@return table
function OptionsGroup:to_table()
    local result = {}
    for name, field in pairs(rawget(self, "_fields")) do
        if type(field.value) == "table" then
            result[name] = clone_list(field.value)
        else
            result[name] = field.value
        end
    end
    for name, group in pairs(rawget(self, "_groups")) do
        result[name] = group:to_table()
    end
    return result
end

--- Applies saved values recursively, ignoring unknown keys.
---@param data table
function OptionsGroup:_load_from(data)
    if type(data) ~= "table" then return end
    for name, value in pairs(data) do
        local field = rawget(self, "_fields")[name]
        if field then
            field.value = coerce(field, value)
        else
            local group = rawget(self, "_groups")[name]
            if group and type(value) == "table" then
                group:_load_from(value)
            end
        end
    end
end

--- Notifies every field and nested group.
function OptionsGroup:_emit_notify_all()
    for name, field in pairs(rawget(self, "_fields")) do
        self:_emit_notify(name, field.value)
    end
    for _, group in pairs(rawget(self, "_groups")) do
        group:_emit_notify_all()
    end
end

--- Sets a field, notifies listeners and schedules persistence.
function OptionsGroup:_set(name, value)
    local field = rawget(self, "_fields")[name]
    if not field then
        error("Unknown option: " .. tostring(name))
    end

    local new_value = coerce(field, value)
    local old_value = field.value
    field.value = new_value

    if old_value == new_value and type(new_value) ~= "table" then
        return
    end

    self:_emit_notify(name, field.value)

    local manager = rawget(self, "_manager")
    if manager then
        manager:_schedule_save()
    end
end

--- Lists the option names declared on this group (leaf fields only).
---@return string[]
function OptionsGroup:list_options()
    local names = {}
    for name in pairs(rawget(self, "_fields")) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

--- Builds a group from a spec, wiring it to a manager for persistence.
---@param spec table
---@param opts? { manager?: table, parent?: table, key?: string }
---@return table
local function create_group(spec, opts)
    opts = opts or {}
    local fields, groups = {}, {}

    local self = setmetatable({
        _fields = fields,
        _groups = groups,
        _signals = {},
        _manager = opts.manager,
        _parent = opts.parent,
        _key = opts.key,
    }, OptionsGroup)

    for name, value in pairs(spec) do
        if is_group_spec(value) then
            groups[name] = create_group(spec_of(value), {
                manager = opts.manager,
                parent = self,
                key = name,
            })
        else
            local default = value
            if type(value) == "table" and value.__ignis_list then
                default = clone_list(value.values)
            end
            fields[name] = {
                default = default,
                value = type(default) == "table" and clone_list(default) or default,
                type = type_of_default(value),
            }
        end
    end

    return self
end

M.OptionsGroup = OptionsGroup
M.create_group = create_group


local OptionsManager = {}

---@param opts { file: string, schema: table, pretty?: boolean }
---@return table
function OptionsManager.new(opts)
    opts = opts or {}
    assert(opts.schema, "OptionsManager requires a 'schema'")

    local self = setmetatable({
        _file = file_utils.expand_path(opts.file or ""),
        _pretty = opts.pretty ~= false,
        _save_source = nil,
        _dirty = false,
    }, OptionsManager)

    self._root = create_group(spec_of(opts.schema), { manager = self, key = "" })
    self:_load()
    return self
end

--- Proxies unknown keys to the root options group.
OptionsManager.__index = function(self, key)
    local method = rawget(OptionsManager, key)
    if method then
        return method
    end
    local root = rawget(self, "_root")
    if root then
        local value = group_index(root, key)
        if value ~= nil then
            return value
        end
    end
    return nil
end

OptionsManager.__newindex = function(self, key, value)
    if type(key) == "string" and key:sub(1, 1) == "_" then
        rawset(self, key, value)
        return
    end
    local root = rawget(self, "_root")
    if root then
        group_newindex(root, key, value)
    else
        rawset(self, key, value)
    end
end

function OptionsManager:_load()
    if self._file == "" then return end
    local ok, content = pcall(file_utils.read_file, self._file, false)
    if not ok or not content or content == "" then return end
    local decoded_ok, data = pcall(json.decode, content)
    if decoded_ok and type(data) == "table" then
        self._root:_load_from(data)
    end
end

--- Serialises the tree to disk immediately.
function OptionsManager:save()
    if self._file == "" then return end
    pcall(file_utils.write_file, self._file, self._root:to_table(), self._pretty)
    self._dirty = false
end

--- Re-reads the file and re-notifies every option.
function OptionsManager:reload()
    self:_load()
    self._root:_emit_notify_all()
end

--- Debounced persistence (coalesces bursts of option changes).
function OptionsManager:_schedule_save()
    self._dirty = true
    local ok, lgi = pcall(require, "lgi")
    if not ok or not lgi.GLib then
        self:save()
        return
    end
    if self._save_source then
        return
    end
    self._save_source = lgi.GLib.timeout_add(lgi.GLib.PRIORITY_DEFAULT, 250, function()
        self._save_source = nil
        if self._dirty then
            self:save()
        end
        return false
    end)
end

M.OptionsManager = setmetatable(OptionsManager, {
    __call = function(_, opts)
        return OptionsManager.new(opts)
    end,
})

return M
