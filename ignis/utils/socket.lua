local ok_native, native = pcall(require, "ignis.native")

local M = {}

function M.connect_unix_socket(path)
    local ok, lgi = pcall(require, "lgi")
    if not ok or not lgi.Gio or not lgi.Gio.SocketClient then
        return nil, "Gio.SocketClient is not available"
    end
    local Gio = lgi.Gio
    local client = Gio.SocketClient.new()
    local address = Gio.UnixSocketAddress.new(path)
    local conn, err = client:connect(address, nil)
    if not conn then
        return nil, tostring(err)
    end
    return conn, nil
end

function M.send_socket(path, message, timeout_ms)
    if ok_native and native and native.unix_request then
        local resp = native.unix_request(path, message or "", timeout_ms or 1500)
        if resp ~= nil then
            return resp, nil
        end
        return nil, "native unix_request failed"
    end

    local conn, err = M.connect_unix_socket(path)
    if not conn then
        return nil, err
    end

    local out_stream = conn:get_output_stream()
    local in_stream = conn:get_input_stream()
    local Gio = require("lgi").Gio

    local ok_write, write_err = pcall(function()
        out_stream:write_all(message, nil)
        out_stream:flush(nil)
    end)
    if not ok_write then
        pcall(function() conn:close(nil) end)
        return nil, tostring(write_err)
    end

    local data_in = Gio.DataInputStream.new(in_stream)
    local chunks = {}
    while true do
        local line = data_in:read_line_utf8(nil)
        if not line then break end
        table.insert(chunks, line)
    end

    pcall(function() conn:close(nil) end)
    return table.concat(chunks, "\n"), nil
end

function M.listen_socket(path, on_line, on_close)
    local conn, err = M.connect_unix_socket(path)
    if not conn then
        return nil, err
    end

    local lgi = require("lgi")
    local Gio = lgi.Gio
    local GLib = lgi.GLib

    local in_stream = conn:get_input_stream()
    local data_in = Gio.DataInputStream.new(in_stream)
    local closed = false

    local handle = {
        connection = conn,
        data_stream = data_in,
        close = function()
            closed = true
            pcall(function() conn:close(nil) end)
        end
    }

    local function read_next()
        if closed then return end
        data_in:read_line_async(GLib.PRIORITY_DEFAULT, nil, function(stream, res)
            local ok_line, line = pcall(function()
                return stream:read_line_finish_utf8(res)
            end)
            if ok_line and line then
                pcall(on_line, line)
                read_next()
            else
                closed = true
                pcall(function() conn:close(nil) end)
                if on_close then
                    pcall(on_close)
                end
            end
        end)
    end

    read_next()
    return handle, nil
end

return M
