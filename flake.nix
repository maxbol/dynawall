{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }: (flake-utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    odin-final =
      if pkgs.stdenv.hostPlatform.isDarwin
      then
        pkgs.odin.override {
          MacOSX-SDK = "${pkgs.apple-sdk_14.sdkroot}";
        }
      else pkgs.odin;
  in
    with pkgs; let
      pname = "dynawall";
      version = "git";

      buildInputs =
        [
          odin-final
          libGL
          libGLU
          glfw
          glew
        ]
        ++ (
          if pkgs.stdenv.hostPlatform.isDarwin
          then [apple-sdk_14]
          else []
        );
    in {
      packages = {
        default = stdenv.mkDerivation {
          inherit pname version buildInputs;

          src = ./.;

          buildPhase = ''
            mkdir -p build/bin
            ${lib.getExe odin-final} build . -minimum-os-version=14.0 -out=build/bin/${pname}
          '';

          installPhase = ''
            cp -r build $out
          '';

          meta = {
            mainProgram = pname;
          };
        };
      };
      devShells = {
        default = mkShell {
          inherit buildInputs;

          packages =
            [
              clang
              ols
              odin-final
              clang-tools
              llvm_17
              lldb_17
              bear
              stdmanpages
            ]
            ++ (with llvmPackages_17; [
              clang-manpages
              llvm-manpages
              lldb-manpages
            ]);
        };
      };
    }));
}
