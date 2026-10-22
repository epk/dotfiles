{
  nix-index-database,
  pkgs,
  try,
  user,
  ...
}:

{
  users.users.${user.username} = {
    home = "/Users/${user.username}";
    uid = 501;
    shell = pkgs.zsh;
  };
  users.knownUsers = [
    user.username
  ];

  system.primaryUser = user.username;

  home-manager = (import ../../lib/hm.nix { inherit nix-index-database try; }) // {
    extraSpecialArgs = {
      inherit user;
    };
    # Each host adds its Home Manager profile to this list.
    users.${user.username}.imports = [
      ../home
      ../home/dev.nix
      ../home/darwin.nix
    ];
  };
}
