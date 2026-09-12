{
  description = "OCaml development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        ocamlPackages = pkgs.ocamlPackages;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with ocamlPackages; [
            ocaml
            dune_3
            ocaml-lsp
            ocamlformat
            utop
            findlib
          ];
        };
      }
    );
}
