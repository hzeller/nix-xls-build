{ pkgs ? import <nixpkgs> {} }:


(pkgs.buildFHSEnv {
  name = "xls-compile-environment";
  targetPkgs = pkgs: (with pkgs; [
    gcc13
    bazel_6
    jdk11
    git cacert         # some recursive workspace dependencies via git.

    # Various libraries that Python links
    python39
    libxcrypt-legacy
    libz
    expat
  ]) 
  ;
}).env
