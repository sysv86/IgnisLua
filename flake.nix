{
  description = "IgnisLua — A high-performance reactive GTK4 widget framework for building Wayland desktop shells in Lua 5.5.1";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    ignis-gvc = {
      url = "github:ignis-sh/ignis-gvc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ignis-gvc,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      gvc = ignis-gvc.packages.${system}.ignis-gvc;
      luaEnv = import ./nix/lua55.nix {inherit pkgs;};
      ignis-lua = pkgs.callPackage ./nix/default.nix {
        inherit self;
        ignis-gvc = gvc;
        lua5_5 = luaEnv.lua;
        lgi = luaEnv.lgi;
      };
    in {
      default = ignis-lua;
      inherit ignis-lua;
      lua5_5 = luaEnv.lua;
      lgi = luaEnv.lgi;
    });

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      gvc = ignis-gvc.packages.${system}.ignis-gvc;
      luaEnv = import ./nix/lua55.nix {inherit pkgs;};
    in
      import ./nix/devshell.nix {
        inherit self pkgs;
        ignis-gvc = gvc;
        lua5_5 = luaEnv.lua;
        lgi = luaEnv.lgi;
      });

    overlays.default = final: prev: let
      luaEnv = import ./nix/lua55.nix {pkgs = prev;};
    in {
      ignis-lua = prev.callPackage ./nix/default.nix {
        inherit self;
        ignis-gvc = ignis-gvc.packages.${prev.stdenv.hostPlatform.system}.ignis-gvc;
        lua5_5 = luaEnv.lua;
        lgi = luaEnv.lgi;
      };
    };

    homeManagerModules = {
      default = import ./nix/hm-module.nix self;
      ignis = self.homeManagerModules.default;
      ignis-lua = self.homeManagerModules.default;
    };

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
