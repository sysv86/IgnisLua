{pkgs}: let
  # Official Lua 5.5.1 release (2026-07-24 / 2026-08-25) from lua.org/ftp
  lua5_5 =
    if pkgs ? lua5_5
    then pkgs.lua5_5
    else
      pkgs.lua5_4.overrideAttrs (old: rec {
        pname = "lua";
        version = "5.5.1";
        luaversion = "5.5";

        src = pkgs.fetchurl {
          url = "https://www.lua.org/ftp/lua-${version}.tar.gz";
          sha256 = "1c4b4068d67061f2a2231ad2b5422e77acea1487ea9890f6320af614f4373dce";
        };

        patches = [];

        makeFlags = [
          "INSTALL_TOP=${placeholder "out"}"
          "INSTALL_MAN=${placeholder "out"}/share/man/man1"
          "R=${version}"
          "V=${luaversion}"
          "PLAT=linux"
          "CC=${pkgs.stdenv.cc.targetPrefix}cc"
          "RANLIB=${pkgs.stdenv.cc.targetPrefix}ranlib"
          "MYCFLAGS=-fPIC -DLUA_USE_LINUX -DLUA_COMPAT_5_3"
          "MYLIBS=-lreadline -lncurses -ldl -lm"
        ];

        postInstall = ''
          mkdir -p "$out/lib/pkgconfig" "$out/lib/lua/${luaversion}" "$out/share/lua/${luaversion}"
          cat > "$out/lib/pkgconfig/lua.pc" <<EOF
          prefix=$out
          exec_prefix=''${prefix}
          libdir=''${exec_prefix}/lib
          includedir=''${prefix}/include

          Name: Lua
          Description: An Extensible Extension Language
          Version: ${version}
          Requires:
          Libs: -L''${libdir} -llua -lm -ldl
          Cflags: -I''${includedir}
          EOF
          ln -sf "$out/lib/pkgconfig/lua.pc" "$out/lib/pkgconfig/lua5.5.pc"
          ln -sf "$out/lib/pkgconfig/lua.pc" "$out/lib/pkgconfig/lua-5.5.pc"
        '';
      });

  lgi = pkgs.stdenv.mkDerivation {
    pname = "lua5.5-lgi";
    version = "0.9.2-lua55";

    src = pkgs.fetchFromGitHub {
      owner = "lgi-devs";
      repo = "lgi";
      rev = "7a2276f3b0267f32bc88ce7fb827ff9cd2afbd45";
      sha256 = "sha256-Up2t5d6E5h1bF7D0n2gN3b1S7A0yW2pQ8r3V4xY5z6A=";
    };

    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.gobject-introspection
    ];

    buildInputs = [
      lua5_5
      pkgs.glib
      pkgs.gobject-introspection
      pkgs.libffi
    ];

    env.NIX_CFLAGS_COMPILE = "-DLUA_COMPAT_5_3 -DLUA_COMPAT_APIINTCASTS -fPIC";

    buildPhase = ''
      runHook preBuild
      make -j$NIX_BUILD_CORES \
        LUA_VERSION=5.5 \
        LUA_INCDIR="${lua5_5}/include" \
        CFLAGS="$NIX_CFLAGS_COMPILE -I${lua5_5}/include"
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/lua/5.5/lgi" "$out/share/lua/5.5"
      cp -r lgi "$out/share/lua/5.5/"
      cp lgi/corelgilua51.so "$out/lib/lua/5.5/lgi/corelgilua51.so"
      runHook postInstall
    '';
  };
in {
  lua = lua5_5;
  inherit lgi;
}
