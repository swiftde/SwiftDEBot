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
      # Keep the Swift version in sync with the swift image tag in the
      # Dockerfile, so local builds, CI and the release image share one
      # compiler and swift-format.
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
    };
}
