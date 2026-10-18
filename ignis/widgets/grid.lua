local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("Grid", Gtk.Grid)

base_widget.apply_to_class(Ignis.Grid)

function Ignis.Grid:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.child_widgets = {}
    env.column_num = props.column_num
    env.row_num = props.row_num

    self:init_base_widget(props)

    if props.row_spacing ~= nil then self.row_spacing = props.row_spacing end
    if props.column_spacing ~= nil then self.column_spacing = props.column_spacing end
    if props.row_homogeneous ~= nil then self.row_homogeneous = props.row_homogeneous end
    if props.column_homogeneous ~= nil then self.column_homogeneous = props.column_homogeneous end

    if props.child ~= nil then
        self.child = props.child
    end
end

function Ignis.Grid:get_column_num()
    return base_widget.get_env(self).column_num
end

function Ignis.Grid:set_column_num(val)
    local env = base_widget.get_env(self)
    env.column_num = val
    if env.child_widgets and #env.child_widgets > 0 then
        self:set_child(env.child_widgets)
    end
end

function Ignis.Grid:get_row_num()
    return base_widget.get_env(self).row_num
end

function Ignis.Grid:set_row_num(val)
    local env = base_widget.get_env(self)
    env.row_num = val
    if env.child_widgets and #env.child_widgets > 0 then
        self:set_child(env.child_widgets)
    end
end

function Ignis.Grid:get_child()
    return base_widget.get_env(self).child_widgets or {}
end

function Ignis.Grid:set_child(child_list)
    if not child_list then return end
    local env = base_widget.get_env(self)
    for _, item in ipairs(env.child_widgets or {}) do
        local w = type(item) == "table" and not item._type and item[1] or item
        if w then
            Gtk.Grid.remove(self, w)
        end
    end
    env.child_widgets = {}

    local col_num = env.column_num
    local row_num = env.row_num

    for i, item in ipairs(child_list) do
        table.insert(env.child_widgets, item)
        if type(item) == "table" and not item._type and item[1] then
            local w = item[1]
            local c = item.column or item.col or item[2] or 0
            local r = item.row or item[3] or 0
            local width = item.width or item[4] or 1
            local height = item.height or item[5] or 1
            Gtk.Grid.attach(self, w, c, r, width, height)
        else
            local idx = i - 1
            local c, r = idx, 0
            if col_num and col_num > 0 then
                c = idx % col_num
                r = math.floor(idx / col_num)
            elseif row_num and row_num > 0 then
                r = idx % row_num
                c = math.floor(idx / row_num)
            end
            Gtk.Grid.attach(self, item, c, r, 1, 1)
        end
    end
    self:notify("child")
end

return Ignis.Grid
