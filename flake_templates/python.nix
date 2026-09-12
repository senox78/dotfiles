{
  description = "Python development environment with basedpyright";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            # Python interpreter used by the project and detected by basedpyright.
            python3

            # Neovim's configured Python language server.
            basedpyright

            # Linter and formatter for command-line and editor integrations.
            ruff
          ];
        };
      });
    };
}
