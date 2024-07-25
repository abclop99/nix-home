{ pkgs, ... }:
{
  config = {
    programs.vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        ms-vscode-remote.remote-ssh

        catppuccin.catppuccin-vsc
        catppuccin.catppuccin-vsc-icons

        ms-toolsai.jupyter
        ms-python.python
        ms-pyright.pyright

        rust-lang.rust-analyzer

        gruntfuggly.todo-tree
      ];
    };
  };
}
