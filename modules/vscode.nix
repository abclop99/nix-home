{ pkgs, ... }:
{
  config = {
    programs.vscode = {
      enable = true;
      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          ms-vscode-remote.remote-ssh

          catppuccin.catppuccin-vsc
          catppuccin.catppuccin-vsc-icons

          ms-python.python
          ms-pyright.pyright

          ms-toolsai.jupyter
          ms-toolsai.jupyter-renderers

          rust-lang.rust-analyzer

          gruntfuggly.todo-tree
        ];
      };
    };
  };
}
