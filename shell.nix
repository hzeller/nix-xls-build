{ pkgs ? import <nixpkgs> {} }:
let
  #xls_used_stdenv = pkgs.stdenv;
  xls_used_stdenv = pkgs.clang17Stdenv;
in
xls_used_stdenv.mkDerivation {
  name = "xls-build-environment";
  buildInputs = with pkgs;
    [
      bazel_6
      jdk11
      git cacert         # some recursive workspace dependencies via git.

      python39
      libxcrypt-legacy  # Bundled python is linked to that

      # Development support
      lcov              # Coverage.
      bazel-buildtools  # buildifier
      clang-tools_17    # clang-format
    ];

   shellHook =
     ''
     # The rules_python is dynamically linking against an old libcrypt
     export NIX_LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH:${pkgs.libxcrypt-legacy}/lib

     # Provide linking information passed through to the dynamic python binary.
     # Unfortunately, that only seems to work for the toplevel project, there is still
     # a target failing in asap7 somewhere. Just build with --keep_going :)
     cat > user.bazelrc <<EOF
test          --test_env=NIX_LD=$NIX_LD        --test_env=NIX_LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
common      --action_env=NIX_LD=$NIX_LD      --action_env=NIX_LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
common --host_action_env=NIX_LD=$NIX_LD --host_action_env=NIX_LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
EOF
   '';
}
