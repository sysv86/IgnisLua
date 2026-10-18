local M = {}


local function strip_comments(text)
    local out = {}
    local i, n = 1, #text
    local line_comment, block_comment, quote = false, false, nil

    while i <= n do
        local c = text:sub(i, i)
        local c2 = text:sub(i + 1, i + 1)

        if line_comment then
            if c == "\n" then
                line_comment = false
                out[#out + 1] = c
            end
            i = i + 1
        elseif block_comment then
            if c == "*" and c2 == "/" then
                block_comment = false
                i = i + 2
            else
                if c == "\n" then out[#out + 1] = c end
                i = i + 1
            end
        elseif quote then
            out[#out + 1] = c
            if c == "\\" then
                out[#out + 1] = c2
                i = i + 2
            else
                if c == quote then quote = nil end
                i = i + 1
            end
        elseif c == "/" and c2 == "/" then
            line_comment = true
            i = i + 2
        elseif c == "/" and c2 == "*" then
            block_comment = true
            i = i + 2
        elseif c == '"' or c == "'" then
            quote = c
            out[#out + 1] = c
            i = i + 1
        else
            out[#out + 1] = c
            i = i + 1
        end
    end

    return table.concat(out)
end

local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_args(text)
    local args = {}
    if not text or trim(text) == "" then return args end
    local depth = 0
    local quote = nil
    local current = {}
    local i = 1
    while i <= #text do
        local c = text:sub(i, i)
        if quote then
            current[#current + 1] = c
            if c == "\\" then
                current[#current + 1] = text:sub(i + 1, i + 1)
                i = i + 1
            elseif c == quote then
                quote = nil
            end
        elseif c == '"' or c == "'" then
            quote = c
            current[#current + 1] = c
        elseif c == "(" then
            depth = depth + 1
            current[#current + 1] = c
        elseif c == ")" then
            depth = depth - 1
            current[#current + 1] = c
        elseif c == "," and depth == 0 then
            args[#args + 1] = trim(table.concat(current))
            current = {}
        else
            current[#current + 1] = c
        end
        i = i + 1
    end
    local last = trim(table.concat(current))
    if last ~= "" then
        args[#args + 1] = last
    end
    return args
end


local function parse(text)
    local nodes = {}
    local i, n = 1, #text

    local function skip_space()
        while i <= n do
            local c = text:sub(i, i)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then
                i = i + 1
            else
                break
            end
        end
    end

    local function read_until_delimiter()
        local buf = {}
        local depth = 0
        local quote = nil
        while i <= n do
            local c = text:sub(i, i)
            if quote then
                buf[#buf + 1] = c
                if c == "\\" then
                    buf[#buf + 1] = text:sub(i + 1, i + 1)
                    i = i + 1
                elseif c == quote then
                    quote = nil
                end
                i = i + 1
            elseif c == '"' or c == "'" then
                quote = c
                buf[#buf + 1] = c
                i = i + 1
            elseif c == "(" then
                depth = depth + 1
                buf[#buf + 1] = c
                i = i + 1
            elseif c == ")" then
                depth = math.max(0, depth - 1)
                buf[#buf + 1] = c
                i = i + 1
            elseif depth == 0 and (c == "{" or c == ";" or c == "}") then
                break
            else
                buf[#buf + 1] = c
                i = i + 1
            end
        end
        return table.concat(buf)
    end

    while i <= n do
        skip_space()
        if i > n then break end

        local head = read_until_delimiter()
        local delim = text:sub(i, i)
        local trimmed = trim(head)

        if delim == "{" then
            i = i + 1
            local body_start = i
            local depth = 1
            local quote = nil
            while i <= n and depth > 0 do
                local c = text:sub(i, i)
                if quote then
                    if c == "\\" then
                        i = i + 1
                    elseif c == quote then
                        quote = nil
                    end
                elseif c == '"' or c == "'" then
                    quote = c
                elseif c == "{" then
                    depth = depth + 1
                elseif c == "}" then
                    depth = depth - 1
                    if depth == 0 then break end
                end
                i = i + 1
            end
            local body = text:sub(body_start, i - 1)
            i = i + 1 -- consume `}`

            local children = parse(body)

            if trimmed:match("^@mixin%s+") then
                local mname, pargs = trimmed:match("^@mixin%s+([%w_%-]+)%s*%((.-)%)%s*$")
                if not mname then
                    mname = trimmed:match("^@mixin%s+([%w_%-]+)%s*$")
                    pargs = ""
                end
                local params = {}
                for _, raw_p in ipairs(split_args(pargs or "")) do
                    local pname, pdef = raw_p:match("^%$([%w_%-]+)%s*:%s*(.-)$")
                    if pname then
                        params[#params + 1] = { name = pname, default = trim(pdef) }
                    else
                        local bare = raw_p:match("^%$([%w_%-]+)$")
                        if bare then
                            params[#params + 1] = { name = bare, default = nil }
                        end
                    end
                end
                if mname then
                    nodes[#nodes + 1] = {
                        kind = "mixin",
                        name = mname,
                        params = params,
                        children = children,
                    }
                end
            elseif trimmed:match("^@") then
                local name, params = trimmed:match("^@([%w%-]+)%s*(.-)$")
                nodes[#nodes + 1] = {
                    kind = "atrule",
                    name = name or trimmed,
                    params = params or "",
                    children = children,
                }
            else
                local selectors = {}
                for raw_sel in trimmed:gmatch("[^,]+") do
                    local sel = trim(raw_sel):gsub("%s+", " ")
                    if sel ~= "" then selectors[#selectors + 1] = sel end
                end
                nodes[#nodes + 1] = { kind = "rule", selectors = selectors, children = children }
            end
        elseif delim == ";" then
            i = i + 1
            if trimmed ~= "" then
                local use_path, use_as = trimmed:match('^@use%s+"([^"]+)"%s*as%s+([%w_%-%*]+)')
                if not use_path then
                    use_path, use_as = trimmed:match("^@use%s+'([^']+)'%s*as%s+([%w_%-%*]+)")
                end
                if not use_path then
                    use_path = trimmed:match('^@use%s+"([^"]+)"')
                        or trimmed:match("^@use%s+'([^']+)'")
                end
                local import_path = trimmed:match('^@import%s+"([^"]+)"')
                    or trimmed:match("^@import%s+'([^']+)'")
                local inc_name, inc_args = trimmed:match("^@include%s+([%w_%-]+)%s*%((.-)%)%s*$")
                if not inc_name then
                    inc_name = trimmed:match("^@include%s+([%w_%-]+)%s*$")
                    inc_args = ""
                end
                local var_name, var_value = trimmed:match("^%$([%w%-_]+)%s*:%s*(.-)$")

                if use_path then
                    nodes[#nodes + 1] = { kind = "use", path = use_path, as = use_as }
                elseif import_path then
                    nodes[#nodes + 1] = { kind = "use", path = import_path, as = "*" }
                elseif inc_name then
                    nodes[#nodes + 1] = {
                        kind = "include",
                        name = inc_name,
                        args = split_args(inc_args or ""),
                    }
                elseif var_name then
                    nodes[#nodes + 1] = { kind = "var", name = var_name, value = trim(var_value):gsub("%s*!default$", "") }
                elseif trimmed:match("^@") then
                    local name, params = trimmed:match("^@([%w%-]+)%s*(.-)$")
                    nodes[#nodes + 1] = { kind = "atrule", name = name, params = params or "", children = {} }
                else
                    local prop, value = trimmed:match("^([%w%-]+)%s*:%s*(.-)$")
                    if prop then
                        nodes[#nodes + 1] = { kind = "decl", prop = prop, value = trim(value):gsub("%s+", " ") }
                    end
                end
            end
        elseif delim == "}" then
            break
        else
            if trimmed ~= "" then
                local prop, value = trimmed:match("^([%w%-]+)%s*:%s*(.-)$")
                if prop then
                    nodes[#nodes + 1] = { kind = "decl", prop = prop, value = trim(value):gsub("%s+", " ") }
                end
            end
        end
    end

    return nodes
end


local function expand_hex_color(hex)
    if #hex == 3 then
        return tonumber(hex:sub(1, 1) .. hex:sub(1, 1), 16),
            tonumber(hex:sub(2, 2) .. hex:sub(2, 2), 16),
            tonumber(hex:sub(3, 3) .. hex:sub(3, 3), 16)
    end
    return tonumber(hex:sub(1, 2), 16),
        tonumber(hex:sub(3, 4), 16),
        tonumber(hex:sub(5, 6), 16)
end

local function rgb_to_hex(r, g, b)
    local function clamp(v)
        v = math.floor(v + 0.5)
        if v < 0 then v = 0 elseif v > 255 then v = 255 end
        return v
    end
    return string.format("#%02x%02x%02x", clamp(r), clamp(g), clamp(b))
end

local function rgb_to_hsl(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local l = (max + min) / 2
    local h, s = 0, 0
    if max ~= min then
        local d = max - min
        s = l > 0.5 and (d / (2 - max - min)) or (d / (max + min))
        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end
    return h * 360, s, l
end

local function hsl_to_rgb(h, s, l)
    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 elseif t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    h = (h % 360) / 360
    if s == 0 then
        return l * 255, l * 255, l * 255
    end
    local q = l < 0.5 and (l * (1 + s)) or (l + s - l * s)
    local p = 2 * l - q
    return hue2rgb(p, q, h + 1 / 3) * 255,
        hue2rgb(p, q, h) * 255,
        hue2rgb(p, q, h - 1 / 3) * 255
end

local function find_call(value, name, from)
    local s, e = value:find(name .. "%s*%(", from or 1)
    if not s then return nil end
    local depth = 0
    local quote = nil
    local i = e
    while i <= #value do
        local c = value:sub(i, i)
        if quote then
            if c == "\\" then i = i + 1 elseif c == quote then quote = nil end
        elseif c == '"' or c == "'" then
            quote = c
        elseif c == "(" then
            depth = depth + 1
        elseif c == ")" then
            depth = depth - 1
            if depth == 0 then
                return s, i, value:sub(e + 1, i - 1)
            end
        end
        i = i + 1
    end
    return nil
end

--- Supports both positional `mix($c1, $c2, 10%)` and named `mix($c1, $c2, $weight: 92%, $method: hsl)`
local function eval_mix(args_text)
    local args = split_args(args_text)
    if #args < 2 then return nil end

    local function color_of(text)
        local hex = text:match("#(%x%x%x%x%x%x)")
            or text:match("#(%x%x%x)")
        if hex then
            return { expand_hex_color(hex) }
        end
        local r, g, b = text:match("rgba?%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
        if r and g and b then
            return { tonumber(r), tonumber(g), tonumber(b) }
        end
        return nil
    end

    local c1 = color_of(args[1] or "")
    local c2 = color_of(args[2] or "")
    if not c1 or not c2 then return nil end

    local weight = 0.5
    local method = "rgb"
    for i = 3, #args do
        local arg_i = trim(args[i])
        local w_named = arg_i:match("%$?weight%s*:%s*([%d%.]+)%%?")
        local m_named = arg_i:match("%$?method%s*:%s*([%a]+)")
        local w_pos = arg_i:match("^([%d%.]+)%%?$")
        if w_named then
            weight = tonumber(w_named) / 100.0
        elseif m_named then
            method = m_named
        elseif w_pos then
            local num = tonumber(w_pos)
            if num then
                weight = (num > 1.0 or arg_i:find("%%")) and (num / 100.0) or num
            end
        end
    end

    if method == "hsl" then
        local h1, s1, l1 = rgb_to_hsl(c1[1], c1[2], c1[3])
        local h2, s2, l2 = rgb_to_hsl(c2[1], c2[2], c2[3])
        local h = h1 * weight + h2 * (1 - weight)
        local s = s1 * weight + s2 * (1 - weight)
        local l = l1 * weight + l2 * (1 - weight)
        return rgb_to_hex(hsl_to_rgb(h, s, l))
    end

    return rgb_to_hex(
        c1[1] * weight + c2[1] * (1 - weight),
        c1[2] * weight + c2[2] * (1 - weight),
        c1[3] * weight + c2[3] * (1 - weight)
    )
end

local function evaluate_functions(value)
    local guard = 0
    while true do
        guard = guard + 1
        if guard > 64 then break end
        local s, e, inner = find_call(value, "mix")
        if not s then break end
        local result = eval_mix(inner)
        if not result then
            break
        end
        value = value:sub(1, s - 1) .. result .. value:sub(e + 1)
    end
    return value
end

local NAMED_COLORS = {
    aliceblue = 0xF0F8FF, antiquewhite = 0xFAEBD7, aqua = 0x00FFFF, aquamarine = 0x7FFFD4,
    azure = 0xF0FFFF, beige = 0xF5F5DC, bisque = 0xFFE4C4, black = 0x000000,
    blanchedalmond = 0xFFEBCD, blue = 0x0000FF, blueviolet = 0x8A2BE2, brown = 0xA52A2A,
    burlywood = 0xDEB887, cadetblue = 0x5F9EA0, chartreuse = 0x7FFF00, chocolate = 0xD2691E,
    coral = 0xFF7F50, cornflowerblue = 0x6495ED, cornsilk = 0xFFF8DC, crimson = 0xDC143C,
    cyan = 0x00FFFF, darkblue = 0x00008B, darkcyan = 0x008B8B, darkgoldenrod = 0xB8860B,
    darkgray = 0xA9A9A9, darkgreen = 0x006400, darkgrey = 0xA9A9A9, darkkhaki = 0xBDB76B,
    darkmagenta = 0x8B008B, darkolivegreen = 0x556B2F, darkorange = 0xFF8C00, darkorchid = 0x9932CC,
    darkred = 0x8B0000, darksalmon = 0xE9967A, darkseagreen = 0x8FBC8F, darkslateblue = 0x483D8B,
    darkslategray = 0x2F4F4F, darkslategrey = 0x2F4F4F, darkturquoise = 0x00CED1, darkviolet = 0x9400D3,
    deeppink = 0xFF1493, deepskyblue = 0x00BFFF, dimgray = 0x696969, dimgrey = 0x696969,
    dodgerblue = 0x1E90FF, firebrick = 0xB22222, floralwhite = 0xFFFAF0, forestgreen = 0x228B22,
    fuchsia = 0xFF00FF, gainsboro = 0xDCDCDC, ghostwhite = 0xF8F8FF, gold = 0xFFD700,
    goldenrod = 0xDAA520, gray = 0x808080, green = 0x008000, greenyellow = 0xADFF2F,
    grey = 0x808080, honeydew = 0xF0FFF0, hotpink = 0xFF69B4, indianred = 0xCD5C5C,
    indigo = 0x4B0082, ivory = 0xFFFFF0, khaki = 0xF0E68C, lavender = 0xE6E6FA,
    lavenderblush = 0xFFF0F5, lawngreen = 0x7CFC00, lemonchiffon = 0xFFFACD, lightblue = 0xADD8E6,
    lightcoral = 0xF08080, lightcyan = 0xE0FFFF, lightgoldenrodyellow = 0xFAFAD2, lightgray = 0xD3D3D3,
    lightgreen = 0x90EE90, lightgrey = 0xD3D3D3, lightpink = 0xFFB6C1, lightsalmon = 0xFFA07A,
    lightseagreen = 0x20B2AA, lightskyblue = 0x87CEFA, lightslategray = 0x778899, lightslategrey = 0x778899,
    lightsteelblue = 0xB0C4DE, lightyellow = 0xFFFFE0, lime = 0x00FF00, limegreen = 0x32CD32,
    linen = 0xFAF0E6, magenta = 0xFF00FF, maroon = 0x800080, mediumaquamarine = 0x66CDAA,
    mediumblue = 0x0000CD, mediumorchid = 0xBA55D3, mediumpurple = 0x9370DB, mediumseagreen = 0x3CB371,
    mediumslateblue = 0x7B68EE, mediumspringgreen = 0x00FA9A, mediumturquoise = 0x48D1CC, mediumvioletred = 0xC71585,
    midnightblue = 0x191970, mintcream = 0xF5FFFA, mistyrose = 0xFFE4E1, moccasin = 0xFFE4B5,
    navajowhite = 0xFFDEAD, navy = 0x000080, oldlace = 0xFDF5E6, olive = 0x808000,
    olivedrab = 0x6B8E23, orange = 0xFFA500, orangered = 0xFF4500, orchid = 0xDA70D6,
    palegoldenrod = 0xEEE8AA, palegreen = 0x98FB98, paleturquoise = 0xAFEEEE, palevioletred = 0xDB7093,
    papayawhip = 0xFFEFD5, peachpuff = 0xFFDAB9, peru = 0xCD853F, pink = 0xFFC0CB,
    plum = 0xDDA0DD, powderblue = 0xB0E0E6, purple = 0x800080, rebeccapurple = 0x663399,
    red = 0xFF0000, rosybrown = 0xBC8F8F, royalblue = 0x4169E1, saddlebrown = 0x8B4513,
    salmon = 0xFA8072, sandybrown = 0xF4A460, seagreen = 0x2E8B57, seashell = 0xFFF5EE,
    sienna = 0xA0522D, silver = 0xC0C0C0, skyblue = 0x87CEEB, slateblue = 0x6A5ACD,
    slategray = 0x708090, slategrey = 0x708090, snow = 0xFFFAFA, springgreen = 0x00FF7F,
    steelblue = 0x4682B4, tan = 0xD2B48C, teal = 0x008080, thistle = 0xD8BFD8,
    tomato = 0xFF6347, turquoise = 0x40E0D0, violet = 0xEE82EE, wheat = 0xF5DEB3,
    white = 0xFFFFFF, whitesmoke = 0xF5F5F5, yellow = 0xFFFF00, yellowgreen = 0x9ACD32,
}

local function named_to_components(name)
    local rgb = NAMED_COLORS[name:lower()]
    if not rgb then return nil end
    return math.floor(rgb / 0x10000) % 0x100,
        math.floor(rgb / 0x100) % 0x100,
        rgb % 0x100
end

local function normalise_color_functions(value)
    local function repl_hex(hex, a)
        local r, g, b = expand_hex_color(hex)
        return string.format("rgba(%d, %d, %d, %s)", r, g, b, a)
    end
    value = value:gsub("rgba%(%s*#(%x%x%x%x%x%x)%s*,%s*([%d%.]+)%s*%)", repl_hex)
    value = value:gsub("rgba%(%s*#(%x%x%x)%s*,%s*([%d%.]+)%s*%)", repl_hex)

    value = value:gsub("rgba%(%s*([%a]+)%s*,%s*([%d%.]+)%s*%)", function(name, a)
        local r, g, b = named_to_components(name)
        if not r then return nil end
        return string.format("rgba(%d, %d, %d, %s)", r, g, b, a)
    end)
    value = value:gsub("rgb%(%s*([%a]+)%s*%)", function(name)
        local r, g, b = named_to_components(name)
        if not r then return nil end
        return string.format("rgb(%d, %d, %d)", r, g, b)
    end)

    return value
end

local DROP_TRANSITIONS = os.getenv("IGNIS_SCSS_NO_TRANSITIONS") ~= nil

local function alt_var_key(name)
    if name:find("_") then
        return (name:gsub("_(%a)", function(c) return c:upper() end))
    else
        return (name:gsub("(%u)", function(c) return "_" .. c:lower() end))
    end
end

local function lookup_var(map, name)
    if not map then return nil end
    if map[name] ~= nil then return map[name] end
    local dash_to_under = name:gsub("%-", "_")
    if map[dash_to_under] ~= nil then return map[dash_to_under] end
    local under_to_dash = name:gsub("_", "-")
    if map[under_to_dash] ~= nil then return map[under_to_dash] end
    local alt = alt_var_key(dash_to_under)
    if map[alt] ~= nil then return map[alt] end
    return nil
end

local function substitute(value, scopes, extra_vars)
    local local_vars = scopes.vars or {}
    local modules = scopes.modules or {}

    value = value:gsub("([%w_%-]+)%.%$([%w_%-]+)", function(ns, name)
        local mod = modules[ns]
        local resolved = lookup_var(mod, name)
        return resolved or (ns .. ".$" .. name)
    end)

    value = value:gsub("%$([%w_%-]+)", function(name)
        local resolved = lookup_var(extra_vars, name) or lookup_var(local_vars, name)
        if not resolved then
            for _, mod in pairs(modules) do
                resolved = lookup_var(mod, name)
                if resolved then break end
            end
        end
        return resolved or ("$" .. name)
    end)

    value = evaluate_functions(value)

    return normalise_color_functions(value)
end


local function dirname(path)
    return path:match("^(.*)/[^/]+$") or "."
end

local function basename_no_ext(path)
    local name = path:match("([^/]+)$") or path
    return (name:gsub("%.s?css$", ""))
end

local function resolve_use_path(from_file, spec)
    local base
    if spec:sub(1, 1) == "/" then
        base = spec
    else
        base = dirname(from_file) .. "/" .. spec
    end
    if not base:match("%.s?css$") then
        base = base .. ".scss"
    end
    while base:find("/[^/]+/%.%./") do
        base = base:gsub("/[^/]+/%.%./", "/", 1)
    end
    base = base:gsub("/%./", "/")
    return base
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function clone_nodes_with_vars(nodes, scopes, arg_vars)
    local out = {}
    for _, node in ipairs(nodes or {}) do
        if node.kind == "decl" then
            out[#out + 1] = {
                kind = "decl",
                prop = node.prop,
                value = substitute(node.value, scopes, arg_vars),
            }
        elseif node.kind == "var" then
            local val = substitute(node.value, scopes, arg_vars)
            arg_vars[node.name] = val
        elseif node.kind == "include" then
            local new_args = {}
            for i, a in ipairs(node.args or {}) do
                new_args[i] = substitute(a, scopes, arg_vars)
            end
            out[#out + 1] = {
                kind = "include",
                name = node.name,
                args = new_args,
            }
        elseif node.kind == "rule" then
            out[#out + 1] = {
                kind = "rule",
                selectors = node.selectors,
                children = clone_nodes_with_vars(node.children, scopes, arg_vars),
            }
        else
            out[#out + 1] = node
        end
    end
    return out
end

local function compile_source(text, file_path, state)
    local root = parse(strip_comments(text))
    local scopes = { vars = {}, modules = {}, mixins = {} }
    local exports = {}
    local exported_mixins = {}

    local function expand_mixin(inc_node)
        local mixin = scopes.mixins[inc_node.name]
        if not mixin then return {} end
        local arg_vars = {}
        local params = mixin.params or {}
        local call_args = inc_node.args or {}

        for idx, param in ipairs(params) do
            if param.default then
                arg_vars[param.name] = substitute(param.default, scopes)
            end
            if call_args[idx] and not call_args[idx]:find("^%$?[%w_%-]+%s*:") then
                arg_vars[param.name] = substitute(call_args[idx], scopes)
            end
        end
        for _, raw_arg in ipairs(call_args) do
            local k, v = raw_arg:match("^%$?([%w_%-]+)%s*:%s*(.-)$")
            if k and v then
                arg_vars[k] = substitute(v, scopes)
            end
        end

        return clone_nodes_with_vars(mixin.children, scopes, arg_vars)
    end

    local function render(nodes, parent_selectors)
        local lines = {}

        local function push_rule(selectors, body)
            if #selectors == 0 or #body == 0 then return end
            lines[#lines + 1] = table.concat(selectors, ",\n") .. " {\n"
            for _, decl in ipairs(body) do
                lines[#lines + 1] = "    " .. decl .. "\n"
            end
            lines[#lines + 1] = "}\n"
        end

        local i = 1
        while i <= #nodes do
            local node = nodes[i]
            i = i + 1

            if node.kind == "decl" then
            elseif node.kind == "var" then
                local val = substitute(node.value, scopes)
                scopes.vars[node.name] = val
                exports[node.name] = val
            elseif node.kind == "mixin" then
                scopes.mixins[node.name] = node
                exported_mixins[node.name] = node
            elseif node.kind == "include" then
                local expanded = expand_mixin(node)
                for j = #expanded, 1, -1 do
                    table.insert(nodes, i, expanded[j])
                end
            elseif node.kind == "use" then
                local resolved = resolve_use_path(file_path, node.path)
                local ns = (node.as and node.as ~= "*") and node.as or basename_no_ext(resolved)
                local module_vars, module_css, module_mixins = state.load(resolved)
                scopes.modules[ns] = scopes.modules[ns] or {}
                for k, v in pairs(module_vars or {}) do
                    local sub_v = substitute(v, scopes)
                    scopes.modules[ns][k] = sub_v
                    if node.as == "*" or scopes.vars[k] == nil then
                        scopes.vars[k] = sub_v
                        exports[k] = sub_v
                    end
                end
                for mk, mv in pairs(module_mixins or {}) do
                    scopes.mixins[mk] = mv
                    exported_mixins[mk] = mv
                end
                if module_css and module_css ~= "" then
                    lines[#lines + 1] = module_css
                end
            elseif node.kind == "atrule" then
                local name = node.name or ""
                if name == "keyframes" or name == "media" or name == "supports" then
                    local inner = render(node.children, nil)
                    if #inner > 0 then
                        lines[#lines + 1] = "@" .. name
                            .. (node.params ~= "" and (" " .. node.params) or "")
                            .. " {\n"
                        for _, line in ipairs(inner) do
                            lines[#lines + 1] = "    " .. line
                        end
                        lines[#lines + 1] = "}\n"
                    end
                else
                    if node.params ~= "" then
                        lines[#lines + 1] = "@" .. name .. " " .. node.params .. ";\n"
                    end
                end
            elseif node.kind == "rule" then
                local decls = {}
                local nested = {}
                local child_list = {}
                for idx_c, ch in ipairs(node.children) do
                    child_list[idx_c] = ch
                end

                local ci = 1
                while ci <= #child_list do
                    local child = child_list[ci]
                    ci = ci + 1
                    if child.kind == "include" then
                        local exp = expand_mixin(child)
                        for j = #exp, 1, -1 do
                            table.insert(child_list, ci, exp[j])
                        end
                    elseif child.kind == "decl" then
                        local value = substitute(child.value, scopes)
                        local skip_transition = DROP_TRANSITIONS
                            and (child.prop:match("^transition") ~= nil
                                or child.prop:match("^animation") ~= nil)
                        if not skip_transition and not value:find("%$") and not value:find("mix%(") then
                            decls[#decls + 1] = child.prop .. ": " .. value .. ";"
                        end
                    elseif child.kind == "var" then
                        local val = substitute(child.value, scopes)
                        scopes.vars[child.name] = val
                        exports[child.name] = val
                    elseif child.kind == "mixin" then
                        scopes.mixins[child.name] = child
                    else
                        nested[#nested + 1] = child
                    end
                end

                local full = {}
                if parent_selectors then
                    for _, parent in ipairs(parent_selectors) do
                        for _, sel in ipairs(node.selectors) do
                            if sel:find("&", 1, true) then
                                full[#full + 1] = (sel:gsub("&", parent))
                            else
                                full[#full + 1] = parent .. " " .. sel
                            end
                        end
                    end
                else
                    full = node.selectors
                end

                push_rule(full, decls)
                if #nested > 0 then
                    for _, line in ipairs(render(nested, full)) do
                        lines[#lines + 1] = line
                    end
                end
            end
        end

        return lines
    end

    local chunks = render(root, nil)
    return table.concat(chunks), exports, exported_mixins
end

---@param path string
---@return string css
function M.compile_file(path)
    local state = { emitted = {}, cache = {} }

    function state.load(file_path)
        local cached = state.cache[file_path]
        if cached then return cached.vars, "", cached.mixins end

        local content = read_file(file_path)
        if not content then
            local empty = { vars = {}, css = "", mixins = {} }
            state.cache[file_path] = empty
            return empty.vars, "", empty.mixins
        end

        local css, vars, mixins
        if state.emitted[file_path] then
            local _, v, mx = compile_source(content, file_path, state)
            css, vars, mixins = "", v, mx
        else
            state.emitted[file_path] = true
            css, vars, mixins = compile_source(content, file_path, state)
        end

        state.cache[file_path] = { vars = vars, css = css, mixins = mixins }
        return vars, css, mixins
    end

    local content = read_file(path)
    if not content then
        error("Could not open SCSS file: " .. tostring(path))
    end
    state.emitted[path] = true
    local css = compile_source(content, path, state)
    return css
end

---@param text string
---@param file_path? string
---@return string css
function M.compile_string(text, file_path)
    local state = { emitted = {}, cache = {} }
    function state.load()
        return {}, "", {}
    end
    return (compile_source(text, file_path or "/tmp/ignis-inline.scss", state))
end

return M