/*
 * src/ignis_launcher.c
 * Native C Binary Entrypoint for IgnisLua (/usr/bin/ignis).
 *
 * 1. Binds libgtk4-layer-shell.so.0 and /usr/lib/ignis-gvc/libgvc.so into
 *    RTLD_GLOBAL at the very start of main() BEFORE libwayland-client.so.0 or
 *    libgtk-4.so.1 can ever be loaded.
 * 2. Eliminates LD_PRELOAD, LD_LIBRARY_PATH, GI_TYPELIB_PATH, and process
 *    self-re-execution completely.
 * 3. Embeds or dynamically invokes the system Lua 5.5 / 5.4 / 5.3 VM in-process.
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

typedef struct lua_State lua_State;

static void preload_wayland_layer_shell_and_gvc(void) {
    static const char *const layer_libs[] = {
        "libgtk4-layer-shell.so.0",
        "/usr/lib/libgtk4-layer-shell.so.0",
        "/usr/lib/libgtk4-layer-shell.so",
        "/usr/local/lib/libgtk4-layer-shell.so.0",
        NULL
    };
    for (int i = 0; layer_libs[i] != NULL; i++) {
        if (dlopen(layer_libs[i], RTLD_NOW | RTLD_GLOBAL) != NULL) {
            break;
        }
    }

    static const char *const gvc_dirs[] = {
        "/usr/lib/ignis-gvc",
        "/usr/local/lib/ignis-gvc",
        NULL
    };
    for (int i = 0; gvc_dirs[i] != NULL; i++) {
        struct stat st;
        if (stat(gvc_dirs[i], &st) == 0 && S_ISDIR(st.st_mode)) {
            char lib_path[512];
            snprintf(lib_path, sizeof(lib_path), "%s/libgvc.so", gvc_dirs[i]);
            dlopen(lib_path, RTLD_NOW | RTLD_GLOBAL);
        }
    }
}

int main(int argc, char **argv) {
    if (getenv("IGNIS_NO_PRELOAD") == NULL) {
        preload_wayland_layer_shell_and_gvc();
    }

    static const char *const lua_libs[] = {
        "liblua.so.5.5", "liblua5.5.so", "liblua.so.5.4", "liblua5.4.so",
        "liblua.so.5.3", "liblua5.3.so", "libtexlua53.so.5", "libluajit-5.1.so.2",
        "liblua.so", NULL
    };

    void *lua_h = NULL;
    for (int i = 0; lua_libs[i] != NULL; i++) {
        lua_h = dlopen(lua_libs[i], RTLD_NOW | RTLD_GLOBAL);
        if (lua_h && dlsym(lua_h, "luaL_newstate")) {
            break;
        }
    }

    if (!lua_h) {
        fprintf(stderr, "[ignis] Fatal: Could not load liblua.so (5.5 / 5.4 / 5.3).\n");
        return 1;
    }

    lua_State *(*fn_newstate)(void) = (lua_State *(*)(void))dlsym(lua_h, "luaL_newstate");
    void (*fn_close)(lua_State *) = (void (*)(lua_State *))dlsym(lua_h, "lua_close");
    void (*fn_createtable)(lua_State *, int, int) = (void (*)(lua_State *, int, int))dlsym(lua_h, "lua_createtable");
    const char *(*fn_pushstring)(lua_State *, const char *) = (const char *(*)(lua_State *, const char *))dlsym(lua_h, "lua_pushstring");
    void (*fn_rawseti)(lua_State *, int, long) = (void (*)(lua_State *, int, long))dlsym(lua_h, "lua_rawseti");
    void (*fn_setglobal)(lua_State *, const char *) = (void (*)(lua_State *, const char *))dlsym(lua_h, "lua_setglobal");
    void (*fn_settop)(lua_State *, int) = (void (*)(lua_State *, int))dlsym(lua_h, "lua_settop");
    int (*fn_loadstring)(lua_State *, const char *) = (int (*)(lua_State *, const char *))dlsym(lua_h, "luaL_loadstring");
    int (*fn_pcallk)(lua_State *, int, int, int, long, void *) = (int (*)(lua_State *, int, int, int, long, void *))dlsym(lua_h, "lua_pcallk");
    int (*fn_pcall)(lua_State *, int, int, int) = (int (*)(lua_State *, int, int, int))dlsym(lua_h, "lua_pcall");
    const char *(*fn_tolstring)(lua_State *, int, size_t *) = (const char *(*)(lua_State *, int, size_t *))dlsym(lua_h, "lua_tolstring");
    long long (*fn_tointegerx)(lua_State *, int, int *) = (long long (*)(lua_State *, int, int *))dlsym(lua_h, "lua_tointegerx");
    void (*fn_openlibs)(lua_State *) = (void (*)(lua_State *))dlsym(lua_h, "luaL_openlibs");
    void (*fn_requiref)(lua_State *, const char *, int (*)(lua_State *), int) =
        (void (*)(lua_State *, const char *, int (*)(lua_State *), int))dlsym(lua_h, "luaL_requiref");

    if (!fn_newstate || !fn_close || !fn_createtable || !fn_pushstring ||
        !fn_rawseti || !fn_setglobal || !fn_settop || !fn_loadstring ||
        (!fn_pcallk && !fn_pcall) || !fn_tolstring) {
        fprintf(stderr, "[ignis] Fatal: the loaded liblua is missing required symbols.\n");
        return 1;
    }

    lua_State *L = fn_newstate();
    if (!L) {
        fprintf(stderr, "[ignis] Fatal: luaL_newstate() failed.\n");
        return 1;
    }

    if (fn_requiref) {
        static const struct { const char *name; const char *sym; } libs[] = {
            { "_G",        "luaopen_base" },
            { "package",   "luaopen_package" },
            { "coroutine", "luaopen_coroutine" },
            { "table",     "luaopen_table" },
            { "io",        "luaopen_io" },
            { "os",        "luaopen_os" },
            { "string",    "luaopen_string" },
            { "math",      "luaopen_math" },
            { "utf8",      "luaopen_utf8" },
            { "debug",     "luaopen_debug" },
            { NULL, NULL }
        };
        for (int i = 0; libs[i].name != NULL; i++) {
            int (*openf)(lua_State *) = (int (*)(lua_State *))dlsym(lua_h, libs[i].sym);
            if (openf) {
                fn_requiref(L, libs[i].name, openf, 1);
                fn_settop(L, 0);
            }
        }
    } else if (fn_openlibs) {
        fn_openlibs(L);
    } else {
        fprintf(stderr, "[ignis] Fatal: could not open the Lua standard libraries.\n");
        fn_close(L);
        return 1;
    }

    fn_createtable(L, argc, 2);
    for (int i = 0; i < argc; i++) {
        fn_pushstring(L, argv[i]);
        fn_rawseti(L, -2, i);
    }
    fn_setglobal(L, "arg");

    const char *bootstrap =
        "local exe = (arg and arg[0]) or ''\n"
        "local bin_dir = exe:match('^(.*)/[^/]+$') or '.'\n"
        "local root_dir = bin_dir .. '/..'\n"
        "local share_dir = os.getenv('IGNIS_LUA_SHARE')\n"
        "    or root_dir .. '/deps/install/share/lua/5.5'\n"
        "package.path = table.concat({\n"
        "    root_dir .. '/?.lua',\n"
        "    root_dir .. '/?/init.lua',\n"
        "    share_dir .. '/?.lua',\n"
        "    share_dir .. '/?/init.lua',\n"
        "    '/usr/share/lua/5.5/?.lua',\n"
        "    '/usr/share/lua/5.5/?/init.lua',\n"
        "    '/usr/local/share/lua/5.5/?.lua',\n"
        "    '/usr/local/share/lua/5.5/?/init.lua',\n"
        "    package.path\n"
        "}, ';')\n"
        "package.cpath = table.concat({\n"
        "    root_dir .. '/?.so',\n"
        "    root_dir .. '/deps/install/lib/lua/5.5/?.so',\n"
        "    '/usr/lib/lua/5.5/?.so',\n"
        "    '/usr/local/lib/lua/5.5/?.so',\n"
        "    package.cpath\n"
        "}, ';')\n"
        "pcall(require, 'ignis.native')\n"
        "local cli = require('ignis.cli')\n"
        "return cli.run(arg)\n";

    if (fn_loadstring(L, bootstrap) != 0) {
        fprintf(stderr, "[ignis] Bootstrap error: %s\n", fn_tolstring(L, -1, NULL));
        fn_close(L);
        return 1;
    }

    int rc = fn_pcallk ? fn_pcallk(L, 0, 1, 0, 0, NULL) : fn_pcall(L, 0, 1, 0);
    if (rc != 0) {
        fprintf(stderr, "[ignis] Runtime error: %s\n", fn_tolstring(L, -1, NULL));
        fn_close(L);
        return 1;
    }

    int exit_code = 0;
    if (fn_tointegerx) {
        int isnum = 0;
        long long v = fn_tointegerx(L, -1, &isnum);
        if (isnum) exit_code = (int)v;
    }
    fn_close(L);
    return exit_code;
}
