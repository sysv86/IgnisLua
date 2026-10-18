# Maintainer: IgnisLua Contributors
pkgname=ignis-lua-git
_pkgname=IgnisLua
pkgver=0.7.0.r0.lua551
pkgrel=1
pkgdesc="High-performance reactive GTK4 widget framework for Wayland desktop shells in Lua 5.5 with native C11 engine (Arch Linux)"
arch=('x86_64' 'aarch64')
url="https://github.com/sysv86/IgnisLua"
license=('LGPL-2.1-or-later')
depends=(
  'lua>=5.5'
  'lua-lgi'
  'gtk4'
  'gtk4-layer-shell'
  'glib2'
  'gobject-introspection-runtime'
  'gdk-pixbuf2'
  'librsvg'
  'pango'
  'cairo'
)
makedepends=(
  'gcc'
  'make'
  'meson'
  'ninja'
  'git'
  'gobject-introspection'
)
optdepends=(
  'ignis-gvc: AudioService Gvc-1.0 typelib support (AUR)'
  'wireplumber: AudioService wpctl fallback support'
  'pipewire-pulse: PulseAudio/PipeWire compatibility'
  'networkmanager: NetworkService daemon'
  'libnm: NetworkService NM-1.0 GIR typelib'
  'gnome-bluetooth-3.0: BluetoothService GnomeBluetooth-3.0 typelib'
  'upower: UPowerService battery and device telemetry'
  'power-profiles-daemon: PowerProfilesService support'
  'dart-sass: SCSS/SASS stylesheet compilation'
  'gpu-screen-recorder: RecorderService Wayland screen recording (AUR)'
  'brightnessctl: BacklightService CLI fallback'
)
provides=('ignis-lua')
conflicts=('ignis-lua')

build() {
  cd "${startdir}"
  make LUA_VERSION=5.5 native
}

package() {
  cd "${startdir}"
  make DESTDIR="${pkgdir}" PREFIX=/usr LUA_VERSION=5.5 install
}
