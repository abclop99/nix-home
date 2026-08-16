{
  description = "abclop99 home-manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix/v26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, home-manager, catppuccin, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = import ./nixpkgs-config.nix;
        overlays = [ inputs.nur.overlays.default ];
      };
      # Headless chromium picks the terminal font by CSS family name via
      # fontconfig, so the font has to be on the font path — an env var naming
      # the .ttf would do nothing. Shared by the devShell and the app: without
      # it every screenshot falls back to a default face, and eza's Nerd Font
      # icons and the powerline separators come out as tofu at shifted column
      # widths, which is exactly what the images are looked at to judge.
      fontsConf = pkgs.makeFontsConf {
        fontDirectories = [ pkgs.nerd-fonts.fira-code ];
      };
    in
    {
      homeConfigurations.abclop99 = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./home.nix
          "${catppuccin}/modules/home-manager"
        ];
      };

      # Theme contrast audit harness — see tools/contrast-audit and
      # docs/superpowers/specs/2026-08-12-contrast-audit-harness-design.md.
      # Deliberately not in home.packages: this is a development tool, not
      # part of the installed environment.
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          (pkgs.python3.withPackages (ps: with ps; [ pyte pytest ]))
          pkgs.chromium
        ];
        FONTCONFIG_FILE = fontsConf;
      };

      apps.${system}.contrast-audit = {
        type = "app";
        program = pkgs.lib.getExe (pkgs.writeShellApplication {
          name = "contrast-audit";
          runtimeInputs = [
            (pkgs.python3.withPackages (ps: with ps; [ pyte ]))
            pkgs.chromium
          ];
          text = ''
            export PYTHONPATH=${./tools/contrast-audit}''${PYTHONPATH:+:$PYTHONPATH}
            export FONTCONFIG_FILE=${fontsConf}
            exec python3 -m contrast_audit "$@"
          '';
        });
      };
    };
}
