{
  description = "Typst development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            typst
            tinymist

            imagemagick
            # pdf viewer
            zathura
            # PDF CLI tool(e.g. merge)
            pdfcpu
          ];
          shellHook = ''
            unset SOURCE_DATE_EPOCH
          '';
        };
      });
    };
}
