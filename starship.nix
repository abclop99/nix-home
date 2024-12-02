{
  enable = true;
  enableFishIntegration = true;
  enableBashIntegration = true;
  enableTransience = true;

  settings = {
    "$schema" = "https://starship.rs/config-schema.json";
    right_format = "$status$cmd_duration$time";
    continuation_prompt = "▶▶ ";

    os = {
      disabled = false;
      symbols = {
        AIX = "➿ ";              # TODO
        Alpaquita = " ";         # Standin for logo
        AlmaLinux = " ";
        Alpine = " ";
        Amazon = " ";
        Android = " ";
        Arch = " ";
        Artix = " ";
        CentOS = " ";
        Debian = " ";
        DragonFly = " ";         # Standin for logo
        Emscripten = "🔗 ";       # TODO
        EndeavourOS = " ";
        Fedora = " ";
        FreeBSD = " ";
        Garuda = " ";
        Gentoo = " ";
        HardenedBSD = " ";       # Standin for logo
        Illumos = " ";
        Kali = " ";
        Linux = " ";
        Mabox = " ";             # Standin for logo
        Macos = " ";
        Manjaro = " ";
        Mariner = "󰠅 ";
        MidnightBSD = " ";      # Standin for logo
        Mint = "󰣭 ";
        NetBSD = "󰉀 ";            # Standin for logo
        NixOS = " ";
        OpenBSD = " ";
        OpenCloudOS = " ";       # Standin for logo
        openEuler = "󰯷 ";
        openSUSE = " ";
        OracleLinux = " ";       # Oracle logo looks weird so small.
        Pop = " ";
        Raspbian = " ";
        Redhat = " ";
        RedHatEnterprise = " ";
        RockyLinux = " ";
        Redox = "󰹻 ";             # Atom icon standin for Redox logo
        Solus = " ";
        SUSE = " ";
        Ubuntu = " ";
        Ultramarine = "󰞍 ";       # Standin; Ultramarine logo is a single wave
        Unknown = " ";
        Void = " ";
        Windows = " ";
      };
    };

    shell = {
      disabled = false;
      bash_indicator = "󱆃 ";
      cmd_indicator = " ";
      fish_indicator = " ";
      powershell_indicator = "󰨊 ";
    };
    shlvl = {
      disabled = false;
      symbol = " ";
    };

    status = {
      disabled = false;
      recognize_signal_code = true;
      map_symbol = true;
      pipestatus = true;

      format = "[$common_meaning $symbol$status]($style) ";
      pipestatus_segment_format = "[$symbol$status]($style) ";

      symbol = "✘ ";
      not_executable_symbol = " ";
      not_found_symbol = " ";
      sigint_symbol = "󰟾 ";
      signal_symbol = "  ";
    };
    
    sudo = {
      disabled = false;
      symbol = " ";
    };
    
    time.disabled = false;

    # Some other miscellaneous symbols
    aws.symbol = " ";
    azure.symbol = "󰠅 ";
    bun.symbol = " ";
    c.symbol = " ";
    cmake.symbol = " ";
    conda.symbol = " ";
    container.symbol = " ";
    crystal.symbol = " ";
    dart.symbol = " ";
    deno.symbol = " ";
    docker_context.symbol = " ";
    elixir.symbol = " ";
    elm.symbol = " ";
    erlang.symbol = " ";
    fennel.symbol = " ";
    fossil_branch.symbol = " ";
    gcloud.symbol = "󱇶 ";
    git_branch.symbol = " ";
    git_commit.tag_symbol = " ";
    golang.symbol = " ";
    guix_shell.symbol = " ";
    gradle.symbol = " ";
    haskell.symbol = "󰲒 ";
    haxe.symbol = " ";
    helm.symbol = " ";
    java.symbol = " ";
    julia.symbol = " ";
    kotlin.symbol = " ";
    kubernetes.symbol = " ";
    lua.symbol = " ";
    hg_branch.symbol = " ";
    nim.symbol = " ";
    nix_shell.symbol = " ";
    nodejs.symbol = " ";
    ocaml.symbol = " ";
    odin.symbol = " ";                # Not in nerd fonts
    opa.symbol = "󰉟 ";                 # No horned helmet
    openstack.symbol = " ";
    package.symbol = " ";
    perl.symbol = " ";
    php.symbol = " ";
    pijul_channel.symbol = " ";
    pulumi.symbol = " ";
    purescript.symbol = " ";
    python.symbol = "󰌠 ";
    rlang.symbol = "󰟔 ";               # Sorted by "R"
    raku.symbol = "󱖉 ";                # Replacement for logo
    ruby.symbol = " ";
    rust.symbol = " ";                # Rust logo: 󱘗 
    scala.symbol = " ";
    solidity.symbol = " ";
    spack.symbol = " ";
    swift.symbol = "󰛥 ";
    terraform.symbol = " ";
    typst.symbol = " ";
    vagrant.symbol = " ";
    vlang.symbol = " ";
    zig.symbol = " ";                 # nf-dev-zig does not work: " ";
  };
}
