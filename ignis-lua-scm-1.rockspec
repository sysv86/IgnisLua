package = "ignis-lua"
version = "scm-1"
source = {
   url = "git+https://github.com/sysv86/IgnisLua.git"
}
description = {
   summary = "High-performance reactive GTK4 widget framework for Wayland desktop shells in Lua 5.5",
   detailed = [[
      IgnisLua is a full-featured, ultra-low footprint reactive GTK4 & Gtk4LayerShell
      widget and service framework for Wayland desktop shells in Lua 5.5 / LuaJIT.
   ]],
   homepage = "https://github.com/sysv86/IgnisLua",
   license = "LGPL-2.1-or-later"
}
dependencies = {
   "lua >= 5.1",
   "lgi >= 0.9.2"
}
build = {
   type = "builtin",
   modules = {
      ["ignis"] = "ignis/init.lua",
      ["ignis.app"] = "ignis/app.lua",
      ["ignis.base_widget"] = "ignis/base_widget.lua",
      ["ignis.cli"] = "ignis/cli.lua",
      ["ignis.command_manager"] = "ignis/command_manager.lua",
      ["ignis.config_manager"] = "ignis/config_manager.lua",
      ["ignis.css_manager"] = "ignis/css_manager.lua",
      ["ignis.dbus"] = "ignis/dbus.lua",
      ["ignis.exceptions"] = "ignis/exceptions.lua",
      ["ignis.gobject"] = "ignis/gobject.lua",
      ["ignis.icon_manager"] = "ignis/icon_manager.lua",
      ["ignis.ipc"] = "ignis/ipc.lua",
      ["ignis.variable"] = "ignis/variable.lua",
      ["ignis.window_manager"] = "ignis/window_manager.lua",
   },
   install = {
      bin = {
         ["ignis"] = "bin/ignis"
      }
   }
}
