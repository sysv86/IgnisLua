{
  lib,
  stdenv,
  makeWrapper,
  self,
  lua5_5,
  lgi,
  gtk4,
  gtk4-layer-shell,
  glib,
  gobject-introspection,
  gdk-pixbuf,
  librsvg,
  pango,
  harfbuzz,
  graphene,
  cairo,
  ignis-gvc,
  networkmanager,
  gnome-bluetooth,
  gpu-screen-recorder,
  upower,
  power-profiles-daemon,
  dart-sass,
  grass-sass,
  enableAudioService ? true,
  enableNetworkService ? false,
  enableRecorderService ? false,
  enableBluetoothService ? false,
  useDartSass ? true,
  useGrassSass ? false,
  extraPackages ? [],
}: let
  runtimeBins =
    lib.optional enableRecorderService gpu-screen-recorder
    ++ lib.optional useDartSass dart-sass
    ++ lib.optional useGrassSass grass-sass
    ++ extraPackages;

  typelibPackages =
    [
      gtk4
      gtk4-layer-shell
      glib.out
      gobject-introspection
      gdk-pixbuf
      librsvg
      pango
      harfbuzz
      graphene
      upower
    ]
    ++ lib.optional enableNetworkService networkmanager
    ++ lib.optional enableBluetoothService gnome-bluetooth;

  libraryPackages =
    [
      gtk4
      gtk4-layer-shell
      glib.out
      gdk-pixbuf
      librsvg
      pango
      cairo
      upower
    ]
    ++ lib.optional enableAudioService ignis-gvc
    ++ lib.optional enableNetworkService networkmanager
    ++ lib.optional enableBluetoothService gnome-bluetooth;

  giTypelibPath =
    lib.optionalString enableAudioService "${ignis-gvc}/lib/ignis-gvc:"
    + lib.makeSearchPath "lib/girepository-1.0" typelibPackages;

  ldLibraryPath =
    lib.optionalString enableAudioService "${ignis-gvc}/lib/ignis-gvc:"
    + lib.makeLibraryPath libraryPackages;
in
  stdenv.mkDerivation {
    pname = "ignis-lua";
    version = "0.6.0-lua5.5.1";
    src = self;

    nativeBuildInputs = [makeWrapper];
    buildInputs = [lua5_5 lgi];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/lua/5.5" "$out/bin"
      cp -r ignis "$out/share/lua/5.5/"
      install -Dm755 bin/ignis "$out/bin/ignis"

      wrapProgram "$out/bin/ignis" \
        --prefix PATH : "${lib.makeBinPath ([lua5_5] ++ runtimeBins)}" \
        --prefix GI_TYPELIB_PATH : "${giTypelibPath}" \
        --prefix LD_LIBRARY_PATH : "${ldLibraryPath}" \
        --prefix LUA_PATH ";" "$out/share/lua/5.5/?.lua;$out/share/lua/5.5/?/init.lua;${lgi}/share/lua/5.5/?.lua;${lgi}/share/lua/5.5/?/init.lua" \
        --prefix LUA_CPATH ";" "${lgi}/lib/lua/5.5/?.so"

      runHook postInstall
    '';

    meta = with lib; {
      description = "A high-performance reactive GTK4 widget framework for building Wayland desktop shells in Lua 5.5.1";
      homepage = "https://github.com/ignis-sh/ignis";
      license = licenses.lgpl21Plus;
      platforms = platforms.linux;
      mainProgram = "ignis";
    };
  }
