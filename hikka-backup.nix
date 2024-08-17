{
  beam,
  lib,
}: let
  beamPackages = beam.packagesWith beam.interpreters.erlang;
in
  beamPackages.mixRelease {
    pname = "hikka-backup";

    version = "0.0.1";

    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.gitTracked ./.;
    };

    mixNixDeps = import ./deps.nix {inherit lib beamPackages;};
  }
