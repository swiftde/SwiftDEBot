{
  lib,
  stdenv,
  swift,
  swiftpm,
  fetchSwiftPMDeps,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swiftdebot";
  version = "0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../Package.swift
      ../Package.resolved
      ../Sources
      ../Tests
    ];
  };

  nativeBuildInputs = [
    swift
    swiftpm
  ];
  # See the dev shell in flake.nix for why zlib also needs CPATH.
  buildInputs = [ zlib ];
  env.CPATH = "${lib.getDev zlib}/include";

  # Any Package.resolved change needs a new hash: build, then copy the hash
  # from the mismatch error.
  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) src;
    hash = "sha256-HRJJvsJJOhhKSdc9k1PK15q9Z5+YPGLMFe1yzHQdi/Q=";
  };

  installPhase = ''
    runHook preInstall
    install -Dm755 $(swiftpmBinPath)/SwiftDEBot $out/bin/swiftdebot
    runHook postInstall
  '';

  doCheck = true;
  # These tests format dates in Europe/Berlin, which needs /usr/share/zoneinfo
  # (see nix/module.nix); the sandbox has none. CI runs them. The flags array
  # is shared with `swift build`, which rejects --skip, so it is restored after.
  preCheck = ''
    swiftpmFlagsArrayBeforeCheck=("''${swiftpmFlagsArray[@]}")
    swiftpmFlagsArray+=(--skip ProposalShortDescriptionTests)
  '';
  postCheck = ''
    swiftpmFlagsArray=("''${swiftpmFlagsArrayBeforeCheck[@]}")
  '';

  meta = {
    description = "The Discord bot of the German Swift community";
    homepage = "https://github.com/SwiftDE/SwiftDEBot";
    mainProgram = "swiftdebot";
  };
})
