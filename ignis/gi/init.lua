local ok_native, native = pcall(require, "ignis.native")
if ok_native and native then
    pcall(native.ensure_layer_shell)
    pcall(native.register_typelib_dirs, {
        "/usr/lib/ignis-gvc",
        "/usr/local/lib/ignis-gvc",
    })
end

local GI

local gtk4_override = require("ignis.gi.gtk4_override")
local gdk4_override = require("ignis.gi.gdk4_override")

package.preload["lgi.override.Gtk"] = function() return gtk4_override end
package.preload["lgi.override.Gdk"] = function() return gdk4_override end
package.preload["LuaGObject.override.Gdk"] = function() return gdk4_override end

local gi_backend = nil
local backend_name = "none"
local forced_backend = os.getenv("IGNIS_GI_BACKEND")

if forced_backend ~= "lgi" then
    local ok_luagobject, luagobject = pcall(require, "LuaGObject")
    if ok_luagobject and type(luagobject) == "table" then
        gi_backend = luagobject
        backend_name = "LuaGObject"
        if not package.loaded["lgi"] then
            package.loaded["lgi"] = luagobject
        end
    end
end

if not gi_backend and forced_backend ~= "luagobject" then
    local ok_lgi, lgi = pcall(require, "lgi")
    if ok_lgi and type(lgi) == "table" then
        gi_backend = lgi
        backend_name = "lgi-gtk4-native"
    end
end

if not gi_backend then
    error("IgnisLua GI Error: Neither 'LuaGObject' nor 'lgi' GObject Introspection runtime was found.")
end

local GLib = gi_backend.GLib
local Gio = gi_backend.Gio
local GObject = gi_backend.GObject

pcall(function()
    local core = require("LuaGObject.core")
    local pspec = GObject.ParamSpec
    if core and pspec and GObject.Type and GObject.Type.PARAM then
        core.index[core.gtype(GObject.Type.PARAM)] = pspec
    end
end)

if backend_name == "LuaGObject" and GObject.Object._method
    and not GObject.Object._method.connect then
    local function signal_pad(self, signal_name)
        local ok, pad = pcall(function()
            return self["on_" .. signal_name:gsub("-", "_")]
        end)
        if ok then return pad end
        return nil
    end

    GObject.Object._method.connect = function(self, signal, callback)
        local name, detail = tostring(signal):match("^(.-)::(.+)$")
        if name then
            local pad = signal_pad(self, name)
            if pad then
                local id = pad:connect(callback, detail)
                GI.retain_connection(pad, callback, id)
                return id
            end
            return self:connect_signal(name, callback, detail)
        end
        local pad = signal_pad(self, signal)
        if pad then
            local id = pad:connect(callback)
            GI.retain_connection(pad, callback, id)
            return id
        end
        return self:connect_signal(signal, callback)
    end
end

if not (ok_native and native) then
    pcall(function()
        local ok_gi, GIRepository = pcall(gi_backend.require, "GIRepository", "2.0")
        if ok_gi and GIRepository and GIRepository.Repository then
            for _, gvc_dir in ipairs({ "/usr/lib/ignis-gvc", "/usr/local/lib/ignis-gvc" }) do
                if GLib.file_test(gvc_dir, GLib.FileTest.IS_DIR) then
                    GIRepository.Repository.prepend_search_path(gvc_dir)
                    GIRepository.Repository.prepend_library_path(gvc_dir)
                end
            end
        end
    end)
end

local Gtk4LayerShell = gi_backend.require("Gtk4LayerShell", "1.0")
local Gdk = gi_backend.require("Gdk", "4.0")
local Gtk = gi_backend.require("Gtk", "4.0")
local GdkPixbuf = gi_backend.require("GdkPixbuf", "2.0")

if gdk4_override and gdk4_override._post_instantiate then
    pcall(gdk4_override._post_instantiate, Gdk)
end
if gtk4_override and gtk4_override._post_instantiate then
    pcall(gtk4_override._post_instantiate, Gtk)
end

GI = {
    backend = gi_backend,
    backend_name = backend_name,
    native = ok_native and native or nil,
    require = gi_backend.require,
    package = gi_backend.package,
    GLib = GLib,
    Gio = Gio,
    GObject = GObject,
    Gtk4LayerShell = Gtk4LayerShell,
    Gdk = Gdk,
    Gtk = Gtk,
    GdkPixbuf = GdkPixbuf,
}

setmetatable(GI, {
    __index = function(_, k)
        return gi_backend[k]
    end
})

local retained_closures = {}

function GI.callback(fn)
    if fn == nil then return nil end
    if backend_name == "LuaGObject" then
        local ok, closure = pcall(GObject.Closure, fn)
        if ok then
            retained_closures[#retained_closures + 1] = { closure = closure, fn = fn }
            return closure
        end
    end
    return fn
end

local retained_connections = {}

--- Retains a signal connection for the lifetime of the process.
---@param pad any
---@param callback function
---@param id any
function GI.retain_connection(pad, callback, id)
    retained_connections[#retained_connections + 1] = {
        pad = pad,
        callback = callback,
        id = id,
    }
end

local function retain_pad(pad)
    if type(pad) ~= "table" or rawget(pad, "_ignis_retained_connect") then
        return pad
    end
    local original_connect = rawget(pad, "connect")
    if type(original_connect) ~= "function" then
        return pad
    end
    rawset(pad, "connect", function(self, callback, detail)
        local id
        if detail ~= nil then
            id = original_connect(self, callback, detail)
        else
            id = original_connect(self, callback)
        end
        GI.retain_connection(self, callback, id)
        return id
    end)
    rawset(pad, "_ignis_retained_connect", true)
    return pad
end

--- Connects a Lua callback to a GI signal while retaining the pad and the
--- callback, so LuaGObject cannot free the GClosure behind them.
---@param emitter table|userdata
---@param signal string signal name (dashes or underscores)
---@param callback function
---@param detail? string
---@return any connection_id
function GI.connect_signal(emitter, signal, callback, detail)
    if not emitter then return nil end
    local pad = emitter["on_" .. tostring(signal):gsub("-", "_")]
    if not pad then return nil end
    local id
    if detail ~= nil then
        id = pad:connect(callback, detail)
    else
        id = pad:connect(callback)
    end
    GI.retain_connection(pad, callback, id)
    return id
end

if backend_name == "LuaGObject" then
    local ok_probe, probe = pcall(function() return Gio.File.new_for_path("/") end)
    if ok_probe and probe then
        local mt = getmetatable(probe)
        if type(mt) == "table" and type(mt.__index) == "function" then
            local original_index = mt.__index
            mt.__index = function(self, key)
                local value = original_index(self, key)
                if type(key) == "string" and key:sub(1, 3) == "on_" and type(value) == "table" then
                    return retain_pad(value)
                end
                return value
            end
        end
    end
end

return GI
