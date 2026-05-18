{ pkgs, ... }:
let
  hm-unstable = builtins.fetchTarball
    "https://github.com/nix-community/home-manager/archive/master.tar.gz";
  pkgs-unstable = import <nixpkgs-unstable> { config = import ../nixpkgs-config.nix; };
in
{
  disabledModules = [ "programs/claude-code.nix" ];
  imports = [ "${hm-unstable}/modules/programs/claude-code.nix" ];

  config = {
    programs.claude-code = {
      enable = true;
      package = pkgs-unstable.claude-code;
    };
  };
}
