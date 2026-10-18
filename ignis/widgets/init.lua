local function make_factory(klass)
    return function(props)
        local inst = klass()
        inst:init(props)
        return inst
    end
end

local listbox_mod = require("ignis.widgets.listbox")
local stack_mod = require("ignis.widgets.stack")

local explicit = {
    Box = require("ignis.widgets.box"),
    Button = require("ignis.widgets.button"),
    Calendar = require("ignis.widgets.calendar"),
    CenterBox = require("ignis.widgets.centerbox"),
    CheckButton = require("ignis.widgets.check_button"),
    Corner = require("ignis.widgets.corner"),
    DropDown = require("ignis.widgets.dropdown"),
    Entry = require("ignis.widgets.entry"),
    EventBox = require("ignis.widgets.eventbox"),
    Fixed = require("ignis.widgets.fixed"),
    FlowBox = require("ignis.widgets.flowbox"),
    Grid = require("ignis.widgets.grid"),
    HeaderBar = require("ignis.widgets.headerbar"),
    Icon = require("ignis.widgets.icon"),
    Label = require("ignis.widgets.label"),
    ListBox = listbox_mod.ListBox,
    ListBoxRow = listbox_mod.ListBoxRow,
    Overlay = require("ignis.widgets.overlay"),
    Picture = require("ignis.widgets.picture"),
    PopoverMenu = require("ignis.widgets.popover_menu"),
    ProgressBar = require("ignis.widgets.progressbar"),
    RegularWindow = require("ignis.widgets.regular_window"),
    Revealer = require("ignis.widgets.revealer"),
    RevealerWindow = require("ignis.widgets.revealer_window"),
    Scale = require("ignis.widgets.scale"),
    Scroll = require("ignis.widgets.scroll"),
    Separator = require("ignis.widgets.separator"),
    SpinButton = require("ignis.widgets.spin_button"),
    Spinner = require("ignis.widgets.spinner"),
    Stack = stack_mod.Stack,
    StackSwitcher = stack_mod.StackSwitcher,
    Switch = require("ignis.widgets.switch"),
    ToggleButton = require("ignis.widgets.toggle_button"),
    Window = require("ignis.widgets.window"),
}

local M = {}

for name, klass in pairs(explicit) do
    M[name] = make_factory(klass)
end

M.FileDialog = require("ignis.widgets.file_dialog")

setmetatable(M, {
    __index = function(t, key)
        local lgi = require("lgi")
        local Gtk = lgi.require("Gtk", "4.0")

        local gtk_name = key
        if key == "Scroll" then
            gtk_name = "ScrolledWindow"
        elseif key == "Icon" then
            gtk_name = "Image"
        end

        local success, base_class = pcall(function() return Gtk[gtk_name] end)
        if success and base_class then
            local Ignis = lgi.package("Ignis")
            local base_widget = require("ignis.base_widget")

            if not Ignis[key] then
                local ok, err = pcall(function()
                    Ignis:class(key, base_class)
                end)
                if not ok then
                    print("[WARN] Failed to subclass " .. key .. " via LGI: " .. tostring(err))
                    return nil
                end

                local klass = Ignis[key]
                base_widget.apply_to_class(klass)
            end

            local klass = Ignis[key]

            if not klass.init then
                function klass:init(props)
                    props = props or {}
                    self:init_base_widget(props)

                    for k, v in pairs(props) do
                        if not base_widget.RESERVED_BASE_KEYS[k] then
                            self[k] = v
                        end
                    end
                end
            end

            local factory = make_factory(klass)
            t[key] = factory
            return factory
        end

        return nil
    end
})

return M
