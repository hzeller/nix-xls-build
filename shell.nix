{ pkgs ? import <nixpkgs> {} }:
let
  bazelOverride = pkgs.bazel_7.overrideAttrs (
    previousAttrs: {
      # Provide our own hack, latest enableNixHacks introduces repo issues.
      patches = previousAttrs.patches ++ [
        ./nix/bazel.patch
      ];
    });

  bazelBinExtra = with pkgs; [
    git      # fetching openroad
    perl     # uses in build of iverilog
    ncurses  # something is using tools from there to query terminal
    gcc14    # `ar` for z3; `cpp` for net_invisible_island_ncurses//:lib_gen_c
  ];
  bazelExtraBinPath = pkgs.lib.makeBinPath bazelBinExtra;

  # TODO: this is a hack of sorts. Ideally, we'd just like to add all these
  # binaries to what is referred to in the bazel package as `defaultShellUtils`
  #
  # If we can do that, they are 'baked into' the bazel installation, and
  # we can remove adding PATH to the excemption environment variables in
  # nix/bazel.patch
  wrappedBazel = pkgs.writeShellScriptBin "bazel" ''
  # Invoking bazel with the extra PATH to tools required by XLS compilation.
  export PATH=${bazelExtraBinPath}
  exec ${bazelOverride}/bin/bazel "$@"
'';

  # Required for toolchains_llvm
  bazelRunLibs = with pkgs; [
    stdenv.cc.cc
    zlib
    zstd
    ncurses  # libtinfo, really
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
  name = "xls-build-environment";
  packages = with pkgs; [
    wrappedBazel

    cacert  # needed by git
    jdk17   # bazel ...

    # Development convenience tools.
    less
    bazel-buildtools  # buildifier
    clang-tools_19
  ];

  # Override .bazelversion. We only care about our bazel we created.
  USE_BAZEL_VERSION = "${bazelOverride.version}";
  NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath bazelRunLibs;
  CPATH = pkgs.lib.makeLibraryPath bazelRunLibs;
  TOOLCHAINS_LLVM = "${toolchains_llvm}";

  # We use system clang-tidy for run-clang-tidy-cached.sh as the one
  # provided by the toolchain does not find its includes by itself.
  CLANG_TIDY = "${pkgs.clang-tools_19}/bin/clang-tidy";

  shellHook =
    ''
     # Tell bazel to use the toolchain we prepared above
     cat > user.bazelrc <<EOF
common --override_module=toolchains_llvm=${toolchains_llvm}
EOF
   '';
}
