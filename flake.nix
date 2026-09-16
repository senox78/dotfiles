{
  description = "dotfiles: NixOS + flakes + Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    firefox-nightly.url = "github:nix-community/flake-firefox-nightly";

    nix-hazkey = {
      url = "github:aster-void/nix-hazkey/4f791a241963f6804420d69613c25c6d25610e73";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jolt = {
      url = "github:jordond/jolt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr = {
      url = "github:ogulcancelik/herdr/v0.7.5";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wlmstr = {
      url = "github:Uliboooo/wlmstr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zathura-gui = {
      url = "github:Uliboooo/zathura_thin_gui_wrapper";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-float-sticky = {
      url = "github:probeldev/niri-float-sticky";
    };

    niri-scratchpad = {
      url = "github:argosnothing/niri-scratchpad-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:charmbracelet/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      linuxSystem = "x86_64-linux";
      userNames = {
        desktop = "rei";
        thinkpad = "seli";
        standalone = "rei";
      };

      gitSigningKeys = {
        desktop = "1A0DD644F6BACFDF7CD807E4E80ED68D276055A6";
        thinkpad = "7AD0F6CEBAE48BAE0D48F9BE839233C3BA088297";
      };

      mkGitSigningConfig = signingKey: {
        xdg.configFile."git-signing.conf".text = ''
          [user]
            signingkey = ${signingKey}
        '';
      };

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

      mkHome =
        system: signingKey: userName:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          modules = [
            ./home/seli.nix
            (mkGitSigningConfig signingKey)
          ];
          extraSpecialArgs = {
            inherit inputs userName;
          };
        };
    in
    {
      # ===== Home Manager (standalone) =====
      homeConfigurations = {
        ${userNames.standalone} = mkHome linuxSystem gitSigningKeys.desktop userNames.standalone;
        "${userNames.standalone}@${linuxSystem}" =
          mkHome linuxSystem gitSigningKeys.desktop
            userNames.standalone;
      };

      lib = {
        userName = userNames.standalone;
        inherit userNames;
      };

      # ===== NixOS (desktop) =====
      nixosConfigurations.thinkpad = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        specialArgs = {
          inherit inputs;
          userName = userNames.thinkpad;
        };
        modules = [
          ./hosts/thinkpad/configuration.nix

          (
            {
              pkgs,
              ...
            }:
            {
              environment.systemPackages = with pkgs; [
                bash
              ];
              environment.pathsToLink = [ "/bin" ];
            }
          )

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = {
              inherit inputs;
              userName = userNames.thinkpad;
            };
            home-manager.sharedModules = [ (mkGitSigningConfig gitSigningKeys.thinkpad) ];
            home-manager.users.${userNames.thinkpad} = import ./home/seli.nix;
          }
        ];
      };

      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        specialArgs = {
          inherit inputs;
          userName = userNames.desktop;
        };
        modules = [
          ./hosts/desktop/configuration.nix

          (
            {
              pkgs,
              ...
            }:
            {
              environment.systemPackages = with pkgs; [
                bash
              ];
              environment.pathsToLink = [ "/bin" ];
            }
          )

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = {
              inherit inputs;
              userName = userNames.desktop;
            };
            home-manager.sharedModules = [ (mkGitSigningConfig gitSigningKeys.desktop) ];
            home-manager.users.${userNames.desktop} = import ./home/seli.nix;
          }

          # inputs.shojiwm.nixosModules.default
          # {
          #   programs.shojiwm = {
          #     enable = true;
          #     initConfig = {
          #       enable = true;
          #       users = [ "seli" ];
          #     };
          #   };
          # }
        ];
      };
    };
}
