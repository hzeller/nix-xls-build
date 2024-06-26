{ pkgs ? import <nixpkgs> {} }:
let
  osrelease = pkgs.stdenv.mkDerivation {
    name = "osrelease";
    buildCommand = ''
      mkdir -p $out/etc
      cp $osrelease $out/etc/os-release
    '';
    osrelease = pkgs.writeTextFile {
      name = "os-release";
      text = ''
# Information llvm toolchain uses to choose what to download.
ID=debian
VERSION_ID="12"
    '';
    };
  };
  bazel = pkgs.bazel_6.override {
    enableNixHacks = false;  # does not make a difference
  };

in (pkgs.buildFHSEnv {
  name = "xls-compile-environment";
  targetPkgs = pkgs: (with pkgs; [
    osrelease          # fake os-release so that blaze llvm download works

    gcc                # bootstrap
    bazel jdk11      # build tool
    git cacert         # some recursive workspace dependencies via git.

    # Various libraries that Python links dynamically
    python39
    libxcrypt-legacy

    # Various things that llvm links dynamically
    libz
    expat
    zstd
    libxml2
    ncurses     # this provides libtinfo. Currenly not properly linking. Requires LD_LIBRARY_PATH
 
    # Development tools
    clang-tools_17
    bazel-buildtools
  ]);
  extraOutputsToInstall = [ "dev" ];
}).env
