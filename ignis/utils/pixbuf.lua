local M = {}

function M.scale_pixbuf(pixbuf, width, height)
    if not pixbuf or width <= 0 or height <= 0 then
        return pixbuf
    end
    local GdkPixbuf = require("lgi").require("GdkPixbuf", "2.0")
    return pixbuf:scale_simple(width, height, GdkPixbuf.InterpType.BILINEAR)
end

function M.crop_pixbuf(pixbuf, width, height)
    if not pixbuf or width <= 0 or height <= 0 then
        return pixbuf
    end
    local img_width = pixbuf:get_width()
    local img_height = pixbuf:get_height()

    local target_aspect_ratio = width / height
    local current_aspect_ratio = img_width / img_height

    local target_width, target_height
    if current_aspect_ratio > target_aspect_ratio then
        target_width = math.floor(img_height * target_aspect_ratio)
        target_height = img_height
    else
        target_width = img_width
        target_height = math.floor(img_width / target_aspect_ratio)
    end

    local crop_x = math.floor((img_width - target_width) / 2)
    local crop_y = math.floor((img_height - target_height) / 2)

    return pixbuf:new_subpixbuf(crop_x, crop_y, target_width, target_height)
end

function M.get_paintable(widget)
    local Gtk = require("lgi").require("Gtk", "4.0")
    return Gtk.WidgetPaintable.new(widget)
end

function M.get_file_icon_name(path, symbolic)
    local Gio = require("lgi").Gio
    local file = Gio.File.new_for_path(path)
    local attr = symbolic and "standard::symbolic-icon" or "standard::icon"
    local ok, info = pcall(function()
        return file:query_info(attr, Gio.FileQueryInfoFlags.NONE, nil)
    end)
    if not ok or not info then return nil end
    local icon = symbolic and info:get_symbolic_icon() or info:get_icon()
    if icon and icon.get_names then
        local names = icon:get_names()
        if names and #names > 0 then
            return names[1]
        end
    end
    return nil
end

--- Resolves a desktop application id (e.g. "org.gnome.Nautilus" or
--- "firefox") to an icon name usable by `widgets.Icon`.
---
--- Port of Ignis's `utils.get_app_icon_name`. Resolution order:
---   1. `Gio.DesktopAppInfo` lookup by id (with and without `.desktop`).
---   2. Direct `Gtk.IconTheme` lookup of the id and of its last dot-segment.
---@param app_id string?
---@return string?
function M.get_app_icon_name(app_id)
    if not app_id or app_id == "" then
        return nil
    end

    local lgi = require("lgi")
    local Gio = lgi.Gio
    local base = (app_id:gsub("%.desktop$", ""))

    local DesktopAppInfo = Gio.DesktopAppInfo
    if not DesktopAppInfo then
        local ok, GioUnix = pcall(function()
            return require("ignis.gi").require("GioUnix", "2.0")
        end)
        if ok and GioUnix then
            DesktopAppInfo = GioUnix.DesktopAppInfo
        end
    end

    if DesktopAppInfo then
        for _, candidate in ipairs({ base .. ".desktop", base }) do
            local ok, info = pcall(DesktopAppInfo.new, candidate)
            if ok and info then
                local icon_ok, icon = pcall(function() return info:get_icon() end)
                if icon_ok and icon then
                    local str_ok, str = pcall(function() return icon:to_string() end)
                    if str_ok and str and str ~= "" then
                        return str
                    end
                end
            end
        end
    end

    local display = lgi.Gdk.Display.get_default()
    if display then
        local Gtk = lgi.require("Gtk", "4.0")
        local theme = Gtk.IconTheme.get_for_display(display)
        local lowered = base:lower()
        for _, candidate in ipairs({ base, lowered, lowered:match("([^%.]+)$") }) do
            if candidate and theme:has_icon(candidate) then
                return candidate
            end
        end
    end

    return nil
end

return M
