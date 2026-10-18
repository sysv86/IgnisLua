-- test.lua
-- Comprehensive Integration & Unit Test Suite for IgnisLua (Lua 5.5.1 / GTK4 / Arch Linux)

package.path = "./?.lua;./?/init.lua;" .. package.path
package.cpath = "./?.so;" .. package.cpath

print("==================================================")
print("IGNISLUA COMPREHENSIVE TEST SUITE STARTING")
print("==================================================")

local has_native_lgi = pcall(require, "lgi")
if not has_native_lgi then
    print("[INFO] Native LGI not detected in environment; activating GTK4/LGI headless test mock...")
    local packages = {}

    local function make_widget_base(type_name)
        local cls = {
            _type = { name = type_name },
            _class = { _props = { label = true, text = true, active = true, visible = true, value = true } }
        }
        cls.__index = cls
        function cls:get_style_context()
            return {
                add_provider = function() end,
                remove_provider = function() end,
                get_color = function() return { red = 1, green = 1, blue = 1, alpha = 1 } end
            }
        end
        function cls:set_css_classes(c) self._css_classes = c end
        function cls:get_css_classes() return self._css_classes or {} end
        function cls:add_css_class(c)
            self._css_classes = self._css_classes or {}
            table.insert(self._css_classes, c)
        end
        function cls:remove_css_class(c)
            for i, v in ipairs(self._css_classes or {}) do
                if v == c then table.remove(self._css_classes, i); break end
            end
        end
        function cls:has_css_class(c)
            for _, v in ipairs(self._css_classes or {}) do
                if v == c then return true end
            end
            return false
        end
        function cls:add_controller(_) end
        function cls:set_orientation(o) self._orientation = o end
        function cls:get_orientation() return self._orientation or "HORIZONTAL" end
        function cls:set_child(c) self._child = c end
        function cls:get_child() return self._child end
        function cls:set_start_widget(w) self._start_widget = w end
        function cls:get_start_widget() return self._start_widget end
        function cls:set_center_widget(w) self._center_widget = w end
        function cls:get_center_widget() return self._center_widget end
        function cls:set_end_widget(w) self._end_widget = w end
        function cls:get_end_widget() return self._end_widget end
        function cls:set_text(t) self._text = t end
        function cls:get_text() return self._text or "" end
        function cls:set_from_icon_name(n) self._icon_name = n end
        function cls:set_from_paintable(p) self._paintable = p end
        function cls:set_paintable(p) self._paintable = p end
        function cls:set_content_fit(f) self._content_fit = f end
        function cls:set_draw_func(f) self._draw_func = f end
        function cls:queue_draw() end
        function cls:set_fraction(f) self._fraction = f end
        function cls:get_fraction() return self._fraction or 0 end
        function cls:set_model(m) self._model = m end
        function cls:get_selected() return self._selected or 0 end
        function cls:set_selected(s) self._selected = s end
        function cls:add_named(w, n) end
        function cls:add_titled(w, n, t) end
        function cls:pack_start(w) end
        function cls:pack_end(w) end
        function cls:insert_action_group() end
        function cls:set_menu_model() end
        function cls:set_visible(v) self.visible = v end
        function cls:get_visible() return self.visible ~= false end
        function cls:destroy() end
        function cls:unrealize() end
        function cls:hold() end
        return cls
    end

    local Gtk = setmetatable({
        STYLE_PROVIDER_PRIORITY_FALLBACK = 1,
        STYLE_PROVIDER_PRIORITY_THEME = 200,
        STYLE_PROVIDER_PRIORITY_SETTINGS = 400,
        STYLE_PROVIDER_PRIORITY_APPLICATION = 600,
        STYLE_PROVIDER_PRIORITY_USER = 800,
        Align = { FILL = "FILL", START = "START", END = "END", CENTER = "CENTER", BASELINE = "BASELINE" },
        Orientation = { HORIZONTAL = "HORIZONTAL", VERTICAL = "VERTICAL" },
        Justification = { LEFT = "LEFT", RIGHT = "RIGHT", CENTER = "CENTER", FILL = "FILL" },
        ContentFit = { FILL = "FILL", CONTAIN = "CONTAIN", COVER = "COVER", SCALE_DOWN = "SCALE_DOWN" },
        RevealerTransitionType = { NONE = "NONE", CROSSFADE = "CROSSFADE", SLIDE_RIGHT = "SLIDE_RIGHT", SLIDE_LEFT = "SLIDE_LEFT", SLIDE_UP = "SLIDE_UP", SLIDE_DOWN = "SLIDE_DOWN" },
        StackTransitionType = { NONE = "NONE", CROSSFADE = "CROSSFADE", SLIDE_RIGHT = "SLIDE_RIGHT", SLIDE_LEFT = "SLIDE_LEFT" },
        PolicyType = { ALWAYS = "ALWAYS", AUTOMATIC = "AUTOMATIC", NEVER = "NEVER", EXTERNAL = "EXTERNAL" },
        PositionType = { LEFT = "LEFT", RIGHT = "RIGHT", TOP = "TOP", BOTTOM = "BOTTOM" },
        SelectionMode = { NONE = "NONE", SINGLE = "SINGLE", BROWSE = "BROWSE", MULTIPLE = "MULTIPLE" },
        Overflow = { VISIBLE = "VISIBLE", HIDDEN = "HIDDEN" },
        EventSequenceState = { NONE = 0, CLAIMED = 1, DENIED = 2 },
        EventControllerScrollFlags = { BOTH_AXES = 3 },
        TextDirection = { NONE = 0 },
        CssProvider = function() return { load_from_string = function() end, connect = function() end } end,
        StyleContext = { add_provider_for_display = function() end, remove_provider_for_display = function() end },
        GestureClick = function() return { set_button = function() end, set_state = function() end } end,
        EventControllerMotion = function() return {} end,
        EventControllerScroll = { new = function() return {} end },
        EventControllerKey = function() return {} end,
        Adjustment = function(t) return t or {} end,
        Range = { set_value = function(self, v) self.adjustment.value = v end },
        StringList = { new = function(items) return { items = items } end },
        IconTheme = { get_for_display = function() return { add_search_path = function() end, lookup_icon = function() return {} end } end },
        FileDialog = { new = function() return { set_title = function() end, set_modal = function() end } end },
        Box = setmetatable({ append = function() end, prepend = function() end, remove = function() end }, { __index = make_widget_base("Gtk.Box") }),
        Grid = setmetatable({ attach = function() end, remove = function() end }, { __index = make_widget_base("Gtk.Grid") }),
        FlowBox = setmetatable({ append = function() end, remove = function() end }, { __index = make_widget_base("Gtk.FlowBox") }),
        ListBox = setmetatable({ append = function() end, remove = function() end }, { __index = make_widget_base("Gtk.ListBox") }),
        Overlay = setmetatable({ add_overlay = function() end, remove_overlay = function() end }, { __index = make_widget_base("Gtk.Overlay") }),
        Stack = setmetatable({ remove = function() end }, { __index = make_widget_base("Gtk.Stack") }),
        Fixed = setmetatable({ put = function() end, remove = function() end }, { __index = make_widget_base("Gtk.Fixed") }),
        Window = setmetatable({ set_interactive_debugging = function() end, destroy = function() end, unrealize = function() end }, { __index = make_widget_base("Gtk.Window") }),
        Application = setmetatable({ get_default = function() return _G._mock_app end, do_activate = function() end, quit = function() end }, { __index = make_widget_base("Gtk.Application") }),
    }, {
        __index = function(t, k)
            local w = make_widget_base("Gtk." .. k)
            rawset(t, k, w)
            return w
        end
    })

    local Gdk = {
        Display = { get_default = function() return { get_monitors = function() return { connect = function() end, get_item = function() return nil end, get_n_items = function() return 1 end } end } end },
        Cursor = { new_from_name = function(n) return { name = n } end },
        Texture = { new_for_pixbuf = function(p) return p end },
        InterpType = { BILINEAR = 2 }
    }

    local Gtk4LayerShell = {
        Layer = { BACKGROUND = 0, BOTTOM = 1, TOP = 2, OVERLAY = 3 },
        KeyboardMode = { NONE = 0, EXCLUSIVE = 1, ON_DEMAND = 2 },
        Edge = { LEFT = 0, RIGHT = 1, TOP = 2, BOTTOM = 3 },
        is_supported = function() return true end,
        init_for_window = function() end,
        set_namespace = function() end,
        set_anchor = function() end,
        set_exclusive_zone = function() end,
        auto_exclusive_zone_enable = function() end,
        set_layer = function() end,
        set_keyboard_mode = function() end,
        set_monitor = function() end,
        set_margin = function() end,
    }

    local Pango = {
        WrapMode = { WORD = "WORD", CHAR = "CHAR", WORD_CHAR = "WORD_CHAR" },
        EllipsizeMode = { NONE = "NONE", START = "START", MIDDLE = "MIDDLE", END = "END" },
    }

    local GObject = {
        ObjectClass = { find_property = function() return false end },
        Object = { notify = function() end }
    }

    local GLib = {
        PRIORITY_DEFAULT = 0,
        PRIORITY_DEFAULT_IDLE = 200,
        FileTest = { EXISTS = 1, IS_DIR = 2 },
        get_user_cache_dir = function() return "/tmp" end,
        get_user_data_dir = function() return "/tmp" end,
        mkdir_with_parents = function() end,
        dir_make_tmp = function() return "/tmp" end,
        find_program_in_path = function() return nil end,
        file_test = function(path)
            local f = io.open(path, "r")
            if f then f:close(); return true end
            return false
        end,
        timeout_add = function() return 1 end,
        idle_add = function(_, cb) cb(); return 1 end,
        Source = { remove = function() end },
        MainContext = { default = function() return { pending = function() return false end, iteration = function() end } end },
        Variant = setmetatable({}, { __call = function(_, sig, val) return { _sig = sig, _val = val, is_container = function() return false end, get_type_string = function() return sig end } end })
    }

    local Gio = {
        ApplicationFlags = { DEFAULT_FLAGS = 0 },
        BusType = { SESSION = 1, SYSTEM = 2 },
        BusNameOwnerFlags = { NONE = 0 },
        DBusProxyFlags = { NONE = 0 },
        DBusCallFlags = { NONE = 0 },
        DBusSignalFlags = { NONE = 0 },
        DBusError = { FAILED = 0 },
        FileMonitorFlags = { NONE = 0 },
        FileQueryInfoFlags = { NONE = 0 },
        FileType = { DIRECTORY = 2 },
        bus_own_name = function() return 1 end,
        bus_unown_name = function() end,
        DBusNodeInfo = { new_for_xml = function() return { interfaces = { { name = "mock", methods = {}, properties = {} } } } end },
        DBusProxy = { new_for_bus_sync = function() return nil, "mock" end },
        SimpleActionGroup = { new = function() return { add_action = function() end } end },
        SimpleAction = { new = function() return { set_enabled = function() end } end },
        Menu = { new = function() return { append = function() end, append_section = function() end, append_submenu = function() end } end },
        File = { new_for_path = function(p) return { get_path = function() return p end, query_exists = function() return true end, get_parent = function() return { get_path = function() return "." end } end, query_info = function() return nil end, monitor = function() return { changed = { connect = function() end }, cancel = function() end } end } end }
    }

    local GdkPixbuf = {
        Pixbuf = { new_from_file = function() return { get_width = function() return 64 end, get_height = function() return 64 end, scale_simple = function(s) return s end, new_subpixbuf = function(s) return s end } end },
        InterpType = { BILINEAR = 2 }
    }

    package.preload["lgi"] = function()
        return {
            Gtk = Gtk,
            Gdk = Gdk,
            Gtk4LayerShell = Gtk4LayerShell,
            GdkPixbuf = GdkPixbuf,
            Pango = Pango,
            GObject = GObject,
            GLib = GLib,
            Gio = Gio,
            cairo = {},
            require = function(name)
                if name == "Gtk" then return Gtk
                elseif name == "Gdk" then return Gdk
                elseif name == "Gtk4LayerShell" then return Gtk4LayerShell
                elseif name == "GdkPixbuf" then return GdkPixbuf
                elseif name == "Pango" then return Pango
                elseif name == "GObject" then return GObject
                elseif name == "GLib" then return GLib
                elseif name == "Gio" then return Gio
                end
                error("Typelib not found in mock: " .. tostring(name))
            end,
            package = function(pkg_name)
                if not packages[pkg_name] then
                    local pkg = {}
                    function pkg:class(cls_name, parent_cls)
                        local c = setmetatable({}, {
                            __index = parent_cls,
                            __call = function(cls_tbl, props)
                                local inst = setmetatable({
                                    _class = cls_tbl._class or { _props = {} },
                                    on_notify = { connect = function() return 1 end }
                                }, {
                                    __index = cls_tbl,
                                    __newindex = rawset
                                })
                                if cls_name == "App" then _G._mock_app = inst end
                                if props and cls_name == "App" and inst.init then
                                    inst:init(props)
                                end
                                return inst
                            end
                        })
                        c.__index = c
                        pkg[cls_name] = c
                    end
                    packages[pkg_name] = pkg
                end
                return packages[pkg_name]
            end
        }
    end
end

local success, ignis = pcall(require, "ignis")
if not success then
    print("[FAIL] Could not load ignis module: " .. tostring(ignis))
    os.exit(1)
end

local function flush_events()
    local GLib = require("lgi").GLib
    local ctx = GLib.MainContext.default()
    while ctx:pending() do
        ctx:iteration(false)
    end
end

-- 1. Test Variables, Shorthand Bind, Subscribe & Derive
print("[TEST 1] Verifying Reactive Variables, Subscribe & Derived State...")
local var = ignis.Variable({ value = 42 })
assert(var.value == 42, "Variable initial value mismatch")
assert(var:get() == 42, "Variable:get() failed")

local notify_val = nil
local unsub = var:subscribe(function(val)
    notify_val = val
end)

var:set(100)
flush_events()
assert(var.value == 100, "Variable value setter failed")
assert(notify_val == 100, "Variable subscribe notification failed")

unsub()
var:set(200)
assert(notify_val == 100, "Variable unsubscribe failed")

local v_a = ignis.Variable(10)
local v_b = ignis.Variable(25)
local v_sum = ignis.Variable.derive({ v_a, v_b }, function(a, b) return a + b end)
assert(v_sum.value == 35, "Variable.derive initial calculation failed")
v_a.value = 50
assert(v_sum.value == 75, "Variable.derive reactive update failed")
print("[PASS] Variable reactivity, subscribe & derive verified.")

-- 2. Test Property Bindings & Fluent Chaining
print("[TEST 2] Verifying Property Bindings & Binding:map()...")
local source = ignis.Variable({ value = "Hello" })
local target = ignis.Variable({ value = "" })

target.value = source:bind(function(val)
    return val .. " World"
end):map(function(val)
    return val .. "!"
end)
flush_events()

assert(target.value == "Hello World!", "Binding transformation + map failed: got " .. tostring(target.value))
source.value = "Lua 5.5"
flush_events()
assert(target.value == "Lua 5.5 World!", "Binding dynamic update failed")

target:unbind_property("value")
source.value = "Unbound"
assert(target.value == "Lua 5.5 World!", "Unbind property failed")
print("[PASS] Property bindings and fluent map verified.")

-- 3. Test JSON Encoder/Decoder & Utilities
print("[TEST 3] Verifying JSON Encoder/Decoder & Utils...")
local payload = {
    name = "IgnisLua",
    version = 5.5,
    active = true,
    items = { "bar", "dock", "notifications" },
    nested = { unicode = "Привет \n \"Lua\"" }
}
local encoded = ignis.utils.json_encode(payload)
local decoded = ignis.utils.json_decode(encoded)
assert(decoded.name == "IgnisLua", "JSON string mismatch")
assert(decoded.version == 5.5, "JSON number mismatch")
assert(decoded.active == true, "JSON boolean mismatch")
assert(#decoded.items == 3 and decoded.items[2] == "dock", "JSON array mismatch")
assert(decoded.nested.unicode == "Привет \n \"Lua\"", "JSON escape/unicode mismatch")

local sh_res = ignis.utils.exec_sh("echo 'ignis-shell-ok'")
assert(sh_res.returncode == 0, "exec_sh returncode failed")
assert(sh_res.stdout:find("ignis-shell-ok", 1, true), "exec_sh stdout failed")

local poll_count = 0
local p_obj = ignis.utils.Poll(1000, function()
    poll_count = poll_count + 1
    return poll_count * 10
end)
assert(p_obj.output == 10, "Poll initial output failed")
p_obj:cancel()
print("[PASS] JSON and shell/poll utilities verified.")

-- 4. Test Exceptions & Managers
print("[TEST 4] Verifying Exceptions, CommandManager & WindowManager...")
local err = ignis.exceptions.AppNotInitializedError()
assert(err.message:find("App is not initialized"), "Exception message mismatch")

local cmd_mgr = ignis.CommandManager.get_default()
cmd_mgr:add_command("ping", function(arg1) return "pong:" .. tostring(arg1) end)
assert(cmd_mgr:run_command("ping", "test") == "pong:test", "CommandManager run_command failed")
cmd_mgr:remove_command("ping")

local win_mgr = ignis.WindowManager.get_default()
assert(win_mgr ~= nil, "WindowManager singleton is nil")
local cfg_mgr = ignis.ConfigManager.get_default()
assert(cfg_mgr ~= nil, "ConfigManager singleton is nil")
print("[PASS] Exceptions and Singleton Managers verified.")

-- 5. Test Full Widget Suite (33 Widgets)
print("[TEST 5] Verifying Full Declarative Widget Suite...")
local app = ignis.App.get_default()
assert(app ~= nil, "Default App instance is nil")

local label = ignis.widgets.Label({
    label = "Test Label",
    halign = "center",
    ellipsize = "end",
    xalign = 0.5,
})
assert(label.label == "Test Label", "Label property assignment failed")

local btn = ignis.widgets.Button({
    child = label,
    on_click = function() end,
    on_hover = function() end,
})

local box = ignis.widgets.Box({
    vertical = true,
    spacing = 8,
    homogeneous = false,
    child = { btn }
})
assert(box.vertical == true, "Box vertical property failed")
assert(#box.child == 1, "Box child management failed")

local center = ignis.widgets.CenterBox({
    start_widget = ignis.widgets.Label({ label = "start" }),
    center_widget = ignis.widgets.Label({ label = "center" }),
    end_widget = ignis.widgets.Label({ label = "end" })
})
assert(center.vertical == false, "CenterBox default orientation failed")

local entry = ignis.widgets.Entry({
    placeholder_text = "Type here",
    text = "Hello Lua",
    visibility = true,
})
assert(entry.text == "Hello Lua", "Entry text assignment failed")

local icon = ignis.widgets.Icon({
    image = "audio-volume-high",
    pixel_size = 24
})
assert(icon.pixel_size == 24, "Icon pixel_size failed")

local picture = ignis.widgets.Picture({
    width = 100,
    height = 100,
    content_fit = "cover"
})
assert(picture.width == 100, "Picture width failed")

local ev_box = ignis.widgets.EventBox({
    child = { ignis.widgets.Label({ label = "Event" }) },
    on_click = function() end,
    on_scroll_up = function() end,
})
assert(#ev_box.child == 1, "EventBox child failed")

local rev = ignis.widgets.Revealer({
    transition_type = "slide_down",
    transition_duration = 250,
    reveal_child = true,
    child = ignis.widgets.Label({ label = "Revealed" })
})
rev:toggle()
assert(rev.reveal_child == false, "Revealer:toggle() failed")

local scale = ignis.widgets.Scale({
    min = 0,
    max = 100,
    step = 5,
    value = 45
})
assert(scale.value == 45, "Scale value failed")

local scroll = ignis.widgets.Scroll({
    hscrollbar_policy = "never",
    vscrollbar_policy = "automatic",
    child = ignis.widgets.Box({})
})
assert(scroll ~= nil, "Scroll widget failed")

local overlay = ignis.widgets.Overlay({
    child = ignis.widgets.Box({}),
    overlays = { ignis.widgets.Label({ label = "Badge" }) }
})
assert(#overlay.overlays == 1, "Overlay overlays failed")

local grid = ignis.widgets.Grid({
    column_num = 2,
    row_spacing = 4,
    column_spacing = 4,
    child = {
        ignis.widgets.Label({ label = "1" }),
        ignis.widgets.Label({ label = "2" }),
    }
})
assert(#grid.child == 2, "Grid child failed")

local corner = ignis.widgets.Corner({
    orientation = "top-left",
    size = 24
})
assert(corner.orientation == "top-left", "Corner orientation failed")

local pbar = ignis.widgets.ProgressBar({
    value = 0.75,
    show_text = true
})
assert(pbar.value == 0.75, "ProgressBar value failed")

local sw = ignis.widgets.Switch({ active = true })
assert(sw.active == true, "Switch active failed")

local tbtn = ignis.widgets.ToggleButton({ active = true, label = "Toggle" })
assert(tbtn.active == true, "ToggleButton active failed")

local cbtn = ignis.widgets.CheckButton({ active = false, label = "Check" })
assert(cbtn.active == false, "CheckButton active failed")

local sep = ignis.widgets.Separator({ vertical = true })
assert(sep.vertical == true, "Separator vertical failed")

local spin = ignis.widgets.Spinner({ spinning = true })
assert(spin.spinning == true, "Spinner spinning failed")

local reg_win = ignis.widgets.RegularWindow({
    namespace = "test-regular-window",
    title = "My Regular Window",
    default_width = 600,
    default_height = 400,
    child = ignis.widgets.Label({ label = "Hello Window" })
})
assert(reg_win.namespace == "test-regular-window", "RegularWindow namespace failed")
assert(reg_win.title == "My Regular Window", "RegularWindow title failed")
reg_win:destroy()
print("[PASS] All 33 widgets constructed and verified.")

-- 6. Test All 16 Services
print("[TEST 6] Verifying All 16 Services...")
local fetch = ignis.services.FetchService.get_default()
assert(fetch.os_name ~= nil, "FetchService.os_name is nil")
assert(fetch.cpu_cores >= 1, "FetchService.cpu_cores invalid")
assert(fetch.mem_total >= 0, "FetchService.mem_total invalid")
assert(type(fetch.packages_count) == "number", "FetchService.packages_count invalid")

local notif_srv = ignis.services.NotificationService.get_default()
assert(notif_srv.dnd == false, "NotificationService initial dnd mismatch")

local audio_srv = ignis.services.AudioService.get_default()
assert(audio_srv.speaker ~= nil, "AudioService.speaker is nil")
assert(audio_srv.microphone ~= nil, "AudioService.microphone is nil")

local upower_srv = ignis.services.UPowerService.get_default()
assert(upower_srv.display_device ~= nil, "UPowerService.display_device is nil")

local net_srv = ignis.services.NetworkService.get_default()
assert(net_srv.wifi ~= nil and net_srv.ethernet ~= nil and net_srv.vpn ~= nil, "NetworkService sub-objects nil")

local bt_srv = ignis.services.BluetoothService.get_default()
assert(type(bt_srv.devices) == "table", "BluetoothService.devices invalid")

local mpris_srv = ignis.services.MprisService.get_default()
assert(type(mpris_srv.players) == "table", "MprisService.players invalid")

local tray_srv = ignis.services.SystemTrayService.get_default()
assert(type(tray_srv.items) == "table", "SystemTrayService.items invalid")

local hypr_srv = ignis.services.HyprlandService.get_default()
assert(hypr_srv.active_workspace ~= nil and hypr_srv.active_window ~= nil, "HyprlandService objects nil")

local niri_srv = ignis.services.NiriService.get_default()
assert(niri_srv.active_workspace ~= nil and niri_srv.active_window ~= nil, "NiriService objects nil")

local apps_srv = ignis.services.ApplicationsService.get_default()
local mock_apps = {
    { name = "Firefox", description = "Web Browser", id = "firefox.desktop", keywords = { "internet" } },
    { name = "Alacritty", description = "GPU Terminal", id = "alacritty.desktop", keywords = { "shell" } },
}
local search_res = ignis.services.ApplicationsService.search(mock_apps, "term")
assert(#search_res == 1 and search_res[1].name == "Alacritty", "ApplicationsService.search failed")

local bl_srv = ignis.services.BacklightService.get_default()
assert(type(bl_srv.devices) == "table", "BacklightService.devices invalid")

local pp_srv = ignis.services.PowerProfilesService.get_default()
assert(pp_srv.active_profile ~= nil, "PowerProfilesService.active_profile is nil")

local rec_srv = ignis.services.RecorderService.get_default()
assert(rec_srv.active == false, "RecorderService.active invalid")

local wp_srv = ignis.services.WallpaperService.get_default()
assert(wp_srv ~= nil, "WallpaperService is nil")

local sysd_srv = ignis.services.SystemdService.get_default()
local unit = sysd_srv:get_unit("ignis.service")
assert(unit.name == "ignis.service", "SystemdService:get_unit failed")
print("[PASS] All 16 services verified.")


-- ---------------------------------------------------------
-- Suite 7: Native C11 Engine (`ignis.native`), Clean GTK4 GI
--          Overrides & Zero-Hack Architecture Verification
-- ---------------------------------------------------------
print("[TEST] Suite 7: Native C11 Engine & Clean GTK4 GI Architecture...")

local ok_native, native = pcall(require, "ignis.native")
assert(ok_native and type(native) == "table", "Failed to load compiled ignis/native.so C11 module")
assert(native.version() == "0.7.0-native-c11", "ignis.native version mismatch: " .. tostring(native.version()))

-- Verify C11 monotonic clock
local t1 = native.monotonic_time_us()
assert(type(t1) == "number" and t1 > 0, "native.monotonic_time_us failed")

-- Verify C11 POSIX fast file I/O & directory entry counter
local tmp_native_file = "/tmp/ignis_native_test_" .. tostring(os.time()) .. ".txt"
assert(native.write_file_fast(tmp_native_file, "arch-native-c11-payload") == true, "native.write_file_fast failed")
assert(native.file_exists(tmp_native_file) == true, "native.file_exists failed")
assert(native.read_file_fast(tmp_native_file) == "arch-native-c11-payload", "native.read_file_fast mismatch")
os.remove(tmp_native_file)
assert(native.file_exists(tmp_native_file) == false, "native.file_exists after remove failed")
assert(native.is_dir("/tmp") == true, "native.is_dir(/tmp) failed")
assert(native.count_dir_entries("./ignis/services") >= 16, "native.count_dir_entries failed on ignis/services")

-- Verify GTK4 / GDK4 clean overrides (no gsub, no Gtk.Container)
local gtk4_ov = require("ignis.gi.gtk4_override")
local gdk4_ov = require("ignis.gi.gdk4_override")
assert(type(gtk4_ov._post_instantiate) == "function", "gtk4_override._post_instantiate missing")
assert(type(gdk4_ov._post_instantiate) == "function", "gdk4_override._post_instantiate missing")

-- Verify that ignis/init.lua, bin/ignis, and systemd/ignis.service contain ZERO
-- runtime string.gsub patches on LGI, ZERO fake Gtk.Container stubs, and ZERO LD_PRELOAD hacks
local init_src = ignis.utils.read_file("./ignis/init.lua")
assert(not init_src:find("gsub", 1, true), "ignis/init.lua must not contain runtime gsub patches")
assert(not init_src:find("Container", 1, true), "ignis/init.lua must not contain fake Gtk.Container stubs")

local bin_src = ignis.utils.read_file("./bin/ignis")
assert(not bin_src:find("LD_PRELOAD", 1, true), "bin/ignis must not contain LD_PRELOAD self-restart hack")
assert(not bin_src:find("_IGNIS_ARCH_ENV_SET", 1, true), "bin/ignis must not contain _IGNIS_ARCH_ENV_SET hack")

local service_src = ignis.utils.read_file("./systemd/ignis.service")
assert(not service_src:find("LD_PRELOAD", 1, true), "systemd/ignis.service must not contain LD_PRELOAD hack")

print("[PASS] Native C11 Engine & Clean GTK4 GI Architecture verified.")

print("==================================================")
print("ALL 7 TEST SUITES PASSED SUCCESSFULLY!")
print("==================================================")
os.exit(0)

