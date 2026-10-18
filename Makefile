PREFIX ?= /usr
DESTDIR ?=
LUA_VERSION ?= 5.5
CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -fPIC
LDFLAGS ?=

BINDIR := $(DESTDIR)$(PREFIX)/bin
LUADIR := $(DESTDIR)$(PREFIX)/share/lua/$(LUA_VERSION)
LUACDIR := $(DESTDIR)$(PREFIX)/lib/lua/$(LUA_VERSION)
SYSTEMD_USER_DIR := $(DESTDIR)$(PREFIX)/lib/systemd/user
DOCDIR := $(DESTDIR)$(PREFIX)/share/doc/ignis-lua

.PHONY: all native clean install uninstall test

all: native

native: ignis/native.so bin/ignis-bin

ignis/native.so: src/ignis_native.c
	$(CC) $(CFLAGS) -shared src/ignis_native.c -o ignis/native.so $(LDFLAGS) -ldl

bin/ignis-bin: src/ignis_launcher.c
	$(CC) $(CFLAGS) src/ignis_launcher.c -o bin/ignis-bin $(LDFLAGS) -ldl -Wl,-rpath,/usr/lib/ignis-gvc:/usr/local/lib/ignis-gvc

clean:
	rm -f ignis/native.so bin/ignis-bin

install: native
	install -d "$(BINDIR)"
	install -d "$(LUADIR)"
	install -d "$(LUACDIR)/ignis"
	install -d "$(SYSTEMD_USER_DIR)"
	install -d "$(DOCDIR)"
	cp -r ignis "$(LUADIR)/"
	rm -f "$(LUADIR)/ignis/native.so"
	install -Dm755 ignis/native.so "$(LUACDIR)/ignis/native.so"
	install -Dm755 bin/ignis "$(BINDIR)/ignis"
	install -Dm755 bin/ignis-bin "$(BINDIR)/ignis-bin"
	install -Dm644 systemd/ignis.service "$(SYSTEMD_USER_DIR)/ignis.service"
	install -Dm644 README.md "$(DOCDIR)/README.md"
	install -d "$(DOCDIR)/examples/bar"
	install -Dm644 examples/bar/config.lua "$(DOCDIR)/examples/bar/config.lua"
	install -Dm644 examples/bar/style.scss "$(DOCDIR)/examples/bar/style.scss"

uninstall:
	rm -f "$(BINDIR)/ignis" "$(BINDIR)/ignis-bin"
	rm -rf "$(LUADIR)/ignis" "$(LUACDIR)/ignis"
	rm -f "$(SYSTEMD_USER_DIR)/ignis.service"
	rm -rf "$(DOCDIR)"

test: native
	lua test.lua
