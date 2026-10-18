#!/usr/bin/env bash
set -euo pipefail

# On Arch Linux, Lua 5.5 and GI packages are available directly in [extra].
if command -v pacman >/dev/null 2>&1 && [ "${FORCE_SOURCE_BUILD:-0}" != "1" ]; then
    echo "[INFO] Arch Linux detected! Delegating to scripts/setup_arch.sh (set FORCE_SOURCE_BUILD=1 to compile Lua 5.5.1 from source)."
    exec "$(dirname "$0")/setup_arch.sh" "$@"
fi

PROJECT_ROOT=$(pwd)
DEPS_DIR="$PROJECT_ROOT/deps"
INSTALL_DIR="$DEPS_DIR/install"
LUA_VERSION="5.5.1"
LUA_SHORT_VER="5.5"
LUA_TARBALL="lua-${LUA_VERSION}.tar.gz"
LUA_URL="https://www.lua.org/ftp/${LUA_TARBALL}"
LUA_SHA256="1c4b4068d67061f2a2231ad2b5422e77acea1487ea9890f6320af614f4373dce"

mkdir -p "$DEPS_DIR" "$INSTALL_DIR"

# 1. Build Lua 5.5.1
cd "$DEPS_DIR"
if [ ! -d "lua-${LUA_VERSION}" ]; then
    echo "[INFO] Downloading Lua ${LUA_VERSION} from ${LUA_URL}..."
    if curl -fsSL "$LUA_URL" -o "$LUA_TARBALL"; then
        echo "${LUA_SHA256}  ${LUA_TARBALL}" | sha256sum -c -
        tar -xzf "$LUA_TARBALL"
        rm -f "$LUA_TARBALL"
    else
        echo "[WARN] Release tarball download failed; falling back to git clone..."
        git clone --depth 1 https://github.com/lua/lua.git "lua-${LUA_VERSION}"
    fi
fi

cd "lua-${LUA_VERSION}"
if [ -d "src" ]; then
    make -C src -j"$(nproc)" linux         MYCFLAGS="-O2 -fPIC -DLUA_USE_LINUX -DLUA_COMPAT_5_3"         MYLIBS="-lreadline -lncurses -ldl -lm"
    mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/include" "$INSTALL_DIR/lib"
    cp src/lua "$INSTALL_DIR/bin/"
    [ -f src/luac ] && cp src/luac "$INSTALL_DIR/bin/" || true
    cp src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h src/lua.hpp "$INSTALL_DIR/include/" 2>/dev/null || true
    cp src/liblua.a "$INSTALL_DIR/lib/"
    gcc -shared -o "$INSTALL_DIR/lib/liblua.so" -Wl,--whole-archive src/liblua.a -Wl,--no-whole-archive -lm -ldl -lreadline
else
    sed -i 's/CFLAGS= -Wall/CFLAGS= -Wall -O2 -fPIC -DLUA_USE_LINUX -DLUA_COMPAT_5_3/' makefile
    make -j"$(nproc)" all MYLIBS="-lreadline -lncurses -ldl -lm"
    mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/include" "$INSTALL_DIR/lib"
    cp lua "$INSTALL_DIR/bin/"
    [ -f luac ] && cp luac "$INSTALL_DIR/bin/" || true
    cp lua.h luaconf.h lualib.h lauxlib.h "$INSTALL_DIR/include/"
    cp liblua.a "$INSTALL_DIR/lib/"
    gcc -shared -o "$INSTALL_DIR/lib/liblua.so" -Wl,--whole-archive liblua.a -Wl,--no-whole-archive -lm -ldl -lreadline
fi

ln -sf "$INSTALL_DIR/bin/lua" "$INSTALL_DIR/bin/lua5.5"

mkdir -p "$INSTALL_DIR/lib/pkgconfig"
printf "prefix=%s\nexec_prefix=\${prefix}\nlibdir=\${exec_prefix}/lib\nincludedir=\${prefix}/include\n\nName: Lua\nDescription: An Extensible Extension Language\nVersion: %s\nRequires:\nLibs: -L\${libdir} -llua -lm -ldl -lreadline\nCflags: -I\${includedir}\n" "$INSTALL_DIR" "$LUA_VERSION" > "$INSTALL_DIR/lib/pkgconfig/lua.pc"
ln -sf "$INSTALL_DIR/lib/pkgconfig/lua.pc" "$INSTALL_DIR/lib/pkgconfig/lua5.5.pc"
ln -sf "$INSTALL_DIR/lib/pkgconfig/lua.pc" "$INSTALL_DIR/lib/pkgconfig/lua-5.5.pc"

# 2. Build GI C Core with Lua 5.4/5.5 lua_resume patch and replace GTK3 overrides with native GTK4 overrides
cd "$DEPS_DIR"
if [ ! -d "lgi" ]; then
    git clone https://github.com/lgi-devs/lgi.git
fi
cd lgi

# Patch callable.c for Lua 5.4 / 5.5 4-argument lua_resume ABI
if grep -q "lua_resume (L, NULL," lgi/callable.c 2>/dev/null; then
    sed -i 's/lua_resume (L, NULL, npos)/#if LUA_VERSION_NUM >= 504
  { int nres = 0; res = lua_resume (L, NULL, npos, \&nres); }
#else
  res = lua_resume (L, NULL, npos);
#endif/' lgi/callable.c || true
fi

export PKG_CONFIG_PATH="$INSTALL_DIR/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export LUA_VERSION="$LUA_SHORT_VER"
export LUA_INCDIR="$INSTALL_DIR/include"
export LUA_LIBDIR="$INSTALL_DIR/lib"
export CFLAGS="-O2 -fPIC -DLUA_COMPAT_5_3 -DLUA_COMPAT_APIINTCASTS -I$INSTALL_DIR/include"

make -j"$(nproc)" LUA="$INSTALL_DIR/bin/lua" PKG_CONFIG="pkg-config lua" CFLAGS="$CFLAGS"

mkdir -p "$INSTALL_DIR/lib/lua/${LUA_SHORT_VER}/lgi"
mkdir -p "$INSTALL_DIR/share/lua/${LUA_SHORT_VER}"
cp -r lgi "$INSTALL_DIR/share/lua/${LUA_SHORT_VER}/"
cp lgi/corelgilua51.so "$INSTALL_DIR/lib/lua/${LUA_SHORT_VER}/lgi/corelgilua51.so"

# Replace legacy GTK3 overrides directly with IgnisLua native GTK4 overrides
cp "$PROJECT_ROOT/ignis/gi/gtk4_override.lua" "$INSTALL_DIR/share/lua/${LUA_SHORT_VER}/lgi/override/Gtk.lua"
cp "$PROJECT_ROOT/ignis/gi/gdk4_override.lua" "$INSTALL_DIR/share/lua/${LUA_SHORT_VER}/lgi/override/Gdk.lua"

# 3. Build IgnisLua C11 Native Engine & Launcher
cd "$PROJECT_ROOT"
make native

echo "Lua ${LUA_VERSION}, GTK4 GI Core, and IgnisLua Native C11 Engine setup complete in $INSTALL_DIR"
