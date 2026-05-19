{ pkgs, inputs, ... }:
let
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    config = import ../nixpkgs-config.nix;
  };
in
{
  disabledModules = [ "programs/claude-code.nix" ];
  imports = [ "${inputs.home-manager-unstable}/modules/programs/claude-code.nix" ];

  config = {
    programs.claude-code = {
      enable = true;
      package = pkgs-unstable.claude-code;
    };
  };
}
