{ options, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./packages.nix
    ./shell.nix
  ];

  home.stateVersion = "26.11";
  home.enableNixpkgsReleaseCheck = false;
  manual.manpages.enable = false;

  programs.gh.enable = true;
  programs.jq.enable = true;
  programs.nh.enable = true;
  programs.nix-index-database.comma.enable = true;
  programs.ripgrep.enable = true;

  programs.try = {
    enable = true;
    # try init uses the script without its wrapper.
    # Its env ruby shebang selects Tec Ruby, which loads old user gems.
    # Select the pinned Ruby interpreter and disable user gems.
    package = options.programs.try.package.default.overrideAttrs {
      postFixup = ''
        substituteInPlace $out/bin/.try-wrapped \
          --replace-fail '#!/usr/bin/env ruby' '#!${pkgs.ruby}/bin/ruby --disable-gems'
      '';
    };
  };
}
