-- examples/bar/config.lua
-- Complete Wayland Desktop Shell for Arch Linux (Status Bar, Control Center, Notification Popups & App Launcher)

local ignis = require("ignis")
local widgets = ignis.widgets
local services = ignis.services

local app = ignis.App.get_default()
local cmd_mgr = ignis.CommandManager.get_default()
local hyprland = services.HyprlandService.get_default()
local audio = services.AudioService.get_default()
local mpris = services.MprisService.get_default()
local upower = services.UPowerService.get_default()
local network = services.NetworkService.get_default()
local bluetooth = services.BluetoothService.get_default()
local backlight = services.BacklightService.get_default()
local power_profiles = services.PowerProfilesService.get_default()
local tray = services.SystemTrayService.get_default()
local notifications = services.NotificationService.get_default()
local applications = services.ApplicationsService.get_default()
local fetch = services.FetchService.get_default()

local config_dir = (debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]+$") or ".")
pcall(function()
    app:apply_css(config_dir .. "/style.scss")
end)

local clock_var = ignis.Variable({
    value = os.date("%a %b %d  %H:%M:%S"),
    poll = { 1000, function() return os.date("%a %b %d  %H:%M:%S") end }
})

-- ============================================================================
-- 1. Status Bar Components
-- ============================================================================
local function ArchLauncherButton()
    return widgets.Button({
        css_classes = { "arch-launcher-btn" },
        tooltip_text = string.format("%s (%s) — %d packages", fetch.os_pretty_name, fetch.kernel, fetch.packages_count),
        on_click = function()
            app:toggle_window("ignis-app-launcher")
        end,
        child = widgets.Icon({
            image = fetch.os_logo ~= "" and fetch.os_logo or "archlinux-logo",
            pixel_size = 18
        })
    })
end

local function WorkspacesWidget()
    return widgets.Box({
        css_classes = { "workspaces" },
        spacing = 6,
        child = hyprland:bind("workspaces", function(ws_list)
            local btns = {}
            for _, ws in ipairs(ws_list or {}) do
                local is_active = (hyprland.active_workspace and hyprland.active_workspace.id == ws.id)
                table.insert(btns, widgets.Button({
                    css_classes = is_active and { "ws-btn", "active" } or { "ws-btn" },
                    label = tostring(ws.name or ws.id),
                    on_click = function()
                        ws:switch_to()
                    end
                }))
            end
            return btns
        end)
    })
end

local function ActiveWindowWidget()
    return widgets.Label({
        css_classes = { "active-window" },
        ellipsize = "end",
        max_width_chars = 48,
        label = hyprland.active_window:bind("title", function(title)
            return (title and title ~= "") and title or "Arch Linux"
        end)
    })
end

local function MediaWidget()
    return widgets.Button({
        css_classes = { "media-pill" },
        visible = mpris:bind("active_player", function(p) return p ~= nil end),
        on_click = function()
            local p = mpris.active_player
            if p then p:play_pause() end
        end,
        on_scroll_up = function()
            local p = mpris.active_player
            if p then p:next() end
        end,
        on_scroll_down = function()
            local p = mpris.active_player
            if p then p:previous() end
        end,
        child = widgets.Box({
            spacing = 8,
            child = {
                widgets.Icon({
                    image = "audio-x-generic-symbolic",
                    pixel_size = 16
                }),
                widgets.Label({
                    ellipsize = "end",
                    max_width_chars = 32,
                    label = mpris:bind("active_player", function(p)
                        if not p then return "" end
                        if p.artist ~= "" then
                            return p.artist .. " — " .. p.title
                        end
                        return p.title
                    end)
                })
            }
        })
    })
end

local function AudioPill()
    local speaker = audio.speaker
    return widgets.EventBox({
        css_classes = { "audio-box" },
        spacing = 6,
        on_click = function()
            speaker:toggle_mute()
        end,
        on_scroll_up = function()
            speaker:adjust_volume(5)
        end,
        on_scroll_down = function()
            speaker:adjust_volume(-5)
        end,
        child = {
            widgets.Icon({
                image = speaker:bind("icon_name"),
                pixel_size = 16,
            }),
            widgets.Scale({
                css_classes = { "volume-scale" },
                min = 0,
                max = 100,
                step = 1,
                value = speaker:bind("volume"),
                width_request = 75,
                on_change = function(scale)
                    speaker:set_volume(scale.value)
                end
            }),
            widgets.Label({
                label = speaker:bind("volume", function(v)
                    return string.format("%d%%", v or 0)
                end)
            })
        }
    })
end

local function NetworkPill()
    return widgets.Box({
        css_classes = { "network-box" },
        spacing = 6,
        child = {
            widgets.Icon({
                image = network.wifi:bind("icon_name"),
                pixel_size = 16
            }),
            widgets.Label({
                label = network.wifi:bind("ssid", function(ssid)
                    return (ssid and ssid ~= "") and ssid or "Offline"
                end)
            })
        }
    })
end

local function BatteryPill()
    local dev = upower.display_device
    return widgets.Box({
        css_classes = { "battery-box" },
        spacing = 6,
        visible = upower:bind("is_available"),
        child = {
            widgets.Icon({
                image = dev:bind("icon_name"),
                pixel_size = 16
            }),
            widgets.Label({
                label = dev:bind("percentage", function(pct)
                    return string.format("%d%%", math.floor((pct or 100) + 0.5))
                end)
            })
        }
    })
end

local function SystemTrayWidget()
    return widgets.Box({
        css_classes = { "systray" },
        spacing = 6,
        child = tray:bind("items", function(items)
            local list = {}
            for _, item in ipairs(items or {}) do
                local popover = item.menu and item.menu:create_popover() or nil
                local btn = widgets.Button({
                    css_classes = { "tray-item" },
                    tooltip_text = item:bind("tooltip"),
                    on_click = function() item:activate(0, 0) end,
                    on_right_click = function()
                        if popover then
                            popover:popup()
                        else
                            item:context_menu(0, 0)
                        end
                    end,
                    child = widgets.Box({
                        child = {
                            widgets.Icon({
                                image = item:bind("icon_name"),
                                pixel_size = 16
                            }),
                            popover
                        }
                    })
                })
                table.insert(list, btn)
            end
            return list
        end)
    })
end

-- ============================================================================
-- 2. Control Center / Quick Settings Window
-- ============================================================================
local function ControlCenterWindow()
    local rev = widgets.Revealer({
        transition_type = "slide_down",
        transition_duration = 200,
        reveal_child = false,
        child = widgets.Box({
            css_classes = { "control-center" },
            vertical = true,
            spacing = 12,
            width_request = 360,
            child = {
                widgets.CenterBox({
                    css_classes = { "cc-header" },
                    start_widget = widgets.Label({
                        css_classes = { "cc-title" },
                        label = "Quick Settings"
                    }),
                    end_widget = widgets.Button({
                        css_classes = { "cc-Action-btn" },
                        label = power_profiles:bind("active_profile", function(p) return "Profile: " .. tostring(p) end),
                        on_click = function() power_profiles:cycle_profile() end
                    })
                }),
                -- Toggle pills grid (Wi-Fi, Bluetooth, DND)
                widgets.Grid({
                    column_num = 3,
                    column_spacing = 8,
                    row_spacing = 8,
                    column_homogeneous = true,
                    child = {
                        widgets.ToggleButton({
                            css_classes = { "cc-toggle" },
                            label = "Wi-Fi",
                            active = network.wifi:bind("enabled"),
                            on_toggled = function(_, active) network.wifi.enabled = active end
                        }),
                        widgets.ToggleButton({
                            css_classes = { "cc-toggle" },
                            label = "Bluetooth",
                            active = bluetooth:bind("powered"),
                            on_toggled = function(_, active) bluetooth.powered = active end
                        }),
                        widgets.ToggleButton({
                            css_classes = { "cc-toggle" },
                            label = "Do Not Disturb",
                            active = notifications:bind("dnd"),
                            on_toggled = function(_, active) notifications.dnd = active end
                        }),
                    }
                }),
                -- Volume Slider
                widgets.Box({
                    spacing = 8,
                    child = {
                        widgets.Icon({ image = audio.speaker:bind("icon_name"), pixel_size = 18 }),
                        widgets.Scale({
                            hexpand = true,
                            min = 0, max = 100, step = 1,
                            value = audio.speaker:bind("volume"),
                            on_change = function(s) audio.speaker:set_volume(s.value) end
                        })
                    }
                }),
                -- Brightness Slider
                widgets.Box({
                    spacing = 8,
                    visible = backlight:bind("available"),
                    child = {
                        widgets.Icon({ image = backlight:bind("icon_name"), pixel_size = 18 }),
                        widgets.Scale({
                            hexpand = true,
                            min = 0, max = 100, step = 1,
                            value = backlight:bind("percentage"),
                            on_change = function(s) backlight.percentage = s.value end
                        })
                    }
                }),
                widgets.Separator({}),
                -- Notifications Header
                widgets.CenterBox({
                    start_widget = widgets.Label({
                        css_classes = { "cc-subtitle" },
                        label = "Notifications"
                    }),
                    end_widget = widgets.Button({
                        css_classes = { "cc-clear-btn" },
                        label = "Clear All",
                        on_click = function() notifications:clear_all() end
                    })
                }),
                -- Notification List
                widgets.Scroll({
                    min_content_height = 180,
                    max_content_height = 320,
                    child = widgets.Box({
                        vertical = true,
                        spacing = 8,
                        child = notifications:bind("notifications", function(list)
                            local cards = {}
                            for _, n in ipairs(list or {}) do
                                table.insert(cards, widgets.Box({
                                    css_classes = { "notif-card", "urgency-" .. tostring(n.urgency) },
                                    vertical = true,
                                    spacing = 4,
                                    child = {
                                        widgets.CenterBox({
                                            start_widget = widgets.Label({
                                                css_classes = { "notif-summary" },
                                                label = n.summary,
                                                ellipsize = "end"
                                            }),
                                            end_widget = widgets.Button({
                                                label = "×",
                                                on_click = function() n:close() end
                                            })
                                        }),
                                        widgets.Label({
                                            css_classes = { "notif-body" },
                                            label = n.body,
                                            wrap = true,
                                            xalign = 0
                                        })
                                    }
                                }))
                            end
                            return cards
                        end)
                    })
                })
            }
        })
    })

    return widgets.RevealerWindow({
        namespace = "ignis-control-center",
        monitor = 0,
        anchor = { "top", "right" },
        margin_top = 8,
        margin_right = 12,
        layer = "overlay",
        kb_mode = "on_demand",
        popup = true,
        visible = false,
        revealer = rev,
        child = rev
    })
end

-- ============================================================================
-- 3. Application Launcher Window
-- ============================================================================
local function AppLauncherWindow()
    local query_var = ignis.Variable("")

    local search_entry = widgets.Entry({
        css_classes = { "launcher-search" },
        placeholder_text = "Search applications...",
        hexpand = true,
        on_change = function(entry)
            query_var.value = entry.text
        end,
        on_accept = function()
            local filtered = services.ApplicationsService.search(applications.apps, query_var.value)
            if filtered[1] then
                filtered[1]:launch()
                app:close_window("ignis-app-launcher")
            end
        end
    })

    local rev = widgets.Revealer({
        transition_type = "crossfade",
        transition_duration = 150,
        reveal_child = false,
        child = widgets.Box({
            css_classes = { "app-launcher" },
            vertical = true,
            spacing = 10,
            width_request = 480,
            height_request = 420,
            child = {
                search_entry,
                widgets.Scroll({
                    vexpand = true,
                    child = widgets.Box({
                        vertical = true,
                        spacing = 6,
                        child = query_var:bind(function(q)
                            local matches = services.ApplicationsService.search(applications.apps, q)
                            local rows = {}
                            for i = 1, math.min(#matches, 25) do
                                local app_item = matches[i]
                                table.insert(rows, widgets.Button({
                                    css_classes = { "launcher-item" },
                                    on_click = function()
                                        app_item:launch()
                                        app:close_window("ignis-app-launcher")
                                    end,
                                    child = widgets.Box({
                                        spacing = 10,
                                        child = {
                                            widgets.Icon({ image = app_item.icon, pixel_size = 28 }),
                                            widgets.Box({
                                                vertical = true,
                                                valign = "center",
                                                child = {
                                                    widgets.Label({
                                                        css_classes = { "launcher-item-name" },
                                                        label = app_item.name,
                                                        xalign = 0
                                                    }),
                                                    widgets.Label({
                                                        css_classes = { "launcher-item-desc" },
                                                        label = app_item.description,
                                                        ellipsize = "end",
                                                        max_width_chars = 50,
                                                        xalign = 0
                                                    })
                                                }
                                            })
                                        }
                                    })
                                }))
                            end
                            return rows
                        end)
                    })
                })
            }
        })
    })

    return widgets.RevealerWindow({
        namespace = "ignis-app-launcher",
        monitor = 0,
        layer = "overlay",
        kb_mode = "exclusive",
        popup = true,
        visible = false,
        revealer = rev,
        child = rev
    })
end

-- ============================================================================
-- 4. Top Status Bar Window & Registered CLI Commands
-- ============================================================================
local function StatusBar(monitor_id)
    return widgets.Window({
        namespace = "ignis-bar-" .. tostring(monitor_id),
        monitor = monitor_id,
        anchor = { "top", "left", "right" },
        exclusivity = "exclusive",
        layer = "top",
        child = widgets.CenterBox({
            css_classes = { "bar" },
            start_widget = widgets.Box({
                spacing = 10,
                child = {
                    ArchLauncherButton(),
                    WorkspacesWidget(),
                    ActiveWindowWidget(),
                }
            }),
            center_widget = MediaWidget(),
            end_widget = widgets.Box({
                spacing = 10,
                child = {
                    SystemTrayWidget(),
                    NetworkPill(),
                    AudioPill(),
                    BatteryPill(),
                    widgets.Button({
                        css_classes = { "clock-btn" },
                        on_click = function()
                            app:toggle_window("ignis-control-center")
                        end,
                        child = widgets.Label({
                            css_classes = { "clock" },
                            label = clock_var:bind()
                        })
                    })
                }
            })
        })
    })
end

StatusBar(0)
ControlCenterWindow()
AppLauncherWindow()

-- Register CLI commands (`ignis run-command <name>`)
cmd_mgr:add_command("toggle-launcher", function()
    app:toggle_window("ignis-app-launcher")
    return "ok"
end)
cmd_mgr:add_command("toggle-control-center", function()
    app:toggle_window("ignis-control-center")
    return "ok"
end)
cmd_mgr:add_command("volume-up", function(step)
    audio.speaker:adjust_volume(tonumber(step) or 5)
    return tostring(audio.speaker.volume)
end)
cmd_mgr:add_command("volume-down", function(step)
    audio.speaker:adjust_volume(-(tonumber(step) or 5))
    return tostring(audio.speaker.volume)
end)
cmd_mgr:add_command("volume-mute", function()
    audio.speaker:toggle_mute()
    return tostring(audio.speaker.is_muted)
end)
cmd_mgr:add_command("media-play-pause", function()
    local p = mpris.active_player
    if p then p:play_pause() end
    return "ok"
end)
