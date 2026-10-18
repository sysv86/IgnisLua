local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local Gdk = lgi.require("Gdk", "4.0")
local GdkPixbuf = lgi.require("GdkPixbuf", "2.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
---@class Ignis.Picture : Gtk.Picture
---@field image string|GdkPixbuf.Pixbuf
---@field width number
---@field height number
---@field content_fit string
Ignis:class("Picture", Gtk.Picture)

base_widget.apply_to_class(Ignis.Picture)

--- Helper to scale pixbuf
---@param pixbuf GdkPixbuf.Pixbuf
---@param width number
---@param height number
---@return GdkPixbuf.Pixbuf
local function scale_pixbuf(pixbuf, width, height)
    return pixbuf:scale_simple(width, height, GdkPixbuf.InterpType.BILINEAR)
end

--- Helper to crop pixbuf
---@param pixbuf GdkPixbuf.Pixbuf
---@param width number
---@param height number
---@return GdkPixbuf.Pixbuf
local function crop_pixbuf(pixbuf, width, height)
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

--- Constructor for Ignis.Picture
---@param props {image: string|GdkPixbuf.Pixbuf, width: number, height: number, content_fit: string, halign: string, valign: string, hexpand: boolean, vexpand: boolean, style: string, setup: function}
function Ignis.Picture:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    
    self:override_enum("content_fit", Gtk.ContentFit)
    
    env.image_val = nil
    env.width_val = props.width or -1
    env.height_val = props.height or -1
    env.content_fit_val = props.content_fit or "contain"
    
    self.width_request = env.width_val
    self.height_request = env.height_val
    self:set_content_fit(env.content_fit_val:upper())
    
    self:init_base_widget(props)
    
    if props.image then
        self:set_image(props.image)
    end
end

---@return string|GdkPixbuf.Pixbuf
function Ignis.Picture:get_image()
    return base_widget.get_env(self).image_val
end

--- Sets the image of the picture
---@param value string|GdkPixbuf.Pixbuf
function Ignis.Picture:set_image(value)
    local env = base_widget.get_env(self)
    env.image_val = value
    self:draw_image(value)
end

---@return number
function Ignis.Picture:get_width()
    return base_widget.get_env(self).width_val
end

---@param value number
function Ignis.Picture:set_width(value)
    local env = base_widget.get_env(self)
    env.width_val = value
    self.width_request = value
    self:draw_image(env.image_val)
end

---@return number
function Ignis.Picture:get_height()
    return base_widget.get_env(self).height_val
end

---@param value number
function Ignis.Picture:set_height(value)
    local env = base_widget.get_env(self)
    env.height_val = value
    self.height_request = value
    self:draw_image(env.image_val)
end

--- Internal method to draw the image
---@param image string|GdkPixbuf.Pixbuf
function Ignis.Picture:draw_image(image)
    if not image then return end
    
    if type(image) == "userdata" and image._type and image._type.name == "GdkPixbuf.Pixbuf" then
        self:set_from_pixbuf(image)
    elseif type(image) == "string" then
        local file = io.open(image, "r")
        if file then
            file:close()
            if image:match("%.svg$") then
                self:set_from_svg(image)
            else
                self:set_from_file(image)
            end
        else
            self:set_from_icon_name(image)
        end
    end
end

---@param pixbuf GdkPixbuf.Pixbuf
function Ignis.Picture:set_from_pixbuf(pixbuf)
    local env = base_widget.get_env(self)
    local scaled = self:scale_pixbuf_internal(pixbuf, env.width_val, env.height_val)
    if not scaled then return end
    
    local paintable = Gdk.Texture.new_for_pixbuf(scaled)
    self:set_paintable(paintable)
end

---@param filename string
function Ignis.Picture:set_from_file(filename)
    local status, pixbuf = pcall(function()
        return GdkPixbuf.Pixbuf.new_from_file(filename)
    end)
    if status and pixbuf then
        self:set_from_pixbuf(pixbuf)
    else
        print("[WARN] Picture failed to load from file: " .. filename)
    end
end

---@param filename string
function Ignis.Picture:set_from_svg(filename)
    local env = base_widget.get_env(self)
    local status, pixbuf = pcall(function()
        return GdkPixbuf.Pixbuf.new_from_file_at_scale(filename, env.width_val, env.height_val, true)
    end)
    if status and pixbuf then
        local paintable = Gdk.Texture.new_for_pixbuf(pixbuf)
        self:set_paintable(paintable)
    else
        print("[WARN] Picture failed to load SVG: " .. filename)
    end
end

---@param icon_name string
function Ignis.Picture:set_from_icon_name(icon_name)
    local env = base_widget.get_env(self)
    local size = math.max(env.height_val, env.width_val)
    if size <= 0 then size = 16 end
    
    local theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default())
    local icon_paintable = theme:lookup_icon(icon_name, {}, size, 1, Gtk.TextDirection.NONE, 0)
    
    if icon_paintable then
        self:set_paintable(icon_paintable)
    else
        print("[WARN] Picture failed to find icon: " .. icon_name)
    end
end

---@param pixbuf GdkPixbuf.Pixbuf
---@param width number
---@param height number
---@return GdkPixbuf.Pixbuf
function Ignis.Picture:scale_pixbuf_internal(pixbuf, width, height)
    if width <= 0 or height <= 0 then return pixbuf end
    
    local env = base_widget.get_env(self)
    if env.content_fit_val == "cover" then
        pixbuf = crop_pixbuf(pixbuf, width, height)
    end
    
    return scale_pixbuf(pixbuf, width, height)
end

return Ignis.Picture
