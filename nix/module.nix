self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.swiftdebot;
in
{
  options.services.swiftdebot = {
    enable = lib.mkEnableOption "SwiftDEBot, the Discord bot of the German Swift community";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "swiftdebot.packages.\${system}.default";
      description = "The SwiftDEBot package to use.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Environment file as defined in systemd.exec(5). Needs `DISCORD_TOKEN`
        and `DISCORD_APP_ID`; `DISCORD_LOGS_WEBHOOK_URL`, `KAGI_API_TOKEN` and
        `OPENROUTER_API_KEY` enable optional features (see AGENTS.md).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.swiftdebot = {
      description = "SwiftDEBot";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        EnvironmentFile = cfg.environmentFile;
        DynamicUser = true;
        # Foundation on Linux only looks for time zones in /usr/share/zoneinfo,
        # which NixOS lacks; without it `!se` traps formatting review dates.
        BindReadOnlyPaths = [ "${pkgs.tzdata}/share/zoneinfo:/usr/share/zoneinfo" ];
        Restart = "always";
        RestartSec = "10";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };
  };
}
