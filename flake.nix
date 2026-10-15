{
  description = "SwiftDEBot, the Discord bot of the German Swift community";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell.override { stdenv = pkgs.swiftPackages.stdenv; } {
          packages = [
            pkgs.swiftPackages.swift
            pkgs.swiftPackages.swiftpm
            pkgs.swiftPackages.swift-format
          ];
          # swift-nio-extras needs zlib. swift-driver ignores the include paths
          # that buildInputs set for the C compiler, so CPATH exposes them to
          # its Clang importer.
          buildInputs = [ pkgs.zlib ];
          env.CPATH = "${pkgs.lib.getDev pkgs.zlib}/include";
        };
      });

      # Local builds, CI and the release image must share one compiler and
      # swift-format, so the Dockerfile's Swift version has to match nixpkgs.
      checks = forAllSystems (
        pkgs:
        let
          nixpkgsVersion = pkgs.swiftPackages.swift.version;
          dockerfileMatch = builtins.match ".*ARG SWIFT_VERSION=([^[:space:]]+).*" (
            builtins.readFile ./Dockerfile
          );
          dockerfileVersion =
            if dockerfileMatch == null then
              throw "Dockerfile has no `ARG SWIFT_VERSION=<version>` line."
            else
              builtins.head dockerfileMatch;
        in
        {
          swift-version =
            if nixpkgsVersion == dockerfileVersion then
              pkgs.emptyFile
            else
              throw "Dockerfile uses Swift ${dockerfileVersion}, nixpkgs has ${nixpkgsVersion}. Update SWIFT_VERSION in the Dockerfile.";
        }
      );
    };
}
