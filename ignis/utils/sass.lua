local exceptions = require("ignis.exceptions")
local lgi = require("lgi")
local GLib = lgi.GLib

local M = {}

local compilers = {}
for _, cmd in ipairs({"sass", "grass"}) do
    local path = GLib.find_program_in_path(cmd)
    if path then
        compilers[cmd] = path
    end
end

local function get_temp_dir()
    local ignis = package.loaded["ignis"]
    local temp_dir = ignis and ignis._temp_dir
    if not temp_dir then
        temp_dir = GLib.dir_make_tmp("ignis-XXXXXX")
        if ignis then
            ignis._temp_dir = temp_dir
        else
            M._temp_dir = temp_dir
        end
    end
    return temp_dir
end

M.get_temp_dir = get_temp_dir

function M.sass_compile(opts)
    opts = opts or {}
    local path = opts.path
    local str_input = opts.string
    local compiler = opts.compiler
    local extra_args = opts.extra_args or {}

    local force_external = (compiler ~= nil) or (os.getenv("IGNIS_EXTERNAL_SASS") == "1")
    local is_indented_sass = path and path:match("%.sass$") ~= nil

    if not force_external and not is_indented_sass then
        local scss = require("ignis.utils.scss")
        if path then
            local ok, css = pcall(scss.compile_file, path)
            if ok and css then
                return css
            end
        elseif str_input then
            local ok, css = pcall(scss.compile_string, str_input)
            if ok and css then
                return css
            end
        end
    end

    if not next(compilers) then
        local scss = require("ignis.utils.scss")
        if path then
            return scss.compile_file(path)
        elseif str_input then
            return scss.compile_string(str_input)
        end
        error("sass_compile() requires either path or string as argument options")
    end

    local compiler_path
    if compiler then
        compiler_path = compilers[compiler]
        if not compiler_path then
            error(exceptions.SassNotFoundError())
        end
    else
        for _, p in pairs(compilers) do
            compiler_path = p
            break
        end
    end

    local args_table = {}
    for _, arg in ipairs(extra_args) do
        table.insert(args_table, arg)
    end
    local args_str = table.concat(args_table, " ")

    if path or str_input then
        local src_path = path
        local is_temp_src = false
        local temp_dir = get_temp_dir()

        if str_input then
            is_temp_src = true
            src_path = temp_dir .. "/temp_src.scss"
            local f = io.open(src_path, "w")
            if not f then
                error(exceptions.SassCompilationError("Failed to write temporary SASS file"))
            end
            f:write(str_input)
            f:close()
        end

        local dest_path = temp_dir .. "/compiled.css"
        local cmd = string.format("%s %q %q %s 2>&1", compiler_path, src_path, dest_path, args_str)
        local p = io.popen(cmd)
        if not p then
            error(exceptions.SassCompilationError("Failed to execute SASS compiler"))
        end
        local output = p:read("*all")
        local success = p:close()

        if is_temp_src then
            os.remove(src_path)
        end

        if not success then
            error(exceptions.SassCompilationError(output))
        end

        local f = io.open(dest_path, "r")
        if not f then
            error(exceptions.SassCompilationError("Compiled CSS file not found"))
        end
        local css = f:read("*all")
        f:close()
        os.remove(dest_path)
        return css
    else
        error("sass_compile() requires either path or string as argument options")
    end
end

return M
