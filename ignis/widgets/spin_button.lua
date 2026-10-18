local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("SpinButton", Gtk.SpinButton)

base_widget.apply_to_class(Ignis.SpinButton)

function Ignis.SpinButton:init(props)
    props = props or {}
    local env = base_widget.get_env(self)

    env.on_change_val = nil
    env.suppress_change = false

    self:init_base_widget(props)

    self.on_value_changed = function(self_ptr)
        local e = base_widget.get_env(self_ptr)
        self_ptr:notify("value")
        if e.on_change_val and not e.suppress_change then
            e.on_change_val(self_ptr, self_ptr:get_value())
        end
    end

    if props.min ~= nil or props.max ~= nil then
        self:set_range(props.min or 0, props.max or 0)
    end
    if props.step ~= nil then
        self:set_increments(props.step, props.step)
    end
    if props.value ~= nil then
        self.value = props.value
    end
    if props.on_change ~= nil then
        self:set_on_change(props.on_change)
    end
end

function Ignis.SpinButton:get_value()
    return Gtk.SpinButton.get_value(self)
end

function Ignis.SpinButton:set_value(value)
    if value == nil then return end
    local env = base_widget.get_env(self)
    env.suppress_change = true
    Gtk.SpinButton.set_value(self, value)
    env.suppress_change = false
    self:notify("value")
end

---@return number
function Ignis.SpinButton:get_min()
    local adj = self.adjustment
    return adj and adj.lower or 0
end

---@param value number
function Ignis.SpinButton:set_min(value)
    if value == nil then return end
    local adj = self.adjustment
    if adj then adj.lower = value end
    self:notify("min")
end

---@return number
function Ignis.SpinButton:get_max()
    local adj = self.adjustment
    return adj and adj.upper or 0
end

---@param value number
function Ignis.SpinButton:set_max(value)
    if value == nil then return end
    local adj = self.adjustment
    if adj then adj.upper = value end
    self:notify("max")
end

---@return number
function Ignis.SpinButton:get_step()
    local adj = self.adjustment
    return adj and adj.step_increment or 1
end

---@param value number
function Ignis.SpinButton:set_step(value)
    if value == nil then return end
    local adj = self.adjustment
    if adj then adj.step_increment = value end
    self:notify("step")
end

---@return number
function Ignis.SpinButton:get_on_change()
    return base_widget.get_env(self).on_change_val
end

---@param value fun(self: table, value: number)
function Ignis.SpinButton:set_on_change(value)
    base_widget.get_env(self).on_change_val = value
end

return Ignis.SpinButton
