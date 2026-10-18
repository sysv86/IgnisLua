# Contributing

## Ground rules

Keep changes scoped. Do not mix bug fixes, refactors, formatting sweeps,
dependency upgrades, and feature work in one pull request.

## Development setup

```bash
make                      # builds ignis/native.so and bin/ignis-bin
lua5.5 test.lua           # or: make test
./bin/ignis-bin init -c examples/bar/config.lua
```

LuaGObject is vendored under `deps/`; rebuild it with
`make -C deps/LuaGObject/LuaGObject LUA_VERSION=5.5` and copy
`lua_gobject_core.so` into `deps/install/lib/lua/5.5/LuaGObject/`.

## Code style

- `snake_case` for functions and variables, `PascalCase` for classes/widgets.
- Keep LDoc annotations (`---@param`, `---@return`) on public APIs.
- No narration comments: comment the reason, not the mechanics.
- Widgets are declarative; a new widget subclasses a GTK4 type and calls
  `base_widget.apply_to_class`.
- Nothing that requires `LD_PRELOAD`, `LD_LIBRARY_PATH` or GTK3 compatibility
  shims.

## Issues

Bug reports need reproduction steps, expected and actual behavior, version or
commit, and environment. Feature requests need the problem, proposed scope,
alternatives, non-goals, and acceptance criteria.

## Pull requests

Before opening a PR:

1. Rebase on the target branch.
2. Run `make test` (or state why it was not run).
3. Add or update tests for behavior changes.
4. Remove unrelated formatting, generated files, local config, caches and logs.
5. Describe the change and the testing results in the PR body.
