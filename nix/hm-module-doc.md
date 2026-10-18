# Home Manager & NixOS Module Options (`programs.ignis`)

## `options.programs.ignis.enable`

Enable the IgnisLua widget framework.

- **Type:** `boolean`
- **Default:** `false`
- **Example:** `true`

## `options.programs.ignis.package`

The IgnisLua package to use.

- **Type:** `lib.types.package`
- **Default:** `self.packages.${pkgs.stdenv.hostPlatform.system}.default`

## `options.programs.ignis.finalPackage`

The final IgnisLua package after applying service and Sass module options (read-only).

- **Type:** `lib.types.package`

## `options.programs.ignis.configDir`

The configuration directory to link recursively into `~/.config/ignis`.

- **Type:** `with lib.types; nullOr path`
- **Default:** `null`
- **Example:** `./ignis`

## `options.programs.ignis.systemd.enable`

Enable the `ignis.service` systemd user service.

- **Type:** `boolean`
- **Default:** `false`
- **Example:** `true`

## `options.programs.ignis.systemd.target`

Systemd target to bind the IgnisLua user service to.

- **Type:** `string`
- **Default:** `"graphical-session.target"`

## `options.programs.ignis.services.audio.enable`

Enable Audio service (`ignis-gvc` typelib and shared library).

- **Type:** `boolean`
- **Default:** `false`
- **Example:** `true`

## `options.programs.ignis.services.network.enable`

Enable NetworkManager service (`NM-1.0` typelib and shared library).

- **Type:** `boolean`
- **Default:** `false`
- **Example:** `true`

## `options.programs.ignis.services.recorder.enable`

Enable Screen Recorder service (`gpu-screen-recorder`).

- **Type:** `boolean`
- **Default:** `false`
- **Example:** `true`

## `options.programs.ignis.services.bluetooth.enable`

Enable Bluetooth service (`GnomeBluetooth-3.0`).

- **Type:** `boolean`
- **Default:** `false`
- **Example:** `true`

## `options.programs.ignis.sass.enable`

Enable SCSS/SASS compilation support.

- **Type:** `boolean`
- **Default:** `false`
- **Example:** `true`

## `options.programs.ignis.sass.useDartSass`

Use `dart-sass` for SCSS/SASS compilation.

- **Type:** `boolean`
- **Default:** `true`

## `options.programs.ignis.sass.useGrassSass`

Use `grass-sass` for SCSS/SASS compilation.

- **Type:** `boolean`
- **Default:** `false`

## `options.programs.ignis.extraPackages`

Extra runtime packages to add to the IgnisLua `PATH`.

- **Type:** `with lib.types; listOf package`
- **Default:** `[]`
- **Example:** `[pkgs.brightnessctl pkgs.wl-clipboard]`
