local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local Gdk = lgi.require("Gdk", "4.0")
local gobject = require("ignis.gobject")

local IconManager = gobject.class(gobject.Object, {
    init = function(self)
    end,

    add_icons = function(self, path)
        local display = Gdk.Display.get_default()
        if display then
            local icon_theme = Gtk.IconTheme.get_for_display(display)
            icon_theme:add_search_path(path)
        end
    end
})

local default_instance = nil
function IconManager.get_default()
    if not default_instance then
        default_instance = IconManager()
    end
    return default_instance
end

return IconManager
