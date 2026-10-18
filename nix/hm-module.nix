self: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.ignis;
in {
  options.programs.ignis = {
    enable = lib.mkEnableOption "the IgnisLua widget framework";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "The IgnisLua package to use.";
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "The final IgnisLua package after applying module options.";
    };

    configDir = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = ./ignis;
      description = "Directory containing config.lua and assets to link into ~/.config/ignis.";
    };

    systemd = {
      enable = lib.mkEnableOption "IgnisLua systemd user service";
      target = lib.mkOption {
        type = lib.types.str;
        default = "graphical-session.target";
        description = "Systemd target to bind the IgnisLua user service to.";
      };
    };

    services = {
      audio.enable = lib.mkEnableOption "Audio service (ignis-gvc)";
      network.enable = lib.mkEnableOption "NetworkManager service";
      recorder.enable = lib.mkEnableOption "Screen recorder service (gpu-screen-recorder)";
      bluetooth.enable = lib.mkEnableOption "Bluetooth service (gnome-bluetooth)";
    };

    sass = {
      enable = lib.mkEnableOption "Sass compilation support";
      useDartSass = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use dart-sass for SCSS/SASS compilation.";
      };
      useGrassSass = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use grass-sass for SCSS/SASS compilation.";
      };
    };

    extraPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = [];
      description = "Extra packages to add to IgnisLua runtime PATH.";
    };
  };

  config = lib.mkIf cfg.enable (let
    finalPkg = cfg.package.override {
      enableAudioService = cfg.services.audio.enable;
      enableNetworkService = cfg.services.network.enable;
      enableRecorderService = cfg.services.recorder.enable;
      enableBluetoothService = cfg.services.bluetooth.enable;
      useDartSass = cfg.sass.enable && cfg.sass.useDartSass;
      useGrassSass = cfg.sass.enable && cfg.sass.useGrassSass;
      extraPackages = cfg.extraPackages;
    };
  in {
    programs.ignis.finalPackage = finalPkg;

    home.packages = [finalPkg];

    xdg.configFile."ignis" = lib.mkIf (cfg.configDir != null) {
      source = cfg.configDir;
      recursive = true;
    };

    systemd.user.services.ignis = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "IgnisLua Wayland Desktop Shell Framework";
        Documentation = "https://github.com/ignis-sh/ignis";
        PartOf = [cfg.systemd.target];
        After = [cfg.systemd.target];
      };
      Service = {
        ExecStart = "${finalPkg}/bin/ignis init";
        ExecReload = "${finalPkg}/bin/ignis reload";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install = {
        WantedBy = [cfg.systemd.target];
      };
    };
  });
}
