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
    odin_override = pkgs.odin.override {
      MacOSX-SDK = "${pkgs.apple-sdk_14.sdkroot}";
    };
  in
    with pkgs; let
      pname = "dynawall";
      version = "git";

      buildInputs = [
        odin_override
        apple-sdk_14
        libGL
        libGLU
        glfw
        glew
      ];
    in {
      packages = {
        default = stdenv.mkDerivation {
          inherit pname version buildInputs;

          src = ./.;

          buildPhase = ''
            mkdir -p build/bin
            ${lib.getExe odin_override} build . -minimum-os-version=14.0 -out=build/bin/${pname}
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
              odin_override
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
