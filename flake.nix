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
  in
    with pkgs; let
      pname = "dynawall";
      version = "git";

      buildInputs = [
        apple-sdk_14
        (
          odin.override {
            MacOSX-SDK = "${apple-sdk_14.sdkroot}";
          }
        )
        libGL
        glfw
      ];
    in {
      packages = {
        default = stdenv.mkDerivation {
          inherit pname version buildInputs;

          src = ./.;

          buildPhase = ''
            mkdir -p build/bin
            ${lib.getExe odin} build . -minimum-os-version=14.0 -out=build/bin/${pname}
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

          packages = [
            clang
            ols
          ];
        };
      };
    }));
}
