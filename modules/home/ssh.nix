{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      # The inner quotes are part of the value: the path contains spaces and
      # ssh_config does not accept an unquoted one.
      IdentityAgent = ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
    };
  };
}
