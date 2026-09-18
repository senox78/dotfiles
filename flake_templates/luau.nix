{
  description = "Luau development environment with LSP and Roblox tooling";

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
            # Luau CLI tools and the language server used by Neovim.
            luau
            luau-lsp

            # Roblox/Rojo project support.
            rojo

            # Formatting and linting.
            stylua
            selene
          ];
        };
      });
    };
}
