{ pkgs, ... }:
{
  config = {
    programs.helix = {
      enable = true;
      defaultEditor = true;
      settings = {
        editor = {
          line-number = "relative";
          cursorline = true;
          cursorcolumn = true;
          rulers = [80];
          text-width = 80;
          bufferline = "multiple";
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
          indent-guides.render = true;
          whitespace.render = {
            nbsp = "all";
          };
          soft-wrap.enable = true;
          lsp.display-messages = true;
          statusline.left = ["mode" "spinner" "version-control" "file-name"];
        };
        keys = {
          normal.X = ["extend_line_up" "extend_to_line_bounds"];
          select.X = ["extend_line_up" "extend_to_line_bounds"];
        };
      };
      languages = {
        language-server = {
          pyright = {
            command = "pyright-langserver";
            args = [ "--stdio" ];
          };
          nil.command = "${pkgs.nil}/bin/nil";
          svlint.command = "${pkgs.svlint}/bin/svlint";
          svls.command = "${pkgs.svls}/bin/svls";
        };
        language = [
          {
            name = "default";
            scope = "source.default";
            roots = [];
            file-types = [ "*" ];
            indent = { tab-width = 8; unit = "\t"; };
            text-width = 80;
            rulers = [ 80 ];
            soft-wrap.wrap-at-text-width = true;
          }
          {
            name = "python";
            language-servers = [
              "ty"
              "ruff"
              "jedi"
              "pylsp"
              "pyright"
              "basedpyright"
            ];
          }
          {
            name = "verilog";
            auto-format = true;
            language-servers = [ "svlangserver" "svlint" "svls" ];
          }
        ];
      };
    };
  };
}
