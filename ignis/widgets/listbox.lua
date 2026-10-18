local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")

Ignis:class("ListBoxRow", Gtk.ListBoxRow)
base_widget.apply_to_class(Ignis.ListBoxRow)

function Ignis.ListBoxRow:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.on_activate_val = props.on_activate

    self:init_base_widget(props)

    if props.selectable ~= nil then self.selectable = props.selectable end
    if props.activatable ~= nil then self.activatable = props.activatable end
    if props.child ~= nil then self.child = props.child end
end

function Ignis.ListBoxRow:get_on_activate()
    return base_widget.get_env(self).on_activate_val
end

function Ignis.ListBoxRow:set_on_activate(cb)
    base_widget.get_env(self).on_activate_val = cb
end

Ignis:class("ListBox", Gtk.ListBox)
base_widget.apply_to_class(Ignis.ListBox)

function Ignis.ListBox:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.row_widgets = {}
    env.on_row_activated_val = nil
    env.on_row_selected_val = nil

    self:override_enum("selection_mode", Gtk.SelectionMode)
    self:init_base_widget(props)

    self.on_row_activated = function(self_ptr, row)
        if row and row.get_on_activate then
            local row_cb = row:get_on_activate()
            if row_cb then row_cb(row) end
        end
        local cb = base_widget.get_env(self_ptr).on_row_activated_val
        if cb then cb(self_ptr, row) end
    end

    self.on_row_selected = function(self_ptr, row)
        local cb = base_widget.get_env(self_ptr).on_row_selected_val
        if cb then cb(self_ptr, row) end
    end

    if props.selection_mode ~= nil then self.selection_mode = props.selection_mode end
    if props.activate_on_single_click ~= nil then self.activate_on_single_click = props.activate_on_single_click end
    if props.show_separators ~= nil then self.show_separators = props.show_separators end
    if props.on_row_activated ~= nil then self:set_on_row_activated(props.on_row_activated) end
    if props.on_row_selected ~= nil then self:set_on_row_selected(props.on_row_selected) end
    if props.rows ~= nil then self.rows = props.rows end
    if props.child ~= nil and props.rows == nil then self.rows = props.child end
end

function Ignis.ListBox:get_rows()
    return base_widget.get_env(self).row_widgets or {}
end

function Ignis.ListBox:set_rows(row_list)
    if not row_list then return end
    local env = base_widget.get_env(self)
    for _, r in ipairs(env.row_widgets or {}) do
        Gtk.ListBox.remove(self, r)
    end
    env.row_widgets = {}

    for _, r in ipairs(row_list) do
        if r then
            table.insert(env.row_widgets, r)
            Gtk.ListBox.append(self, r)
        end
    end
    self:notify("rows")
    self:notify("child")
end

Ignis.ListBox.get_child = Ignis.ListBox.get_rows
Ignis.ListBox.set_child = Ignis.ListBox.set_rows

function Ignis.ListBox:get_on_row_activated()
    return base_widget.get_env(self).on_row_activated_val
end

function Ignis.ListBox:set_on_row_activated(cb)
    base_widget.get_env(self).on_row_activated_val = cb
end

function Ignis.ListBox:get_on_row_selected()
    return base_widget.get_env(self).on_row_selected_val
end

function Ignis.ListBox:set_on_row_selected(cb)
    base_widget.get_env(self).on_row_selected_val = cb
end

return {
    ListBox = Ignis.ListBox,
    ListBoxRow = Ignis.ListBoxRow
}
