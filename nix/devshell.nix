{
  self,
  pkgs,
  ignis-gvc,
  lua5_5 ? (import ./lua55.nix {inherit pkgs;}).lua,
  lgi ? (import ./lua55.nix {inherit pkgs;}).lgi,
}: let
  deps = with pkgs; [
    lua5_5
    lgi
    gnome-bluetooth
    gpu-screen-recorder
    ignis-gvc
    networkmanager
    upower
    power-profiles-daemon
    dart-sass
    grass-sass
    gtk4
    gtk4-layer-shell
    gobject-introspection
    librsvg
    gdk-pixbuf
    pango
    cairo
    glib
    readline
    ncurses
    pkg-config
    libffi
    lua-language-server
    stylua
  ];

  typelibPaths = pkgs.lib.makeSearchPath "lib/girepository-1.0" [
    pkgs.gtk4
    pkgs.gtk4-layer-shell
    pkgs.gdk-pixbuf
    pkgs.librsvg
    pkgs.pango
    pkgs.harfbuzz
    pkgs.graphene
    pkgs.glib.out
    pkgs.gobject-introspection
    pkgs.networkmanager
    pkgs.gnome-bluetooth
    pkgs.upower
  ];

  ldLibraryPaths = pkgs.lib.makeLibraryPath [
    pkgs.gtk4
    pkgs.gtk4-layer-shell
    pkgs.glib.out
    pkgs.gdk-pixbuf
    pkgs.librsvg
    pkgs.pango
    pkgs.cairo
    pkgs.networkmanager
    pkgs.gnome-bluetooth
    ignis-gvc
  ];
in {
  default = pkgs.mkShell {
    packages = deps;

    GI_TYPELIB_PATH = "${ignis-gvc}/lib/ignis-gvc:${typelibPaths}";
    LD_LIBRARY_PATH = "${ignis-gvc}/lib/ignis-gvc:${ldLibraryPaths}";

    shellHook = ''
      export PATH="$PWD/bin:$PWD/deps/install/bin:${lua5_5}/bin:$PATH"
      export LUA_PATH="$PWD/?.lua;$PWD/?/init.lua;${lgi}/share/lua/5.5/?.lua;${lgi}/share/lua/5.5/?/init.lua;$PWD/deps/install/share/lua/5.5/?.lua;$PWD/deps/install/share/lua/5.5/?/init.lua;;"
      export LUA_CPATH="${lgi}/lib/lua/5.5/?.so;$PWD/deps/install/lib/lua/5.5/?.so;;"
    '';
  };
}
