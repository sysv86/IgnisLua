project(
  'ignis-lua',
  'c',
  version: '0.7.0',
  license: 'LGPL-2.1-or-later',
  default_options: ['c_std=c11', 'warning_level=2', 'optimization=2']
)

cc = meson.get_compiler('c')
dl_dep = cc.find_library('dl', required: true)
lua_ver = get_option('lua_version')

shared_module(
  'native',
  'src/ignis_native.c',
  name_prefix: '',
  dependencies: [dl_dep],
  install: true,
  install_dir: join_paths(get_option('libdir'), 'lua', lua_ver, 'ignis')
)

executable(
  'ignis-bin',
  'src/ignis_launcher.c',
  dependencies: [dl_dep],
  build_rpath: '/usr/lib/ignis-gvc:/usr/local/lib/ignis-gvc',
  install_rpath: '/usr/lib/ignis-gvc:/usr/local/lib/ignis-gvc',
  install: true,
  install_dir: get_option('bindir')
)

install_data('bin/ignis', install_dir: get_option('bindir'), install_mode: 'rwxr-xr-x')
install_subdir('ignis', install_dir: join_paths(get_option('datadir'), 'lua', lua_ver), exclude_files: ['native.so'])
install_data('systemd/ignis.service', install_dir: join_paths(get_option('prefix'), 'lib', 'systemd', 'user'))
