local json = require("ignis.utils.json")
local ok_native, native = pcall(require, "ignis.native")

local M = {}

--- Expand leading `~` and `$VAR` / `${VAR}` environment variables in a file path
---@param path string
---@return string
function M.expand_path(path)
    if not path then return "" end
    local res = path:gsub("^~", function()
        return os.getenv("HOME") or "~"
    end)
    res = res:gsub("%$([%w_]+)", function(var)
        return os.getenv(var) or ("$" .. var)
    end)
    res = res:gsub("%${([%w_]+)}", function(var)
        return os.getenv(var) or ("${" .. var .. "}")
    end)
    return res
end

--- Check whether a file or directory exists
---@param path string
---@return boolean
function M.file_exists(path)
    path = M.expand_path(path)
    if ok_native and native and native.file_exists then
        if native.file_exists(path) then return true end
    end
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    local ok, lgi = pcall(require, "lgi")
    if ok and lgi.GLib and lgi.GLib.file_test then
        return lgi.GLib.file_test(path, lgi.GLib.FileTest.EXISTS)
    end
    return false
end

--- Check whether a path is a directory
---@param path string
---@return boolean
function M.is_dir(path)
    path = M.expand_path(path)
    if ok_native and native and native.is_dir then
        if native.is_dir(path) then return true end
    end
    local ok, lgi = pcall(require, "lgi")
    if ok and lgi.GLib and lgi.GLib.file_test then
        return lgi.GLib.file_test(path, lgi.GLib.FileTest.IS_DIR)
    end
    return false
end

--- Read a file's contents synchronously (optionally decoding JSON)
---@param path string
---@param decode_json? boolean
---@return any
function M.read_file(path, decode_json)
    path = M.expand_path(path)
    if ok_native and native and native.read_file_fast then
        local content = native.read_file_fast(path)
        if content ~= nil then
            if decode_json then
                return json.decode(content)
            end
            return content
        end
    end
    local f, err = io.open(path, "rb")
    if not f then
        error("Could not open file '" .. tostring(path) .. "': " .. tostring(err))
    end
    local content = f:read("*a")
    f:close()
    if decode_json then
        return json.decode(content)
    end
    return content
end

--- Write contents to a file synchronously (optionally encoding table as JSON)
---@param path string
---@param contents string|table
---@param pretty_json? boolean
function M.write_file(path, contents, pretty_json)
    path = M.expand_path(path)
    if type(contents) == "table" then
        contents = json.encode(contents, pretty_json)
    end
    contents = tostring(contents)
    local parent = path:match("^(.*)/[^/]+$")
    if parent then
        local ok, lgi = pcall(require, "lgi")
        if ok and lgi.GLib and lgi.GLib.mkdir_with_parents then
            pcall(lgi.GLib.mkdir_with_parents, parent, 493)
        end
    end
    if ok_native and native and native.write_file_fast then
        local ok_w = native.write_file_fast(path, contents)
        if ok_w then return end
    end
    local f, err = io.open(path, "wb")
    if not f then
        error("Could not write file '" .. tostring(path) .. "': " .. tostring(err))
    end
    f:write(contents)
    f:close()
end

--- Read a file asynchronously via Gio.File:load_contents_async
---@param path string
---@param callback fun(content: any, err: any)
---@param decode_json? boolean
function M.read_file_async(path, callback, decode_json)
    path = M.expand_path(path)
    local ok, lgi = pcall(require, "lgi")
    if ok and lgi.Gio and lgi.Gio.File then
        local file = lgi.Gio.File.new_for_path(path)
        if file and file.load_contents_async then
            file:load_contents_async(nil, function(f_obj, res)
                local ok_load, bytes, err = pcall(function()
                    return f_obj:load_contents_finish(res)
                end)
                if ok_load and bytes then
                    local str = tostring(bytes)
                    if decode_json then
                        local ok_j, parsed = pcall(json.decode, str)
                        if ok_j then
                            callback(parsed, nil)
                        else
                            callback(nil, parsed)
                        end
                    else
                        callback(str, nil)
                    end
                else
                    callback(nil, err or bytes)
                end
            end)
            return
        end
    end
    local ok_sync, content = pcall(M.read_file, path, decode_json)
    if ok_sync then
        callback(content, nil)
    else
        callback(nil, content)
    end
end

--- Write a file asynchronously via Gio.File:replace_contents_async
---@param path string
---@param contents string|table
---@param callback? fun(ok: boolean, err: any)
---@param pretty_json? boolean
function M.write_file_async(path, contents, callback, pretty_json)
    path = M.expand_path(path)
    if type(contents) == "table" then
        contents = json.encode(contents, pretty_json)
    end
    contents = tostring(contents)
    local ok, lgi = pcall(require, "lgi")
    if ok and lgi.Gio and lgi.Gio.File then
        local file = lgi.Gio.File.new_for_path(path)
        if file and file.replace_contents_async then
            file:replace_contents_async(
                contents,
                nil,
                false,
                lgi.Gio.FileCreateFlags and lgi.Gio.FileCreateFlags.NONE or 0,
                nil,
                function(f_obj, res)
                    local ok_w, err = pcall(function()
                        return f_obj:replace_contents_finish(res)
                    end)
                    if callback then callback(ok_w, ok_w and nil or err) end
                end
            )
            return
        end
    end
    local ok_sync, err = pcall(M.write_file, path, contents)
    if callback then callback(ok_sync, err) end
end

return M
