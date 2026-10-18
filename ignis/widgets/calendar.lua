local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("Calendar", Gtk.Calendar)

base_widget.apply_to_class(Ignis.Calendar)

function Ignis.Calendar:init(props)
    props = props or {}
    local env = base_widget.get_env(self)

    self:init_base_widget(props)

    self.on_day_selected = function(self_ptr)
        if env.on_day_selected_val then env.on_day_selected_val(self_ptr) end
    end
    self.on_next_month = function(self_ptr)
        if env.on_next_month_val then env.on_next_month_val(self_ptr) end
    end
    self.on_prev_month = function(self_ptr)
        if env.on_prev_month_val then env.on_prev_month_val(self_ptr) end
    end
    self.on_next_year = function(self_ptr)
        if env.on_next_year_val then env.on_next_year_val(self_ptr) end
    end
    self.on_prev_year = function(self_ptr)
        if env.on_prev_year_val then env.on_prev_year_val(self_ptr) end
    end

    if props.day ~= nil then self.day = props.day end
    if props.month ~= nil then self.month = props.month end
    if props.year ~= nil then self.year = props.year end
    if props.show_day_names ~= nil then self.show_day_names = props.show_day_names end
    if props.show_heading ~= nil then self.show_heading = props.show_heading end
    if props.show_week_numbers ~= nil then self.show_week_numbers = props.show_week_numbers end
    if props.no_month_change ~= nil then self.no_month_change = props.no_month_change end

    if props.on_day_selected then env.on_day_selected_val = props.on_day_selected end
    if props.on_next_month then env.on_next_month_val = props.on_next_month end
    if props.on_prev_month then env.on_prev_month_val = props.on_prev_month end
    if props.on_next_year then env.on_next_year_val = props.on_next_year end
    if props.on_prev_year then env.on_prev_year_val = props.on_prev_year end
end

return Ignis.Calendar
