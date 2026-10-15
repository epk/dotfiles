{ user, ... }:

{
  imports = [
    ../../modules/darwin
    ../../profiles/work/darwin.nix
  ];

  home-manager.users.${user.username}.imports = [ ../../profiles/work/home.nix ];
}
