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
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
NAME="Debian GNU/Linux"
VERSION_ID="12"
VERSION="12 (bookworm)"
VERSION_CODENAME=bookworm
ID=debian
HOME_URL="https://www.debian.org/"
SUPPORT_URL="https://www.debian.org/support"
BUG_REPORT_URL="https://bugs.debian.org/"
    '';
    };
  };
in (pkgs.buildFHSEnv {
  name = "xls-compile-environment";
  targetPkgs = pkgs: (with pkgs; [
    bazel_6
    jdk11
    git cacert         # some recursive workspace dependencies via git.

    # Various libraries that Python links
    python39
    libxcrypt-legacy
    libz
    expat
    osrelease
  ])
  ;
}).env
