local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("Corner", Gtk.DrawingArea)

base_widget.apply_to_class(Ignis.Corner)

local pi = math.pi

local function draw_corner(area, cr, width, height)
    local env = base_widget.get_env(area)
    local orient = (env.orientation or "top-left"):lower():gsub("_", "-")

    cr:save()
    cr:new_path()

    if orient == "top-left" then
        cr:move_to(0, 0)
        cr:line_to(0, height)
        cr:arc(width, height, width, pi, 1.5 * pi)
        cr:close_path()
    elseif orient == "top-right" then
        cr:move_to(width, 0)
        cr:line_to(0, 0)
        cr:arc(0, height, width, 1.5 * pi, 2 * pi)
        cr:close_path()
    elseif orient == "bottom-left" then
        cr:move_to(0, height)
        cr:line_to(width, height)
        cr:arc(width, 0, width, 0.5 * pi, pi)
        cr:close_path()
    elseif orient == "bottom-right" then
        cr:move_to(width, height)
        cr:line_to(width, 0)
        cr:arc(0, 0, width, 0, 0.5 * pi)
        cr:close_path()
    end

    local style_ctx = area:get_style_context()
    local ok, color = pcall(function() return area:get_color() end)
    if ok and color then
        cr:set_source_rgba(color.red, color.green, color.blue, color.alpha)
    elseif style_ctx then
        local ok_c, c = pcall(function() return style_ctx:get_color() end)
        if ok_c and c then
            cr:set_source_rgba(c.red, c.green, c.blue, c.alpha)
        end
    end

    cr:fill()
    cr:restore()
end

function Ignis.Corner:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.orientation = props.orientation or "top-left"
    env.size = props.size or { 20, 20 }

    self:init_base_widget(props)

    self:set_size(env.size)
    self:set_draw_func(draw_corner)
end

function Ignis.Corner:get_orientation()
    return base_widget.get_env(self).orientation
end

function Ignis.Corner:set_orientation(value)
    base_widget.get_env(self).orientation = value
    self:queue_draw()
    self:notify("orientation")
end

function Ignis.Corner:get_size()
    return base_widget.get_env(self).size
end

function Ignis.Corner:set_size(value)
    local env = base_widget.get_env(self)
    env.size = value
    if type(value) == "number" then
        self.width_request = value
        self.height_request = value
    elseif type(value) == "table" then
        self.width_request = value.width or value[1] or 20
        self.height_request = value.height or value[2] or 20
    end
    self:queue_draw()
    self:notify("size")
end

return Ignis.Corner
