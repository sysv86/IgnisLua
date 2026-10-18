local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local Gio = lgi.Gio
local gobject = require("ignis.gobject")

local FileDialog = gobject.class(gobject.Object, {
    init = function(self, props)
        props = props or {}
        self._dialog = Gtk.FileDialog.new()
        self._select_folder = props.select_folder or false
        self._multiple = props.multiple or false
        self._on_file_set = props.on_file_set
        self._initial_path = nil

        if props.title then self._dialog:set_title(props.title) end
        if props.modal ~= nil then self._dialog:set_modal(props.modal) end
        if props.accept_label then self._dialog:set_accept_label(props.accept_label) end
        if props.initial_path then self:set_initial_path(props.initial_path) end
    end,

    properties = {
        select_folder = {
            get = function(self) return self._select_folder end,
            set = function(self, val) self._select_folder = val end
        },
        multiple = {
            get = function(self) return self._multiple end,
            set = function(self, val) self._multiple = val end
        },
        initial_path = {
            get = function(self) return self._initial_path end,
            set = function(self, path)
                self._initial_path = path
                if path then
                    local file = Gio.File.new_for_path(path)
                    local is_dir = false
                    local ok, info = pcall(function()
                        return file:query_info("standard::type", Gio.FileQueryInfoFlags.NONE, nil)
                    end)
                    if ok and info and info:get_file_type() == Gio.FileType.DIRECTORY then
                        is_dir = true
                    end
                    if is_dir then
                        self._dialog:set_initial_folder(file)
                    else
                        self._dialog:set_initial_file(file)
                    end
                end
            end
        },
        on_file_set = {
            get = function(self) return self._on_file_set end,
            set = function(self, cb) self._on_file_set = cb end
        }
    },

    show = function(self, parent_window)
        local d = self._dialog
        if self._select_folder then
            d:select_folder(parent_window, nil, function(obj, res)
                local ok, file = pcall(function() return obj:select_folder_finish(res) end)
                if ok and file then
                    local path = file:get_path()
                    self:emit("file-set", file, path)
                    if self._on_file_set then self._on_file_set(self, file, path) end
                end
            end)
        else
            d:open(parent_window, nil, function(obj, res)
                local ok, file = pcall(function() return obj:open_finish(res) end)
                if ok and file then
                    local path = file:get_path()
                    self:emit("file-set", file, path)
                    if self._on_file_set then self._on_file_set(self, file, path) end
                end
            end)
        end
    end
})

return FileDialog
