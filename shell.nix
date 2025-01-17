{ pkgs ? import <nixpkgs> {} }:
let
  bazelOverride = pkgs.bazel_7.overrideAttrs (
    previousAttrs: {
      # Provide our own hack, latest enableNixHacks introduces repo issues.
      patches = previousAttrs.patches ++ [
        ./nix/bazel.patch
      ];
    });

  # Required for toolchains_llvm
  bazelRunLibs = with pkgs; [
    stdenv.cc.cc
    zlib
    zstd
    libtinfo
    libxml2
    expat
  ];

  toolchains_llvm = pkgs.stdenv.mkDerivation {
    name = "toolchains_llvm";
    src = pkgs.fetchFromGitHub {
      owner = "bazel-contrib";
      repo = "toolchains_llvm";
      rev = "ab5557f9c1c1b086af0c9f6806aaae189bf248c0";
      sha256 = "sha256-HhWqb+WVeR5dR64P4xqv4LSNeLO+AVZqzPNRZcM9A4k=";
    };

    patches = [
      (pkgs.substituteAll {
        src = ./nix/toolchains_llvm.patch;
        linuxHeadersPath = pkgs.stdenv.cc.libc.dev.linuxHeaders;
        glibcPath = pkgs.stdenv.cc.libc;
        glibcDevPath = pkgs.stdenv.cc.libc.dev;
        stdenvPath = pkgs.stdenv.cc.cc.lib;
        stdenvDevPath = pkgs.stdenv.cc.cc;
        extraIncludes = ({ prefix, values }:
          builtins.concatStringsSep
            ","
            (builtins.concatMap (x:
              [("\"${prefix}\"") ("\""+ x + "\"")]) values)) {
                prefix = "-idirafter";
                values = [
                  "${pkgs.zlib.dev}/include"
                ];
              };
      })
    ];
    postPatch = ''
      # HACK: change to executable so it can be picked up by patchshebangs.
      chmod 755 ./toolchain/cc_wrapper.sh.tpl
      patchShebangs .
    '';
    installPhase = ''
      cp -r . $out
    '';
  };
in
pkgs.mkShell {
  name = "build-environment";
  packages = with pkgs; [
    git
    bazelOverride
    jdk17
    valgrind
    gopls
    gdb
    zlib
    zlib.dev
    python3
    perl
    infocmp
    bc
  ];

  # Override .bazelversion. We only care to have bazel 7.
  USE_BAZEL_VERSION = "${bazelOverride.version}";
  NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath bazelRunLibs;
  CPATH = pkgs.lib.makeLibraryPath bazelRunLibs;
  TOOLCHAINS_LLVM = "${toolchains_llvm}";
  shellHook =
    ''
     cat > user.bazelrc <<EOF
common --override_repository=toolchains_llvm=${toolchains_llvm}
EOF
   '';
}
