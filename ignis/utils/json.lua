local M = {}

local escape_char_map = {
    ["\\"] = "\\\\",
    ['"']  = '\\"',
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
}

local escape_char_map_inv = {
    ["\\"] = "\\",
    ['"']  = '"',
    ["/"]  = "/",
    ["b"]  = "\b",
    ["f"]  = "\f",
    ["n"]  = "\n",
    ["r"]  = "\r",
    ["t"]  = "\t",
}

local function escape_char(c)
    return escape_char_map[c] or string.format("\\u%04x", c:byte())
end

local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local function is_array(t)
    local count = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
            return false, 0
        end
        count = count + 1
    end
    for i = 1, count do
        if rawget(t, i) == nil then
            return false, 0
        end
    end
    return true, count
end

local encode_value

local function encode_table(val, stack, indent, level)
    if stack[val] then
        error("Circular reference in JSON table")
    end
    stack[val] = true

    local arr, len = is_array(val)
    local res = {}
    local nl = indent and "\n" or ""
    local pad = indent and string.rep(indent, level + 1) or ""
    local close_pad = indent and string.rep(indent, level) or ""
    local sep = indent and ": " or ":"

    if arr then
        if len == 0 then
            stack[val] = nil
            return "[]"
        end
        for i = 1, len do
            res[i] = pad .. encode_value(val[i], stack, indent, level + 1)
        end
        stack[val] = nil
        return "[" .. nl .. table.concat(res, "," .. nl) .. nl .. close_pad .. "]"
    else
        local keys = {}
        for k, _ in pairs(val) do
            if type(k) == "string" or type(k) == "number" then
                table.insert(keys, k)
            end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        if #keys == 0 then
            stack[val] = nil
            return "{}"
        end
        for i, k in ipairs(keys) do
            res[i] = pad .. encode_string(tostring(k)) .. sep .. encode_value(val[k], stack, indent, level + 1)
        end
        stack[val] = nil
        return "{" .. nl .. table.concat(res, "," .. nl) .. nl .. close_pad .. "}"
    end
end

encode_value = function(val, stack, indent, level)
    local t = type(val)
    if val == nil or val == M.null then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        if val ~= val or val <= -math.huge or val >= math.huge then
            return "null"
        end
        if math.type and math.type(val) == "integer" then
            return tostring(val)
        end
        return string.format("%.14g", val)
    elseif t == "string" then
        return encode_string(val)
    elseif t == "table" then
        return encode_table(val, stack, indent, level)
    else
        error("Unsupported JSON value type: " .. t)
    end
end

M.null = setmetatable({}, { __tostring = function() return "null" end })

function M.encode(val, pretty)
    local indent = pretty and "  " or nil
    return encode_value(val, {}, indent, 0)
end

local function codepoint_to_utf8(n)
    if n <= 0x7f then
        return string.char(n)
    elseif n <= 0x7ff then
        return string.char(math.floor(n / 64) + 192, n % 64 + 128)
    elseif n <= 0xffff then
        return string.char(math.floor(n / 4096) + 224, math.floor(n % 4096 / 64) + 128, n % 64 + 128)
    elseif n <= 0x10ffff then
        return string.char(
            math.floor(n / 262144) + 240,
            math.floor(n % 262144 / 4096) + 128,
            math.floor(n % 4096 / 64) + 128,
            n % 64 + 128
        )
    end
    return ""
end

local function skip_whitespace(str, idx)
    local _, next_idx = str:find("^[ \n\r\t]*", idx)
    return (next_idx or idx - 1) + 1
end

local parse_value

local function parse_string(str, idx)
    local i = idx + 1
    local chunks = {}
    local start = i
    local len = #str

    while i <= len do
        local c = str:sub(i, i)
        if c == '"' then
            if i > start then
                table.insert(chunks, str:sub(start, i - 1))
            end
            return table.concat(chunks), i + 1
        elseif c == "\\" then
            if i > start then
                table.insert(chunks, str:sub(start, i - 1))
            end
            local esc = str:sub(i + 1, i + 1)
            if esc == "u" then
                local hex = str:sub(i + 2, i + 5)
                local cp = tonumber(hex, 16)
                if not cp then
                    error("Invalid unicode escape at position " .. i)
                end
                if cp >= 0xD800 and cp <= 0xDBFF and str:sub(i + 6, i + 7) == "\\u" then
                    local low = tonumber(str:sub(i + 8, i + 11), 16)
                    if low and low >= 0xDC00 and low <= 0xDFFF then
                        cp = 0x10000 + (cp - 0xD800) * 0x400 + (low - 0xDC00)
                        i = i + 6
                    end
                end
                table.insert(chunks, codepoint_to_utf8(cp))
                i = i + 6
            else
                local mapped = escape_char_map_inv[esc]
                if not mapped then
                    error("Invalid escape char '" .. esc .. "' at position " .. i)
                end
                table.insert(chunks, mapped)
                i = i + 2
            end
            start = i
        else
            i = i + 1
        end
    end
    error("Unterminated string starting at position " .. idx)
end

local function parse_number(str, idx)
    local _, end_idx, num_str = str:find("^(-?%d+%.?%d*[eE]?[%+%-]?%d*)", idx)
    local n = tonumber(num_str)
    if not n then
        error("Invalid number at position " .. idx)
    end
    return n, end_idx + 1
end

local function parse_array(str, idx)
    local res = {}
    local i = skip_whitespace(str, idx + 1)
    if str:sub(i, i) == "]" then
        return res, i + 1
    end
    local n = 1
    while true do
        local val
        val, i = parse_value(str, i)
        res[n] = val
        n = n + 1
        i = skip_whitespace(str, i)
        local c = str:sub(i, i)
        if c == "]" then
            return res, i + 1
        elseif c == "," then
            i = skip_whitespace(str, i + 1)
        else
            error("Expected ',' or ']' in array at position " .. i)
        end
    end
end

local function parse_object(str, idx)
    local res = {}
    local i = skip_whitespace(str, idx + 1)
    if str:sub(i, i) == "}" then
        return res, i + 1
    end
    while true do
        if str:sub(i, i) ~= '"' then
            error("Expected string key at position " .. i)
        end
        local key, val
        key, i = parse_string(str, i)
        i = skip_whitespace(str, i)
        if str:sub(i, i) ~= ":" then
            error("Expected ':' after key at position " .. i)
        end
        i = skip_whitespace(str, i + 1)
        val, i = parse_value(str, i)
        res[key] = val
        i = skip_whitespace(str, i)
        local c = str:sub(i, i)
        if c == "}" then
            return res, i + 1
        elseif c == "," then
            i = skip_whitespace(str, i + 1)
        else
            error("Expected ',' or '}' in object at position " .. i)
        end
    end
end

parse_value = function(str, idx)
    idx = skip_whitespace(str, idx)
    local c = str:sub(idx, idx)
    if c == '"' then
        return parse_string(str, idx)
    elseif c == "{" then
        return parse_object(str, idx)
    elseif c == "[" then
        return parse_array(str, idx)
    elseif c == "t" and str:sub(idx, idx + 3) == "true" then
        return true, idx + 4
    elseif c == "f" and str:sub(idx, idx + 4) == "false" then
        return false, idx + 5
    elseif c == "n" and str:sub(idx, idx + 3) == "null" then
        return nil, idx + 4
    elseif c == "-" or (c >= "0" and c <= "9") then
        return parse_number(str, idx)
    else
        error("Unexpected character '" .. tostring(c) .. "' at position " .. tostring(idx))
    end
end

function M.decode(str)
    if type(str) ~= "string" or str == "" then
        error("JSON decode expects a non-empty string")
    end
    local res, idx = parse_value(str, 1)
    idx = skip_whitespace(str, idx)
    if idx <= #str then
        error("Trailing characters in JSON at position " .. idx)
    end
    return res
end

return M
