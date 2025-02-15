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
    git cacert
    bazelOverride
    jdk17
    zlib
    python3
    perl
    ncurses

    # Development convenience tools.
    #
    # Note, since this modifies the PATH, adding things here will
    # also invalidate the bazel cache due to the pass-through
    # of PATH we have to do.
    #
    # TODO: make this less impacting probably with a wrapper
    # for bazel that only selectively adds the paths to binaries
    # we need during build.
    less
    bazel-buildtools  # buildifier
    clang-tools_17
  ];

  # Override .bazelversion. We only care about our bazel we created.
  USE_BAZEL_VERSION = "${bazelOverride.version}";
  NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath bazelRunLibs;
  CPATH = pkgs.lib.makeLibraryPath bazelRunLibs;
  TOOLCHAINS_LLVM = "${toolchains_llvm}";

  # We use system clang-tidy for run-clang-tidy-cached.sh as the one
  # provided by the toolchain does not find its includes by itself.
  CLANG_TIDY = "${pkgs.clang-tools_17}/bin/clang-tidy";
  shellHook =
    ''
     # Tell bazel to use the toolchain we prepared above
     cat > user.bazelrc <<EOF
common --override_module=toolchains_llvm=${toolchains_llvm}
EOF
   '';
}
