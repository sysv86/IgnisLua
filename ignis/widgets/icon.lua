local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local Gdk = lgi.require("Gdk", "4.0")
local GdkPixbuf = lgi.require("GdkPixbuf", "2.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
---@class Ignis.Icon : Gtk.Image
---@field image string|GdkPixbuf.Pixbuf
---@field pixel_size number
Ignis:class("Icon", Gtk.Image)

base_widget.apply_to_class(Ignis.Icon)

--- Constructor for Ignis.Icon
---@param props {image: string|GdkPixbuf.Pixbuf, pixel_size: number, halign: string, valign: string, hexpand: boolean, vexpand: boolean, style: string, setup: function}
function Ignis.Icon:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    
    env.pixel_size = props.pixel_size or -1
    env.image_val = nil
    
    self:init_base_widget(props)

    if props.image then
        if type(props.image) == "table" and props.image._is_binding then
            self.image = props.image
        else
            self:set_image(props.image)
        end
    end
end

---@return number
function Ignis.Icon:get_pixel_size()
    return base_widget.get_env(self).pixel_size
end

---@param value number
function Ignis.Icon:set_pixel_size(value)
    base_widget.get_env(self).pixel_size = value
    if base_widget.get_env(self).image_val then
        self:set_image(base_widget.get_env(self).image_val)
    end
end

---@return string|GdkPixbuf.Pixbuf
function Ignis.Icon:get_image()
    return base_widget.get_env(self).image_val
end

--- Helper to scale pixbuf
---@param pixbuf GdkPixbuf.Pixbuf
---@param width number
---@param height number
---@return GdkPixbuf.Pixbuf
local function scale_pixbuf(pixbuf, width, height)
    return pixbuf:scale_simple(width, height, GdkPixbuf.InterpType.BILINEAR)
end

--- Sets the image of the icon
---@param value string|GdkPixbuf.Pixbuf
function Ignis.Icon:set_image(value)
    if not value then return end
    
    local env = base_widget.get_env(self)
    env.image_val = value
    
    local pixbuf = nil
    
    if type(value) == "userdata" and value._type and value._type.name == "GdkPixbuf.Pixbuf" then
        pixbuf = value
    elseif type(value) == "string" then
        local file = io.open(value, "r")
        if file then
            file:close()
            local status, err = pcall(function()
                pixbuf = GdkPixbuf.Pixbuf.new_from_file(value)
            end)
            if not status then
                print("[WARN] Icon failed to load image from file: " .. tostring(err))
            end
        else
            self:set_from_icon_name(value)
            return
        end
    end
    
    if not pixbuf then return end
    
    local pixel_size = env.pixel_size or -1
    if pixel_size > 0 then
        pixbuf = scale_pixbuf(pixbuf, pixel_size, pixel_size)
    end
    
    local paintable = Gdk.Texture.new_for_pixbuf(pixbuf)
    self:set_from_paintable(paintable)
end

return Ignis.Icon
