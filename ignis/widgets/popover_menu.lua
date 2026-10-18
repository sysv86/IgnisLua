local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local Gio = lgi.Gio
local base_widget = require("ignis.base_widget")

local Ignis = lgi.package("Ignis")
Ignis:class("PopoverMenu", Gtk.PopoverMenu)

base_widget.apply_to_class(Ignis.PopoverMenu)

local action_counter = 0

local function build_gio_menu(self, items, action_group)
    local menu = Gio.Menu.new()
    local section = Gio.Menu.new()

    for _, item in ipairs(items or {}) do
        if item.separator then
            menu:append_section(nil, section)
            section = Gio.Menu.new()
        elseif item.submenu or item.items then
            local sub = build_gio_menu(self, item.submenu or item.items, action_group)
            section:append_submenu(item.label or "", sub)
        else
            action_counter = action_counter + 1
            local act_name = "item_" .. tostring(action_counter)
            local simple_action = Gio.SimpleAction.new(act_name, nil)
            if item.enabled == false then
                simple_action:set_enabled(false)
            end
            if item.on_activate then
                simple_action.on_activate = function()
                    item.on_activate(self, item)
                end
            end
            action_group:add_action(simple_action)
            section:append(item.label or "", "menu." .. act_name)
        end
    end

    menu:append_section(nil, section)
    return menu
end

function Ignis.PopoverMenu:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.items = {}

    self:override_enum("position", Gtk.PositionType)
    self:init_base_widget(props)

    if props.has_arrow ~= nil then self.has_arrow = props.has_arrow end
    if props.autohide ~= nil then self.autohide = props.autohide end
    if props.position ~= nil then self.position = props.position end
    if props.menu_model ~= nil then self:set_menu_model(props.menu_model) end
    if props.items ~= nil then self:set_items(props.items) end
end

function Ignis.PopoverMenu:get_items()
    return base_widget.get_env(self).items
end

function Ignis.PopoverMenu:set_items(items)
    local env = base_widget.get_env(self)
    env.items = items or {}
    local action_group = Gio.SimpleActionGroup.new()
    local menu_model = build_gio_menu(self, env.items, action_group)
    self:insert_action_group("menu", action_group)
    self:set_menu_model(menu_model)
    self:notify("items")
end

return Ignis.PopoverMenu
